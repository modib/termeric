# termeric

**Golden prompts for your terminal.**

A modernized, AI-ready shell prompt for bash, zsh, and fish with powerline segments, git status caching, and sub-10ms rendering.

## Features

- **Powerline segments** — colored background segments with arrow separators
- **Git status caching** — only recompute when the working tree changes
- **Fast rendering** — eliminated subshells, early exits, no redundant forks
- **Command timing** — shows duration for long-running commands
- **Exit code indicator** — visual check/cross for success/failure
- **Cross-platform** — macOS, Linux, any terminal with truecolor support
- **Zero dependencies** — pure bash/zsh, no Python, no Node

## Quick Start

### macOS (Homebrew)

```bash
brew tap modib/termeric
brew install termeric
termeric install
exec zsh
```

### Linux (Debian/Ubuntu)

```bash
# Download latest .deb from GitHub Releases
dpkg -i termeric_*.deb
termeric install
exec bash
```

### Any Platform

```bash
curl -fsSL https://raw.githubusercontent.com/modib/termeric/main/install.sh | bash
```

### From Source

```bash
git clone https://github.com/modib/termeric.git
cd termeric
make install
termeric install
exec bash  # or exec zsh
```

## Configuration

Set these in your shell config **before** sourcing termeric:

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_COLORS` | `on` | Powerline segments with background colors |
| `PROMPT_EXIT_CODE` | `on` | Show ✓/✗ exit code indicator |
| `PROMPT_CMD_TIME` | `off` | Show command duration when ≥2s |
| `PROMPT_COLOR_MODE` | `256color` | Color mode: `256color` (truecolor) or `xterm` (16-color) |
| `PROMPT_USER_HOST` | `on` | Show user@host segment |

**bash/zsh** (in `~/.bashrc` or `~/.zshrc`):

```bash
export GIT_COLORS=on
export PROMPT_EXIT_CODE=on
export PROMPT_CMD_TIME=on
export PROMPT_COLOR_MODE=256color  # or xterm for basic terminals
export PROMPT_USER_HOST=on
```

**fish** (in `~/.config/fish/config.fish`):

```fish
set -g GIT_COLORS on
set -g PROMPT_EXIT_CODE on
set -g PROMPT_CMD_TIME on
```

## CLI Commands

```
termeric install       # Install to current shell
termeric uninstall     # Remove from shell config
termeric update        # Pull latest and reinstall
termeric config        # Open config in $EDITOR
termeric status        # Show current settings
termeric font          # Install Meslo Nerd Font
termeric doctor        # Check system compatibility
termeric version       # Show version
```

## Prompt Preview

**Powerline mode** (default) — same across bash, zsh, fish:

```
✓  user@host  ~/project  main +2 ~1 ?3  3s
$
```

**Normal mode** (`GIT_COLORS=off`):

```
✓ user@host ~/project (main +2 ~1 ?3) [3s]
$
```

## Performance

Termeric is optimized for speed:

- **Git status cache** — stores results in `.git/.termeric_cache`, only recomputes when HEAD or index changes
- **No subshells** — git info uses process substitution, not `$(command)` capture
- **Early exit** — skips git commands entirely outside git repos
- **Pre-computed flags** — terminal detection runs once at source time

Benchmark (100 prompt renders in a medium git repo):

| Tool | Avg render time |
|------|----------------|
| starship | ~45ms |
| oh-my-posh | ~80ms |
| **termeric** | **~8ms** |

## AI Features (Coming Soon)

Termeric is being built with AI-powered features:

- **Intent detection** — predict what you're trying to do
- **Command explanation** — annotate what each command does
- **Error translation** — rewrite cryptic errors in plain English
- **Natural language** — type descriptions, get commands

## License

MIT
