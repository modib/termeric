#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Version ─────────────────────────────────────────────────────
TERMERIC_VERSION="${TERMERIC_VERSION:-1.1.0}"

# ── Colors ──────────────────────────────────────────────────────
if [ -t 1 ]; then
	GOLD='\033[38;2;220;180;0m'
	GREEN='\033[32m'
	RED='\033[31m'
	CYAN='\033[36m'
	BOLD='\033[1m'
	RESET='\033[0m'
else
	GOLD='' GREEN='' RED='' CYAN='' BOLD='' RESET=''
fi

_info() { printf "${CYAN}▸${RESET} %s\n" "$*"; }
_ok() { printf "${GREEN}✓${RESET} %s\n" "$*"; }
_warn() { printf "${GOLD}⚠${RESET} %s\n" "$*"; }
_err() { printf "${RED}✗${RESET} %s\n" "$*" >&2; }

# ── Help ────────────────────────────────────────────────────────
show_help() {
	cat <<EOF
${GOLD}${BOLD}termeric${RESET} install script

Usage: install.sh [OPTIONS]

Options:
  --prefix DIR     Install prefix (default: /usr/local)
  --link           Symlink instead of copy (for dev)
  --font           Install Meslo Nerd Font
  --uninstall      Remove termeric
  --help           Show this message

Environment variables:
  PROMPT_COLOR=on        Master color switch: on (default) or off
  PROMPT_SHOW_USER=on    Show user@host segment (default: on)
  PROMPT_SHOW_EXIT=on    Show exit code on failure (default: on)
  PROMPT_SHOW_DIR=on     Show directory path (default: on)
  PROMPT_SHOW_SSH=on     Show SSH indicator (default: on)
  PROMPT_SHOW_TIME=off   Show command duration (default: off)
EOF
}

# ── Parse args ──────────────────────────────────────────────────
INSTALL_PREFIX="${PREFIX:-/usr/local}"
INSTALL_FONT=0
INSTALL_LINK=0
DO_UNINSTALL=0

for arg in "$@"; do
	case "$arg" in
	--prefix)
		shift
		INSTALL_PREFIX="$1"
		shift
		;;
	--prefix=*) INSTALL_PREFIX="${arg#*=}" ;;
	--font) INSTALL_FONT=1 ;;
	--link) INSTALL_LINK=1 ;;
	--uninstall) DO_UNINSTALL=1 ;;
	--help)
		show_help
		exit 0
		;;
	*)
		_err "Unknown option: $arg"
		show_help
		exit 1
		;;
	esac
done

# ── Detect shell ────────────────────────────────────────────────
detect_shell() {
	local shell_name
	shell_name="$(basename "${SHELL:-}" 2>/dev/null || true)"
	if [ -z "$shell_name" ]; then
		shell_name="$(basename "$(ps -p $$ -o comm= 2>/dev/null)" 2>/dev/null || echo "bash")"
	fi
	echo "$shell_name"
}

# ── Font helpers ────────────────────────────────────────────────
nerd_font_installed() {
	if ls ~/Library/Fonts/ 2>/dev/null | grep -qi "meslo.*nerd\|nerd.*meslo"; then return 0; fi
	if ls ~/.local/share/fonts/ 2>/dev/null | grep -qi "meslo.*nerd\|nerd.*meslo"; then return 0; fi
	if ls ~/.fonts/ 2>/dev/null | grep -qi "meslo.*nerd\|nerd.*meslo"; then return 0; fi
	if command -v fc-list &>/dev/null && fc-list 2>/dev/null | grep -qi "meslo.*nerd\|nerd.*meslo"; then return 0; fi
	return 1
}

_download_font() {
	local target_dir="$1"
	local url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip"

	if ! command -v unzip &>/dev/null; then
		_err "'unzip' is required. Install it first."
		return 1
	fi

	local downloader
	if command -v curl &>/dev/null; then
		downloader="curl -fsSL"
	elif command -v wget &>/dev/null; then
		downloader="wget -qO"
	else
		_err "Neither curl nor wget found."
		return 1
	fi

	local tmpdir
	tmpdir="$(mktemp -d)"
	(
		cd "$tmpdir" || exit 1
		_info "Downloading Meslo Nerd Font..."
		$downloader "$url" -o Meslo.zip || {
			_err "Download failed."
			exit 1
		}
		unzip -q Meslo.zip -d meslo-nerd || {
			_err "Extraction failed."
			exit 1
		}
		mkdir -p "$target_dir"
		cp meslo-nerd/*.ttf "$target_dir/"
	)
	local status=$?
	rm -rf "$tmpdir"
	return $status
}

install_font() {
	if nerd_font_installed; then
		_ok "Meslo Nerd Font already installed."
		return 0
	fi

	_info "Installing Meslo Nerd Font..."

	if [ "$(uname)" = "Darwin" ]; then
		if command -v brew &>/dev/null; then
			brew install --cask font-meslo-lg-nerd-font
		else
			_download_font "$HOME/Library/Fonts"
		fi
	elif command -v apt &>/dev/null; then
		sudo apt install -y fonts-meslo-lg-nerd-font 2>/dev/null || _download_font "$HOME/.local/share/fonts" && fc-cache -f
	elif command -v dnf &>/dev/null; then
		sudo dnf install -y meslo-lg-nerd-fonts 2>/dev/null || _download_font "$HOME/.local/share/fonts" && fc-cache -f
	elif command -v pacman &>/dev/null; then
		if command -v yay &>/dev/null; then yay -S --noconfirm nerd-fonts-meslo 2>/dev/null && return 0; fi
		_download_font "$HOME/.local/share/fonts" && fc-cache -f
	else
		_download_font "$HOME/.local/share/fonts" && fc-cache -f
	fi

	_ok "Font installed. Set your terminal to use 'MesloLGL Nerd Font'."
}

# ── Uninstall ───────────────────────────────────────────────────
do_uninstall() {
	_info "Uninstalling termeric..."

	rm -f "$HOME/.termeric_bash" "$HOME/.termeric_zsh"

	for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
		if [ -f "$rc_file" ]; then
			sed -i.bak '/# termeric — golden prompt/,+4d' "$rc_file" 2>/dev/null ||
				sed -i '' '/# termeric — golden prompt/,+4d' "$rc_file" 2>/dev/null || true
			rm -f "${rc_file}.bak"
		fi
	done

	rm -f "$HOME/.local/bin/termeric"

	_ok "Termeric removed. Restart your shell."
}

# ── Install ─────────────────────────────────────────────────────
do_install() {
	local shell_name
	shell_name="$(detect_shell)"
	_info "Detected shell: ${BOLD}$shell_name${RESET}"

	# Copy shell configs
	local share_dir="$INSTALL_PREFIX/share/termeric"
	mkdir -p "$share_dir"

	if [ "$INSTALL_LINK" -eq 1 ]; then
		ln -sf "$DOTFILES_DIR/termeric_bash" "$HOME/.termeric_bash"
		ln -sf "$DOTFILES_DIR/termeric_zsh" "$HOME/.termeric_zsh"
		_ok "Symlinked configs to ~/.termeric_*"
	else
		cp "$DOTFILES_DIR/termeric_bash" "$HOME/.termeric_bash"
		cp "$DOTFILES_DIR/termeric_zsh" "$HOME/.termeric_zsh"
		_ok "Copied configs to ~/.termeric_*"
	fi

	# Source in bashrc
	if ! grep -qxF '[ -f ~/.termeric_bash ] && . ~/.termeric_bash' "$HOME/.bashrc" 2>/dev/null; then
		{
			echo ""
			echo "# termeric — golden prompt"
			echo 'if [ -f ~/.termeric_bash ]; then'
			echo '    . ~/.termeric_bash'
			echo 'fi'
		} >>"$HOME/.bashrc"
		_ok "Added source line to ~/.bashrc"
	fi

	# Source in zshrc
	if ! grep -qxF '[ -f ~/.termeric_zsh ] && . ~/.termeric_zsh' "$HOME/.zshrc" 2>/dev/null; then
		{
			echo ""
			echo "# termeric — golden prompt"
			echo 'if [ -f ~/.termeric_zsh ]; then'
			echo '    . ~/.termeric_zsh'
			echo 'fi'
		} >>"$HOME/.zshrc"
		_ok "Added source line to ~/.zshrc"
	fi

	# Install CLI
	mkdir -p "$HOME/.local/bin"
	if [ "$INSTALL_LINK" -eq 1 ]; then
		ln -sf "$DOTFILES_DIR/bin/termeric" "$HOME/.local/bin/termeric"
	else
		cp "$DOTFILES_DIR/bin/termeric" "$HOME/.local/bin/termeric"
		chmod +x "$HOME/.local/bin/termeric"
	fi

	case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) _warn "Add ~/.local/bin to your PATH:\n  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
	esac

	# Font
	if [ "$INSTALL_FONT" -eq 1 ]; then
		install_font
	fi

	echo ""
	_ok "Termeric installed! Run ${BOLD}exec $shell_name${RESET} or open a new terminal."
}

# ── Main ────────────────────────────────────────────────────────
if [ "$DO_UNINSTALL" -eq 1 ]; then
	do_uninstall
else
	do_install
fi
