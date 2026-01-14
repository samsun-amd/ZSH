# --- Navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
alias desktop="cd ~/Desktop"
alias dev="cd /mnt/c/develop"
alias s="cd /home/chisun/script"

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
