"""Check tmux configuration generation without running the full bootstrap."""

import os
import pty
import subprocess
import tempfile
from pathlib import Path


script = Path(__file__).resolve().with_name("bootstrap_linux_env.sh")
settings = b"set -g mouse on\nset -g set-clipboard on\n"

with tempfile.TemporaryDirectory(prefix="bootstrap-tmux-") as directory:
    target = Path(directory) / "home"
    config = target / ".tmux.conf"
    command = [
        "bash", "-c",
        'source "$1"; TARGET_HOME="$2"; TARGET_USER="$(id -un)"; install_tmux_config',
        "check", str(script), str(target),
    ]
    for original in (
        None,
        b"",
        b"# Custom settings without a trailing newline",
        b"set -g prefix C-a\nset -g mouse off\n",
        settings,
        settings + b"set -g mouse off\nset -g set-clipboard off\n",
    ):
        if config.exists():
            config.unlink()
        if original is not None:
            config.write_bytes(original)
            config.chmod(0o600)
        subprocess.run(command, check=True, capture_output=True)
        actual = config.read_bytes()
        expected = settings if original is None else (
            original if original.endswith(settings) else original + b"\n" + settings
        )
        assert actual == expected, (original, actual)
        if original is not None:
            assert config.stat().st_mode & 0o777 == 0o600
        subprocess.run(command, check=True, capture_output=True)
        assert config.read_bytes() == actual, "Rerunning must not append duplicates"

    config.unlink()
    config.mkdir()
    result = subprocess.run(command, capture_output=True)
    assert result.returncode != 0 and config.is_dir()

# Exercise the completion message without installing packages or changing settings.
notice_command = [
    "bash", "-c",
    'source "$1"; '
    'for step in require_sudo_access setup_cleanup_traps start_sudo_keepalive '
    'install_packages verify_core_tools configure_ssh install_vim_config '
    'install_oh_my_zsh install_custom_plugins install_dotfiles install_tmux_config '
    'change_default_shell; do eval "$step() { :; }"; done; main',
    "check", str(script),
]
environment = dict(os.environ, TERM="xterm-256color")
result = subprocess.run(notice_command, env=environment, check=True, capture_output=True, timeout=10)
assert b"WARNING:" in result.stdout and b"tmux source-file ~/.tmux.conf" in result.stdout
assert b"\x1b[" not in result.stdout, "Redirected output must not contain color codes"

for terminal, colored in (("xterm-256color", True), ("dumb", False)):
    master, slave = pty.openpty()
    try:
        subprocess.run(
            notice_command, env=dict(environment, TERM=terminal), stdout=slave,
            stderr=subprocess.PIPE, check=True, timeout=10,
        )
        output = os.read(master, 65536)
        assert b"tmux source-file ~/.tmux.conf" in output
        assert (b"\x1b[1;33m" in output and b"\x1b[0m" in output) == colored
    finally:
        os.close(master)
        os.close(slave)

print("Tmux configuration and completion-message checks passed")
