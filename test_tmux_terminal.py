"""Exercise first startup, wheel scrolling, selection, and OSC 52 through a PTY."""

import base64
import contextlib
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
from pathlib import Path


script = Path(__file__).resolve().with_name("bootstrap_linux_env.sh")
with tempfile.TemporaryDirectory(prefix="tmux-terminal-") as directory:
    target = Path(directory)
    environment = dict(os.environ, HOME=str(target), XDG_CONFIG_HOME=str(target / ".config"))
    environment.pop("TMUX", None)
    environment.setdefault("TERM", "xterm-256color")
    subprocess.run(
        ["bash", "-c", 'source "$1"; TARGET_HOME="$2"; TARGET_USER="$(id -un)"; install_tmux_config',
         "check", str(script), str(target)],
        env=environment, check=True, capture_output=True, timeout=10,
    )
    tmux = ["tmux", "-S", str(target / "socket")]

    def run(*args):
        return subprocess.run(
            tmux + list(args), env=environment, check=True,
            capture_output=True, timeout=10,
        ).stdout

    output = bytearray()
    client_pid = None
    master = None

    def wait_for(predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                output.extend(os.read(master, 65536))
            if predicate():
                return
        raise AssertionError("Timed out waiting for tmux terminal response")

    try:
        run("new-session", "-d", "-s", "first-start", "-x", "80", "-y", "24",
            "i=0; while [ \"$i\" -lt 100 ]; do printf 'LINE-%03d SAMPLE-TEXT\\n' \"$i\"; "
            "i=$((i+1)); done; exec sleep 60")
        for option in ("mouse", "set-clipboard"):
            assert run("show-options", "-gv", option).strip() == b"on", option
        print("First startup: mouse=on, set-clipboard=on", flush=True)

        client_pid, master = pty.fork()
        if client_pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
            os.execvpe("tmux", tmux + ["attach-session", "-t", "first-start"], environment)

        wait_for(lambda: b"LINE-099" in output)
        mouse_enabled = b"\x1b[?1000h" in output or b"\x1b[?1002h" in output
        print(f"Terminal {environment['TERM']}: mouse reporting enabled={mouse_enabled}", flush=True)
        assert mouse_enabled, "tmux did not enable terminal mouse reporting"

        os.write(master, b"\x1b[<64;10;5M" * 3)
        wait_for(lambda: run("display-message", "-p", "#{pane_in_mode}").strip() == b"1")
        position = int(run("display-message", "-p", "#{scroll_position}").strip())
        assert position > 0, "Wheel input did not scroll history"
        print(f"Wheel scrolling: history offset={position}", flush=True)

        run("send-keys", "-X", "cancel")
        expected = run("capture-pane", "-p").splitlines()[0][:8]
        os.write(master, b"\x1b[<0;1;1M\x1b[<32;9;1M")
        wait_for(lambda: run("display-message", "-p", "#{selection_present}").strip() == b"1")
        time.sleep(0.1)  # Allow the selection redraw before releasing the mouse.
        os.write(master, b"\x1b[<0;9;1m")
        wait_for(lambda: bool(run("list-buffers")))
        selected = run("show-buffer")
        print(f"Mouse selection: {selected!r}, expected={expected!r}", flush=True)
        assert selected == expected, "Drag selection copied unexpected text"

        def clipboard_matches():
            payloads = re.findall(rb"\x1b\]52;[^;]*;([A-Za-z0-9+/=]+)(?:\x07|\x1b\\)", output)
            return any(base64.b64decode(payload) == selected for payload in payloads)

        try:
            wait_for(clipboard_matches)
        except AssertionError as error:
            print("Clipboard capability:", [line for line in run("info").splitlines() if b"Ms:" in line])
            raise AssertionError("The terminal received no OSC 52 for the selection") from error
        print("OSC 52: emitted the selected text", flush=True)
    finally:
        subprocess.run(tmux + ["kill-server"], env=environment, capture_output=True, timeout=10)
        if client_pid:
            with contextlib.suppress(ProcessLookupError):
                os.kill(client_pid, signal.SIGTERM)
            os.waitpid(client_pid, 0)
        if master is not None:
            os.close(master)
