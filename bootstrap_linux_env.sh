#!/usr/bin/env bash
set -Eeuo pipefail

# User-editable configuration. Environment variables and CLI options can
# override these defaults without modifying this file.
TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-}"
OH_MY_ZSH_DIR="${OH_MY_ZSH_DIR:-}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM_DIR:-${ZSH_CUSTOM:-}}"
VIM_CONFIG_REPO_URL="${VIM_CONFIG_REPO_URL:-https://github.com/samsun-amd/vim-set.git}"
VIM_CONFIG_REPO_DIR="${VIM_CONFIG_REPO_DIR:-}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"

CONFIGURE_SSH="${CONFIGURE_SSH:-1}"
INSTALL_SSH_SERVER="${INSTALL_SSH_SERVER:-1}"
ENABLE_SSH_SERVER="${ENABLE_SSH_SERVER:-1}"
START_SSH_SERVER="${START_SSH_SERVER:-1}"
WRITE_SSH_CLIENT_CONFIG="${WRITE_SSH_CLIENT_CONFIG:-1}"
SSH_AUTHORIZED_KEYS_SOURCE="${SSH_AUTHORIZED_KEYS_SOURCE:-}"
SSH_PORT="${SSH_PORT:-22}"
SSH_PASSWORD_AUTHENTICATION="${SSH_PASSWORD_AUTHENTICATION:-yes}"
SSH_PUBKEY_AUTHENTICATION="${SSH_PUBKEY_AUTHENTICATION:-yes}"
SSH_PERMIT_ROOT_LOGIN="${SSH_PERMIT_ROOT_LOGIN:-prohibit-password}"
SSH_CLIENT_SERVER_ALIVE_INTERVAL="${SSH_CLIENT_SERVER_ALIVE_INTERVAL:-60}"
SSH_CLIENT_SERVER_ALIVE_COUNT_MAX="${SSH_CLIENT_SERVER_ALIVE_COUNT_MAX:-3}"
SSHD_CONFIG_DROPIN_NAME="${SSHD_CONFIG_DROPIN_NAME:-99-bootstrap-linux-env.conf}"

OH_MY_ZSH_REPO_URL="${OH_MY_ZSH_REPO_URL:-https://github.com/ohmyzsh/ohmyzsh.git}"
ZSH_AUTOSUGGESTIONS_REPO_URL="${ZSH_AUTOSUGGESTIONS_REPO_URL:-https://github.com/zsh-users/zsh-autosuggestions.git}"
ZSH_SYNTAX_HIGHLIGHTING_REPO_URL="${ZSH_SYNTAX_HIGHLIGHTING_REPO_URL:-https://github.com/zsh-users/zsh-syntax-highlighting.git}"

BACKUP_SUFFIX="${BACKUP_SUFFIX:-$(date +%Y%m%d%H%M%S)}"

APT_REQUIRED_PACKAGES=(
    ca-certificates
    curl
    git
    ripgrep
    sudo
    vim
    zsh
)

APT_COMMON_PACKAGES=(
    bat
    build-essential
    cscope
    dnsutils
    fd-find
    file
    fzf
    g++
    gcc
    gzip
    htop
    iproute2
    iputils-ping
    jq
    less
    lsof
    make
    man-db
    net-tools
    neovim
    pkg-config
    procps
    psmisc
    python3
    python3-dev
    python3-pip
    python3-venv
    rsync
    shellcheck
    strace
    tar
    tcpdump
    tmux
    traceroute
    tree
    unzip
    wget
    xz-utils
    zip
)

APT_CTAG_PACKAGE_CANDIDATES=(
    universal-ctags
    exuberant-ctags
)

APT_SSH_CLIENT_PACKAGES=(
    openssh-client
)

APT_SSH_SERVER_PACKAGES=(
    openssh-server
)

DNF_SSH_CLIENT_PACKAGES=(
    openssh-clients
)

DNF_SSH_SERVER_PACKAGES=(
    openssh-server
)

YUM_SSH_CLIENT_PACKAGES=(
    openssh-clients
)

YUM_SSH_SERVER_PACKAGES=(
    openssh-server
)

ZYPPER_SSH_CLIENT_PACKAGES=(
    openssh
)

ZYPPER_SSH_SERVER_PACKAGES=(
    openssh-server
)

PACMAN_SSH_SERVER_PACKAGES=(
    openssh
)

PACMAN_SSH_CLIENT_PACKAGES=(
    openssh
)

APK_SSH_CLIENT_PACKAGES=(
    openssh-client
)

APK_SSH_SERVER_PACKAGES=(
    openssh-server
)

SSH_SERVICE_CANDIDATES=(
    ssh
    sshd
)

BASIC_MANAGER_PACKAGES=(
    zsh
    git
    curl
    ripgrep
    fzf
    wget
    tree
    tmux
    htop
    jq
    unzip
    zip
    vim
    neovim
    rsync
    python3
    python3-pip
)

PACMAN_PACKAGES=(
    zsh
    git
    curl
    ripgrep
    fzf
    wget
    tree
    tmux
    htop
    jq
    unzip
    zip
    vim
    neovim
    rsync
    python
    python-pip
)

APK_PACKAGES=(
    zsh
    git
    curl
    ripgrep
    fzf
    wget
    tree
    tmux
    htop
    jq
    unzip
    zip
    vim
    neovim
    rsync
    python3
    py3-pip
)

REQUIRED_TOOLS=(
    zsh
    git
    curl
    rg
    ssh
    vim
)

VIM_CONFIG_ALLOWED_SHELL_COMMANDS=(
    "silent !mkdir -p ~/.vim/bundle"
    "silent !git clone https://github.com/gmarik/vundle ~/.vim/bundle/vundle"
)

SUDO_KEEPALIVE_PID=""

usage() {
    cat <<'EOF'
Usage: ./bootstrap_linux_env.sh [options]

Configure a fresh Ubuntu/Linux environment with common tools, zsh, Oh My Zsh,
plugins, and the embedded shell settings.

The script asks for sudo access once at startup when it is not run as root, then
keeps that sudo session fresh while the bootstrap is running.

Environment variables:
  TARGET_USER       User to configure. Defaults to SUDO_USER when present,
                    otherwise the current user.
  TARGET_HOME       Home directory to receive .zshrc and .zsh.
                    Defaults to TARGET_USER's home directory.
  OH_MY_ZSH_DIR     Oh My Zsh installation directory. Defaults to
                    $TARGET_HOME/.oh-my-zsh.
  ZSH_CUSTOM_DIR    Oh My Zsh custom directory. Defaults to
                    $OH_MY_ZSH_DIR/custom. ZSH_CUSTOM is also supported for
                    compatibility.
  VIM_CONFIG_REPO_URL
                    Git repository providing .vim and .vimrc. Defaults to
                    https://github.com/samsun-amd/vim-set.git.
  VIM_CONFIG_REPO_DIR
                    Local clone/cache directory for VIM_CONFIG_REPO_URL.
                    Defaults to $TARGET_HOME/.vim-set.
  CONFIGURE_SSH     Configure SSH client/server support. Defaults to 1.
  INSTALL_SSH_SERVER
                    Install OpenSSH server packages. Defaults to 1.
  ENABLE_SSH_SERVER
                    Enable the SSH server service when available. Defaults to 1.
  START_SSH_SERVER  Restart the SSH server after configuration. Defaults to 1.
  WRITE_SSH_CLIENT_CONFIG
                    Create ~/.ssh/config when it does not exist. Defaults to 1.
  SSH_AUTHORIZED_KEYS_SOURCE
                    Optional file copied to ~/.ssh/authorized_keys.
  SSH_PORT          SSH server port. Defaults to 22.
  SSH_PASSWORD_AUTHENTICATION
                    sshd PasswordAuthentication value. Defaults to yes.
  SSH_PUBKEY_AUTHENTICATION
                    sshd PubkeyAuthentication value. Defaults to yes.
  SSH_PERMIT_ROOT_LOGIN
                    sshd PermitRootLogin value. Defaults to prohibit-password.

Options:
  --target-user USER
                    User to configure.
  --target-home DIR
                    Home directory to configure.
  --oh-my-zsh-dir DIR
                    Oh My Zsh installation directory.
  --zsh-custom-dir DIR
                    Oh My Zsh custom directory.
  --vim-config-repo-url URL
                    Git repository providing .vim and .vimrc.
  --vim-config-repo-dir DIR
                    Local clone/cache directory for the Vim config repo.
  --ssh-authorized-keys FILE
                    Copy FILE to ~/.ssh/authorized_keys.
  --ssh-port PORT   Configure sshd to listen on PORT.
  --ssh-password-authentication VALUE
                    Set sshd PasswordAuthentication.
  --ssh-pubkey-authentication VALUE
                    Set sshd PubkeyAuthentication.
  --ssh-permit-root-login VALUE
                    Set sshd PermitRootLogin.
  --no-ssh          Skip SSH installation and configuration.
  --no-ssh-server   Install/configure SSH client only.
  --no-ssh-service  Do not enable or restart the SSH server service.
  --no-ssh-client-config
                    Do not create ~/.ssh/config.
  --no-chsh         Do not change the default login shell.
  -h, --help        Show this help.
EOF
}

log() {
    printf '[bootstrap_linux_env] %s\n' "$*"
}

die() {
    printf '[bootstrap_linux_env] ERROR: %s\n' "$*" >&2
    exit 1
}

flag_enabled() {
    local value="${1,,}"
    local name="${2:-flag}"

    case "$value" in
        1|yes|true|on|enable|enabled)
            return 0
            ;;
        0|no|false|off|disable|disabled)
            return 1
            ;;
        *)
            die "$name must be enabled or disabled, got: $1"
            ;;
    esac
}

validate_flag_value() {
    local name="$1"
    local value="${2,,}"

    case "$value" in
        1|yes|true|on|enable|enabled|0|no|false|off|disable|disabled)
            ;;
        *)
            die "$name must be enabled or disabled, got: $2"
            ;;
    esac
}

validate_yes_no() {
    local name="$1"
    local value="${2,,}"

    case "$value" in
        yes|no)
            ;;
        *)
            die "$name must be yes or no, got: $2"
            ;;
    esac
}

validate_numeric_range() {
    local name="$1"
    local value="$2"
    local minimum="$3"
    local maximum="$4"

    [[ "$value" =~ ^[0-9]+$ ]] || die "$name must be a number, got: $value"
    (( value >= minimum && value <= maximum )) || die "$name must be between $minimum and $maximum, got: $value"
}

validate_ssh_config_values() {
    validate_flag_value CONFIGURE_SSH "$CONFIGURE_SSH"
    validate_flag_value INSTALL_SSH_SERVER "$INSTALL_SSH_SERVER"
    validate_flag_value ENABLE_SSH_SERVER "$ENABLE_SSH_SERVER"
    validate_flag_value START_SSH_SERVER "$START_SSH_SERVER"
    validate_flag_value WRITE_SSH_CLIENT_CONFIG "$WRITE_SSH_CLIENT_CONFIG"

    validate_numeric_range SSH_PORT "$SSH_PORT" 1 65535
    validate_numeric_range SSH_CLIENT_SERVER_ALIVE_INTERVAL "$SSH_CLIENT_SERVER_ALIVE_INTERVAL" 0 86400
    validate_numeric_range SSH_CLIENT_SERVER_ALIVE_COUNT_MAX "$SSH_CLIENT_SERVER_ALIVE_COUNT_MAX" 0 1000
    validate_yes_no SSH_PASSWORD_AUTHENTICATION "$SSH_PASSWORD_AUTHENTICATION"
    validate_yes_no SSH_PUBKEY_AUTHENTICATION "$SSH_PUBKEY_AUTHENTICATION"

    case "${SSH_PERMIT_ROOT_LOGIN,,}" in
        yes|no|prohibit-password|without-password|forced-commands-only)
            ;;
        *)
            die "SSH_PERMIT_ROOT_LOGIN has an unsupported value: $SSH_PERMIT_ROOT_LOGIN"
            ;;
    esac

    case "$SSHD_CONFIG_DROPIN_NAME" in
        ""|*/*)
            die "SSHD_CONFIG_DROPIN_NAME must be a file name, got: $SSHD_CONFIG_DROPIN_NAME"
            ;;
    esac

    if [[ -n "$SSH_AUTHORIZED_KEYS_SOURCE" && ! -f "$SSH_AUTHORIZED_KEYS_SOURCE" ]]; then
        die "SSH_AUTHORIZED_KEYS_SOURCE is not a file: $SSH_AUTHORIZED_KEYS_SOURCE"
    fi
}

default_target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
        printf '%s\n' "$SUDO_USER"
    else
        id -un
    fi
}

default_target_home() {
    local user_name="$1"
    local home_dir=""

    if command -v getent >/dev/null 2>&1; then
        home_dir="$(getent passwd "$user_name" | cut -d: -f6 || true)"
    fi

    printf '%s\n' "${home_dir:-$HOME}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target-user)
                [[ $# -ge 2 ]] || die "--target-user requires a value"
                TARGET_USER="$2"
                shift 2
                ;;
            --target-user=*)
                TARGET_USER="${1#*=}"
                shift
                ;;
            --target-home)
                [[ $# -ge 2 ]] || die "--target-home requires a value"
                TARGET_HOME="$2"
                shift 2
                ;;
            --target-home=*)
                TARGET_HOME="${1#*=}"
                shift
                ;;
            --oh-my-zsh-dir)
                [[ $# -ge 2 ]] || die "--oh-my-zsh-dir requires a value"
                OH_MY_ZSH_DIR="$2"
                shift 2
                ;;
            --oh-my-zsh-dir=*)
                OH_MY_ZSH_DIR="${1#*=}"
                shift
                ;;
            --zsh-custom-dir)
                [[ $# -ge 2 ]] || die "--zsh-custom-dir requires a value"
                ZSH_CUSTOM_DIR="$2"
                shift 2
                ;;
            --zsh-custom-dir=*)
                ZSH_CUSTOM_DIR="${1#*=}"
                shift
                ;;
            --vim-config-repo-url)
                [[ $# -ge 2 ]] || die "--vim-config-repo-url requires a value"
                VIM_CONFIG_REPO_URL="$2"
                shift 2
                ;;
            --vim-config-repo-url=*)
                VIM_CONFIG_REPO_URL="${1#*=}"
                shift
                ;;
            --vim-config-repo-dir)
                [[ $# -ge 2 ]] || die "--vim-config-repo-dir requires a value"
                VIM_CONFIG_REPO_DIR="$2"
                shift 2
                ;;
            --vim-config-repo-dir=*)
                VIM_CONFIG_REPO_DIR="${1#*=}"
                shift
                ;;
            --ssh-authorized-keys)
                [[ $# -ge 2 ]] || die "--ssh-authorized-keys requires a value"
                SSH_AUTHORIZED_KEYS_SOURCE="$2"
                shift 2
                ;;
            --ssh-authorized-keys=*)
                SSH_AUTHORIZED_KEYS_SOURCE="${1#*=}"
                shift
                ;;
            --ssh-port)
                [[ $# -ge 2 ]] || die "--ssh-port requires a value"
                SSH_PORT="$2"
                shift 2
                ;;
            --ssh-port=*)
                SSH_PORT="${1#*=}"
                shift
                ;;
            --ssh-password-authentication)
                [[ $# -ge 2 ]] || die "--ssh-password-authentication requires a value"
                SSH_PASSWORD_AUTHENTICATION="$2"
                shift 2
                ;;
            --ssh-password-authentication=*)
                SSH_PASSWORD_AUTHENTICATION="${1#*=}"
                shift
                ;;
            --ssh-pubkey-authentication)
                [[ $# -ge 2 ]] || die "--ssh-pubkey-authentication requires a value"
                SSH_PUBKEY_AUTHENTICATION="$2"
                shift 2
                ;;
            --ssh-pubkey-authentication=*)
                SSH_PUBKEY_AUTHENTICATION="${1#*=}"
                shift
                ;;
            --ssh-permit-root-login)
                [[ $# -ge 2 ]] || die "--ssh-permit-root-login requires a value"
                SSH_PERMIT_ROOT_LOGIN="$2"
                shift 2
                ;;
            --ssh-permit-root-login=*)
                SSH_PERMIT_ROOT_LOGIN="${1#*=}"
                shift
                ;;
            --no-ssh)
                CONFIGURE_SSH=0
                INSTALL_SSH_SERVER=0
                ENABLE_SSH_SERVER=0
                START_SSH_SERVER=0
                WRITE_SSH_CLIENT_CONFIG=0
                shift
                ;;
            --no-ssh-server)
                INSTALL_SSH_SERVER=0
                ENABLE_SSH_SERVER=0
                START_SSH_SERVER=0
                shift
                ;;
            --no-ssh-service)
                ENABLE_SSH_SERVER=0
                START_SSH_SERVER=0
                shift
                ;;
            --no-ssh-client-config)
                WRITE_SSH_CLIENT_CONFIG=0
                shift
                ;;
            --no-chsh)
                SET_DEFAULT_SHELL=0
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

resolve_configuration() {
    if [[ -z "$TARGET_USER" ]]; then
        TARGET_USER="$(default_target_user)"
    fi

    if [[ -z "$TARGET_HOME" ]]; then
        TARGET_HOME="$(default_target_home "$TARGET_USER")"
    fi

    if [[ -z "$OH_MY_ZSH_DIR" ]]; then
        OH_MY_ZSH_DIR="$TARGET_HOME/.oh-my-zsh"
    fi

    if [[ -z "$ZSH_CUSTOM_DIR" ]]; then
        ZSH_CUSTOM_DIR="$OH_MY_ZSH_DIR/custom"
    fi

    if [[ -z "$VIM_CONFIG_REPO_DIR" ]]; then
        VIM_CONFIG_REPO_DIR="$TARGET_HOME/.vim-set"
    fi

    validate_ssh_config_values
}

require_sudo_access() {
    if [[ "$(id -u)" -eq 0 ]]; then
        return
    fi

    command -v sudo >/dev/null 2>&1 || die "sudo is required when running as a non-root user"

    log "Checking sudo access. Enter your password if prompted."
    sudo -v || die "sudo authentication failed"
}

start_sudo_keepalive() {
    if [[ "$(id -u)" -eq 0 || -n "$SUDO_KEEPALIVE_PID" ]]; then
        return
    fi

    (
        while true; do
            sudo -n -v >/dev/null 2>&1 || exit 0
            sleep 60
        done
    ) &
    SUDO_KEEPALIVE_PID="$!"
}

stop_sudo_keepalive() {
    if [[ -z "${SUDO_KEEPALIVE_PID:-}" ]]; then
        return
    fi

    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    wait "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    SUDO_KEEPALIVE_PID=""
}

setup_cleanup_traps() {
    trap stop_sudo_keepalive EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

sudo_cmd() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
        return
    fi

    command -v sudo >/dev/null 2>&1 || die "sudo is required when running as a non-root user"
    sudo "$@"
}

run_as_target_user() {
    if [[ "$(id -u)" -eq 0 && "$TARGET_USER" != "root" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo -H -u "$TARGET_USER" "$@"
        elif command -v runuser >/dev/null 2>&1; then
            runuser -u "$TARGET_USER" -- "$@"
        else
            die "sudo or runuser is required to run commands as $TARGET_USER"
        fi
    else
        "$@"
    fi
}

fix_target_ownership() {
    if [[ "$(id -u)" -ne 0 || "$TARGET_USER" == "root" ]]; then
        return
    fi

    id "$TARGET_USER" >/dev/null 2>&1 || return

    local target_group
    target_group="$(id -gn "$TARGET_USER")"

    local path
    for path in "$@"; do
        if [[ -e "$path" || -L "$path" ]]; then
            chown -R "$TARGET_USER:$target_group" "$path"
        fi
    done
}

ensure_directory() {
    local path="$1"

    if [[ -e "$path" && ! -d "$path" ]]; then
        die "$path exists and is not a directory"
    fi

    if [[ ! -d "$path" ]]; then
        install -d "$path"
        fix_target_ownership "$path"
    fi
}

apt_package_available() {
    apt-cache show "$1" >/dev/null 2>&1
}

install_apt_packages() {
    local label="$1"
    shift

    if [[ "$#" -eq 0 ]]; then
        return
    fi

    log "Installing $label packages: $*"
    sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

install_apt_optional_packages() {
    local available_packages=()
    local skipped_packages=()
    local package_name

    for package_name in "$@"; do
        if apt_package_available "$package_name"; then
            available_packages+=("$package_name")
        else
            skipped_packages+=("$package_name")
        fi
    done

    install_apt_packages "optional common tool" "${available_packages[@]}"

    if [[ "${#skipped_packages[@]}" -gt 0 ]]; then
        log "Skipped unavailable optional packages: ${skipped_packages[*]}"
    fi
}

install_apt_first_available_package() {
    local label="$1"
    shift

    local package_name
    for package_name in "$@"; do
        if apt_package_available "$package_name"; then
            install_apt_packages "$label" "$package_name"
            return
        fi
    done

    log "Skipped unavailable $label package candidates: $*"
}

install_ssh_client_packages() {
    if ! flag_enabled "$CONFIGURE_SSH" CONFIGURE_SSH; then
        log "Skipping SSH packages"
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        install_apt_packages "ssh client" "${APT_SSH_CLIENT_PACKAGES[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        log "Installing ssh client packages with dnf"
        sudo_cmd dnf install -y "${DNF_SSH_CLIENT_PACKAGES[@]}"
    elif command -v yum >/dev/null 2>&1; then
        log "Installing ssh client packages with yum"
        sudo_cmd yum install -y "${YUM_SSH_CLIENT_PACKAGES[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        log "Installing ssh client packages with pacman"
        sudo_cmd pacman -Sy --needed --noconfirm "${PACMAN_SSH_CLIENT_PACKAGES[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        log "Installing ssh client packages with zypper"
        sudo_cmd zypper --non-interactive install "${ZYPPER_SSH_CLIENT_PACKAGES[@]}"
    elif command -v apk >/dev/null 2>&1; then
        log "Installing ssh client packages with apk"
        sudo_cmd apk add --no-cache "${APK_SSH_CLIENT_PACKAGES[@]}"
    fi
}

install_ssh_server_packages() {
    if ! flag_enabled "$CONFIGURE_SSH" CONFIGURE_SSH || ! flag_enabled "$INSTALL_SSH_SERVER" INSTALL_SSH_SERVER; then
        log "Skipping SSH server packages"
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        install_apt_packages "ssh server" "${APT_SSH_SERVER_PACKAGES[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        log "Installing ssh server packages with dnf"
        sudo_cmd dnf install -y "${DNF_SSH_SERVER_PACKAGES[@]}"
    elif command -v yum >/dev/null 2>&1; then
        log "Installing ssh server packages with yum"
        sudo_cmd yum install -y "${YUM_SSH_SERVER_PACKAGES[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        log "Installing ssh server packages with pacman"
        sudo_cmd pacman -Sy --needed --noconfirm "${PACMAN_SSH_SERVER_PACKAGES[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        log "Installing ssh server packages with zypper"
        sudo_cmd zypper --non-interactive install "${ZYPPER_SSH_SERVER_PACKAGES[@]}"
    elif command -v apk >/dev/null 2>&1; then
        log "Installing ssh server packages with apk"
        sudo_cmd apk add --no-cache "${APK_SSH_SERVER_PACKAGES[@]}"
    fi
}

install_ubuntu_packages() {
    log "Updating apt package indexes"
    sudo_cmd apt-get update
    install_apt_packages "required" "${APT_REQUIRED_PACKAGES[@]}"
    install_apt_optional_packages "${APT_COMMON_PACKAGES[@]}"
    install_apt_first_available_package "ctags support" "${APT_CTAG_PACKAGE_CANDIDATES[@]}"
}

install_basic_packages_with_manager() {
    local manager="$1"
    shift

    log "Installing common packages with $manager"
    sudo_cmd "$manager" "$@" "${BASIC_MANAGER_PACKAGES[@]}"
}

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        install_ubuntu_packages
    elif command -v dnf >/dev/null 2>&1; then
        install_basic_packages_with_manager dnf install -y
    elif command -v yum >/dev/null 2>&1; then
        install_basic_packages_with_manager yum install -y
    elif command -v pacman >/dev/null 2>&1; then
        log "Installing common packages with pacman"
        sudo_cmd pacman -Sy --needed --noconfirm "${PACMAN_PACKAGES[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        install_basic_packages_with_manager zypper --non-interactive install
    elif command -v apk >/dev/null 2>&1; then
        log "Installing common packages with apk"
        sudo_cmd apk add --no-cache "${APK_PACKAGES[@]}"
    else
        die "Unsupported package manager. Install zsh, git, curl, and ripgrep manually, then rerun this script."
    fi

    install_ssh_client_packages
    install_ssh_server_packages
}

clone_or_update_repo() {
    local repo_url="$1"
    local destination="$2"

    if [[ -d "$destination/.git" ]]; then
        log "Updating $destination"
        run_as_target_user git -C "$destination" pull --ff-only
    elif [[ -e "$destination" || -L "$destination" ]]; then
        local backup_path="${destination}.backup.${BACKUP_SUFFIX}"
        mv "$destination" "$backup_path"
        log "Backed up existing non-git path $destination to $backup_path"
        log "Cloning $repo_url to $destination"
        run_as_target_user git clone --depth=1 "$repo_url" "$destination"
    else
        log "Cloning $repo_url to $destination"
        run_as_target_user git clone --depth=1 "$repo_url" "$destination"
    fi

    fix_target_ownership "$destination"
}

install_oh_my_zsh() {
    ensure_directory "$TARGET_HOME"
    clone_or_update_repo "$OH_MY_ZSH_REPO_URL" "$OH_MY_ZSH_DIR"
}

install_custom_plugins() {
    ensure_directory "$ZSH_CUSTOM_DIR/plugins"
    fix_target_ownership "$OH_MY_ZSH_DIR" "$ZSH_CUSTOM_DIR"
    clone_or_update_repo "$ZSH_AUTOSUGGESTIONS_REPO_URL" "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
    clone_or_update_repo "$ZSH_SYNTAX_HIGHLIGHTING_REPO_URL" "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
}

backup_if_exists() {
    local path="$1"

    if [[ -e "$path" || -L "$path" ]]; then
        local backup_path="${path}.backup.${BACKUP_SUFFIX}"
        mv "$path" "$backup_path"
        log "Backed up $path to $backup_path"
    fi
}

string_in_array() {
    local needle="$1"
    shift

    local value
    for value in "$@"; do
        if [[ "$value" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

validate_vim_config_repo() {
    local source_dir="$1"

    [[ -d "$source_dir/.vim" ]] || die "$source_dir does not contain .vim"
    [[ -f "$source_dir/.vimrc" ]] || die "$source_dir does not contain .vimrc"
    [[ ! -L "$source_dir/.vim" ]] || die "$source_dir/.vim must not be a symlink"
    [[ ! -L "$source_dir/.vimrc" ]] || die "$source_dir/.vimrc must not be a symlink"

    local top_path
    local top_name
    for top_path in "$source_dir"/.[!.]* "$source_dir"/..?* "$source_dir"/*; do
        [[ -e "$top_path" || -L "$top_path" ]] || continue
        top_name="$(basename "$top_path")"

        case "$top_name" in
            .git|.vim|.vimrc)
                ;;
            *)
                die "Unexpected top-level path in vim config repo: $top_name"
                ;;
        esac
    done

    local symlink_path
    symlink_path="$(find "$source_dir/.vim" -type l -print -quit)"
    if [[ -n "$symlink_path" ]]; then
        die "Unexpected symlink in vim config repo: $symlink_path"
    fi

    local line
    local trimmed
    local line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        trimmed="${line#"${line%%[![:space:]]*}"}"

        case "$trimmed" in
            \"*|"")
                continue
                ;;
        esac

        if string_in_array "$trimmed" "${VIM_CONFIG_ALLOWED_SHELL_COMMANDS[@]}"; then
            continue
        fi

        case "$trimmed" in
            \!*|silent\ \!*|execute\ *\!*|silent\ execute\ *\!*|*system\(*|*job_start\(*|*term_start\(*|terminal\ *|:terminal\ *)
                die "Unexpected command execution in .vimrc:$line_number: $trimmed"
                ;;
        esac
    done < "$source_dir/.vimrc"
}

install_vim_config() {
    log "Installing vim settings from $VIM_CONFIG_REPO_URL"
    ensure_directory "$TARGET_HOME"
    clone_or_update_repo "$VIM_CONFIG_REPO_URL" "$VIM_CONFIG_REPO_DIR"
    validate_vim_config_repo "$VIM_CONFIG_REPO_DIR"

    backup_if_exists "$TARGET_HOME/.vimrc"
    cp "$VIM_CONFIG_REPO_DIR/.vimrc" "$TARGET_HOME/.vimrc"
    chmod 0644 "$TARGET_HOME/.vimrc"

    backup_if_exists "$TARGET_HOME/.vim"
    cp -a "$VIM_CONFIG_REPO_DIR/.vim" "$TARGET_HOME/.vim"
    find "$TARGET_HOME/.vim" -type d -exec chmod 0755 {} +
    find "$TARGET_HOME/.vim" -type f -exec chmod 0644 {} +

    fix_target_ownership "$TARGET_HOME/.vimrc" "$TARGET_HOME/.vim" "$VIM_CONFIG_REPO_DIR"
}

write_ssh_client_config() {
    if ! flag_enabled "$WRITE_SSH_CLIENT_CONFIG" WRITE_SSH_CLIENT_CONFIG; then
        return
    fi

    local config_path="$TARGET_HOME/.ssh/config"
    if [[ -e "$config_path" || -L "$config_path" ]]; then
        log "Preserving existing ssh client config at $config_path"
        return
    fi

    cat > "$config_path" <<EOF
Host *
    ServerAliveInterval $SSH_CLIENT_SERVER_ALIVE_INTERVAL
    ServerAliveCountMax $SSH_CLIENT_SERVER_ALIVE_COUNT_MAX
EOF
    chmod 0600 "$config_path"
    fix_target_ownership "$config_path"
}

install_ssh_user_config() {
    ensure_directory "$TARGET_HOME"
    ensure_directory "$TARGET_HOME/.ssh"
    chmod 0700 "$TARGET_HOME/.ssh"
    fix_target_ownership "$TARGET_HOME/.ssh"

    if [[ -n "$SSH_AUTHORIZED_KEYS_SOURCE" ]]; then
        backup_if_exists "$TARGET_HOME/.ssh/authorized_keys"
        install -m 0600 "$SSH_AUTHORIZED_KEYS_SOURCE" "$TARGET_HOME/.ssh/authorized_keys"
        fix_target_ownership "$TARGET_HOME/.ssh/authorized_keys"
    fi

    write_ssh_client_config
}

ensure_sshd_config_includes_dropins() {
    local main_config="/etc/ssh/sshd_config"

    if [[ ! -f "$main_config" ]]; then
        return
    fi

    if sudo_cmd grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf([[:space:]]|$)' "$main_config"; then
        return
    fi

    local backup_path="${main_config}.backup.${BACKUP_SUFFIX}"
    sudo_cmd cp -a "$main_config" "$backup_path"
    log "Backed up $main_config to $backup_path"

    printf '\nInclude /etc/ssh/sshd_config.d/*.conf\n' | sudo_cmd tee -a "$main_config" >/dev/null
}

find_sshd_binary() {
    local candidate
    for candidate in /usr/sbin/sshd /usr/local/sbin/sshd; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    candidate="$(command -v sshd 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    return 1
}

validate_sshd_configuration() {
    local sshd_path
    sshd_path="$(find_sshd_binary || true)"

    if [[ -z "$sshd_path" ]]; then
        log "Could not find sshd to validate server configuration"
        return
    fi

    sudo_cmd "$sshd_path" -t
}

install_sshd_config() {
    if ! flag_enabled "$INSTALL_SSH_SERVER" INSTALL_SSH_SERVER; then
        return
    fi

    local config_dir="/etc/ssh/sshd_config.d"
    local config_path="$config_dir/$SSHD_CONFIG_DROPIN_NAME"
    local temp_file

    sudo_cmd install -d -m 0755 "$config_dir"
    temp_file="$(mktemp)"
    cat > "$temp_file" <<EOF
# Managed by bootstrap_linux_env.sh.
Port $SSH_PORT
PubkeyAuthentication $SSH_PUBKEY_AUTHENTICATION
PasswordAuthentication $SSH_PASSWORD_AUTHENTICATION
PermitRootLogin $SSH_PERMIT_ROOT_LOGIN
AuthorizedKeysFile .ssh/authorized_keys
EOF

    sudo_cmd install -m 0644 "$temp_file" "$config_path"
    rm -f "$temp_file"
    ensure_sshd_config_includes_dropins
    validate_sshd_configuration
}

systemd_service_exists() {
    local service_name="$1"
    systemctl list-unit-files "${service_name}.service" --no-legend 2>/dev/null | grep -q "^${service_name}\.service"
}

manage_ssh_service() {
    if ! flag_enabled "$INSTALL_SSH_SERVER" INSTALL_SSH_SERVER || ! flag_enabled "$ENABLE_SSH_SERVER" ENABLE_SSH_SERVER; then
        return
    fi

    local service_name
    if command -v systemctl >/dev/null 2>&1; then
        for service_name in "${SSH_SERVICE_CANDIDATES[@]}"; do
            if systemd_service_exists "$service_name"; then
                if sudo_cmd systemctl enable "$service_name"; then
                    log "Enabled SSH service: $service_name"
                else
                    log "Could not enable SSH service: $service_name"
                fi

                if flag_enabled "$START_SSH_SERVER" START_SSH_SERVER; then
                    if sudo_cmd systemctl restart "$service_name"; then
                        log "Restarted SSH service: $service_name"
                    else
                        log "Could not restart SSH service: $service_name"
                    fi
                fi
                return
            fi
        done
    fi

    if command -v rc-update >/dev/null 2>&1 && command -v rc-service >/dev/null 2>&1; then
        if sudo_cmd rc-update add sshd default; then
            log "Enabled SSH service: sshd"
        fi

        if flag_enabled "$START_SSH_SERVER" START_SSH_SERVER; then
            sudo_cmd rc-service sshd restart || log "Could not restart SSH service: sshd"
        fi
        return
    fi

    if command -v service >/dev/null 2>&1; then
        for service_name in "${SSH_SERVICE_CANDIDATES[@]}"; do
            if sudo_cmd service "$service_name" status >/dev/null 2>&1; then
                if flag_enabled "$START_SSH_SERVER" START_SSH_SERVER; then
                    sudo_cmd service "$service_name" restart || log "Could not restart SSH service: $service_name"
                fi
                return
            fi
        done
    fi

    log "Could not find a known SSH service manager"
}

configure_ssh() {
    if ! flag_enabled "$CONFIGURE_SSH" CONFIGURE_SSH; then
        log "Skipping SSH configuration"
        return
    fi

    log "Configuring SSH"
    install_ssh_user_config
    install_sshd_config
    manage_ssh_service
}

write_zshrc() {
    cat <<'EOF'
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    extract
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
[[ -f ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh
EOF
}

write_aliases() {
    cat <<'EOF'
# --- Navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
alias desktop="cd ~/Desktop"
alias dev="cd /mnt/c/develop"

# --- Better Default Commands ---
alias ll="ls -alF"              # Long list, all files
alias la="ls -A"                # Show hidden files
alias c="clear"                 # Faster clearing
alias h="history"               # Show full history
alias hg="history | grep git"   # Show full history of git command
alias rf="sudo rm -r"           # Reomve with sudo

# --- Git Shortcuts (If not using the git plugin) ---
alias gs="git status"
alias ga="git add"
alias gaa="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"

# --- Utilities ---
alias reload="source ~/.zshrc"                      # Apply changes instantly
alias myip="curl -s https://ifconfig.me; echo"      # Show public IP
EOF
}

install_dotfiles() {
    log "Installing embedded zsh settings to $TARGET_HOME"
    ensure_directory "$TARGET_HOME"

    backup_if_exists "$TARGET_HOME/.zshrc"
    write_zshrc > "$TARGET_HOME/.zshrc"
    chmod 0644 "$TARGET_HOME/.zshrc"

    backup_if_exists "$TARGET_HOME/.zsh"
    ensure_directory "$TARGET_HOME/.zsh"
    write_aliases > "$TARGET_HOME/.zsh/aliases.zsh"
    chmod 0644 "$TARGET_HOME/.zsh/aliases.zsh"

    fix_target_ownership "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh"
}

ensure_shell_registered() {
    local shell_path="$1"

    if [[ -f /etc/shells ]] && grep -Fxq "$shell_path" /etc/shells; then
        return
    fi

    log "Registering $shell_path in /etc/shells"
    printf '%s\n' "$shell_path" | sudo_cmd tee -a /etc/shells >/dev/null
}

change_default_shell() {
    if [[ "$SET_DEFAULT_SHELL" -eq 0 ]]; then
        log "Skipping login shell change"
        return
    fi

    local zsh_path
    zsh_path="$(command -v zsh)" || die "zsh was not found after installation"
    ensure_shell_registered "$zsh_path"

    local current_shell="${SHELL:-}"
    if command -v getent >/dev/null 2>&1; then
        current_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7 || true)"
    fi

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log "Default shell for $TARGET_USER is already $zsh_path"
        return
    fi

    if sudo_cmd chsh -s "$zsh_path" "$TARGET_USER"; then
        log "Default shell for $TARGET_USER changed to $zsh_path"
    else
        log "Could not change the default shell automatically. Run: chsh -s $zsh_path $TARGET_USER"
    fi
}

verify_core_tools() {
    local missing_tools=()
    local tool

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if [[ "$tool" == "ssh" ]] && ! flag_enabled "$CONFIGURE_SSH" CONFIGURE_SSH; then
            continue
        fi

        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ "${#missing_tools[@]}" -gt 0 ]]; then
        die "Missing expected tools after installation: ${missing_tools[*]}"
    fi
}

main() {
    log "Configuring user $TARGET_USER at $TARGET_HOME"
    require_sudo_access
    setup_cleanup_traps
    start_sudo_keepalive
    install_packages
    verify_core_tools
    configure_ssh
    install_vim_config
    install_oh_my_zsh
    install_custom_plugins
    install_dotfiles
    change_default_shell
    log "Done. Start a new terminal session or run: exec zsh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    parse_args "$@"
    resolve_configuration
    main
fi
