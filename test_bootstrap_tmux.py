"""Check tmux configuration generation without running the full bootstrap."""

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

print("Tmux configuration checks passed")
