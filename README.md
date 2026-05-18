# ZSH Linux Environment Bootstrap

This repository provides a bootstrap script for configuring a fresh Linux environment with common development tools, Zsh, Oh My Zsh, Vim settings, and SSH support.

The main entry point is:

```bash
./bootstrap_linux_env.sh
```

The script is intended to be editable. The configuration defaults, package lists, repository URLs, and SSH options are grouped at the top of `bootstrap_linux_env.sh` so they can be reviewed before running.

## What It Installs

The script installs required packages first, then optional common tools when they are available from the current package manager.

Required tools include:

- `zsh`
- `git`
- `curl`
- `ripgrep`
- `sudo`
- `vim`
- `openssh-client` when SSH support is enabled

Common optional tools include:

- `fzf`
- `tmux`
- `tree`
- `jq`
- `rsync`
- `neovim`
- `shellcheck`
- `cscope`
- `ctags` support through `universal-ctags` or `exuberant-ctags`

Supported package managers:

- `apt-get`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`

## Quick Start

Run the full bootstrap:

```bash
./bootstrap_linux_env.sh
```

Run without changing the login shell:

```bash
./bootstrap_linux_env.sh --no-chsh
```

Configure another user or home directory:

```bash
sudo ./bootstrap_linux_env.sh --target-user alice --target-home /home/alice
```

The script asks for `sudo` access once at startup when it is not run as `root`, then keeps that sudo session fresh while the bootstrap is running.

## Zsh Configuration

The script installs:

- `~/.zshrc`
- `~/.zsh/aliases.zsh`
- Oh My Zsh
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

The generated `~/.zshrc` loads these plugins:

```zsh
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    extract
)
```

Existing `~/.zshrc` and `~/.zsh` paths are backed up with a timestamp suffix before replacement.

## Vim Configuration

After installing `vim`, the script installs Vim configuration from:

```text
https://github.com/samsun-amd/vim-set.git
```

By default, it clones that repository to:

```text
~/.vim-set
```

Then it installs:

- `~/.vimrc`
- `~/.vim`

Existing `~/.vimrc` and `~/.vim` paths are backed up with a timestamp suffix before replacement.

Override the Vim configuration repository:

```bash
./bootstrap_linux_env.sh --vim-config-repo-url https://github.com/samsun-amd/vim-set.git
```

Override the local Vim configuration clone directory:

```bash
./bootstrap_linux_env.sh --vim-config-repo-dir /opt/vim-set
```

## Vim Repository Safety Checks

Before installing the Vim configuration, the script validates the cloned repository.

The validation checks that:

- `.vim` exists and is a directory.
- `.vimrc` exists and is a file.
- `.vim` and `.vimrc` are not symbolic links.
- No symbolic links exist inside `.vim`.
- Top-level paths are limited to `.git`, `.vim`, and `.vimrc`.
- `.vimrc` does not contain unexpected command execution patterns.

The currently allowed command execution lines in `.vimrc` are:

```vim
silent !mkdir -p ~/.vim/bundle
silent !git clone https://github.com/gmarik/vundle ~/.vim/bundle/vundle
```

These lines are allowed because the referenced Vim configuration uses Vundle. The repository already includes Vundle under `.vim/bundle/vundle`, so the fallback clone should not normally run after installation.

## SSH Support

SSH support is enabled by default.

The script can install:

- OpenSSH client package
- OpenSSH server package

It also configures the target user's SSH directory:

- Creates `~/.ssh` with mode `0700`.
- Creates `~/.ssh/config` with mode `0600` only when it does not already exist.
- Copies an optional authorized keys file to `~/.ssh/authorized_keys` with mode `0600`.

The default generated SSH client config is:

```sshconfig
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

If `~/.ssh/config` already exists, the script preserves it.

### SSH Server Configuration

When SSH server support is enabled, the script writes:

```text
/etc/ssh/sshd_config.d/99-bootstrap-linux-env.conf
```

Default content:

```sshconfig
# Managed by bootstrap_linux_env.sh.
Port 22
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin prohibit-password
AuthorizedKeysFile .ssh/authorized_keys
```

The script validates the server configuration with:

```bash
sshd -t
```

Then it attempts to enable and restart the SSH service using `systemctl`, `rc-service`, or `service` when available.

On systems that use `systemd` socket activation for SSH, changing `SSH_PORT` may also require updating or restarting `ssh.socket`. Review the local systemd socket configuration before using a non-default SSH port.

### SSH Examples

Install and configure SSH client only:

```bash
./bootstrap_linux_env.sh --no-ssh-server
```

Skip all SSH installation and configuration:

```bash
./bootstrap_linux_env.sh --no-ssh
```

Install an authorized keys file:

```bash
./bootstrap_linux_env.sh --ssh-authorized-keys ~/.ssh/authorized_keys
```

Use a custom SSH server port:

```bash
./bootstrap_linux_env.sh --ssh-port 2222
```

Disable SSH password authentication:

```bash
./bootstrap_linux_env.sh --ssh-password-authentication no
```

Do not enable or restart the SSH server service:

```bash
./bootstrap_linux_env.sh --no-ssh-service
```

## Configuration Reference

The most important defaults are defined at the top of `bootstrap_linux_env.sh`:

```bash
TARGET_USER=""
TARGET_HOME=""
OH_MY_ZSH_DIR=""
ZSH_CUSTOM_DIR=""
VIM_CONFIG_REPO_URL="https://github.com/samsun-amd/vim-set.git"
VIM_CONFIG_REPO_DIR=""
SET_DEFAULT_SHELL="1"

CONFIGURE_SSH="1"
INSTALL_SSH_SERVER="1"
ENABLE_SSH_SERVER="1"
START_SSH_SERVER="1"
WRITE_SSH_CLIENT_CONFIG="1"
SSH_AUTHORIZED_KEYS_SOURCE=""
SSH_PORT="22"
SSH_PASSWORD_AUTHENTICATION="yes"
SSH_PUBKEY_AUTHENTICATION="yes"
SSH_PERMIT_ROOT_LOGIN="prohibit-password"
SSH_CLIENT_SERVER_ALIVE_INTERVAL="60"
SSH_CLIENT_SERVER_ALIVE_COUNT_MAX="3"
SSHD_CONFIG_DROPIN_NAME="99-bootstrap-linux-env.conf"
```

Most values can be overridden with environment variables:

```bash
SSH_PASSWORD_AUTHENTICATION=no ./bootstrap_linux_env.sh
```

Or with CLI options:

```bash
./bootstrap_linux_env.sh --ssh-password-authentication no
```

## CLI Options

Show all options:

```bash
./bootstrap_linux_env.sh --help
```

Common options:

```text
--target-user USER
--target-home DIR
--oh-my-zsh-dir DIR
--zsh-custom-dir DIR
--vim-config-repo-url URL
--vim-config-repo-dir DIR
--ssh-authorized-keys FILE
--ssh-port PORT
--ssh-password-authentication yes|no
--ssh-pubkey-authentication yes|no
--ssh-permit-root-login VALUE
--no-ssh
--no-ssh-server
--no-ssh-service
--no-ssh-client-config
--no-chsh
```

## Backup Behavior

Before replacing user configuration paths, the script moves existing files or directories to timestamped backups.

Examples:

```text
~/.zshrc.backup.YYYYMMDDHHMMSS
~/.zsh.backup.YYYYMMDDHHMMSS
~/.vimrc.backup.YYYYMMDDHHMMSS
~/.vim.backup.YYYYMMDDHHMMSS
```

## Notes

- The script is designed for fresh Linux environments.
- Review the top-level configuration before running it on an existing workstation.
- Review SSH settings before enabling remote access.
- Keep `bootstrap_linux_env.sh`, `.zshrc`, and `.zsh/aliases.zsh` in sync because the script embeds the generated Zsh reference content.
