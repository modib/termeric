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
| `PROMPT_COLOR` | `on` | Master color switch: `on` (default) or `off` |
| `PROMPT_STYLE` | `0` | Prompt style: `0`=powerline, `1`=basename, `2`=abbreviated, `3`=full path, `4`=long text |
| `PROMPT_SHOW_USER` | `on` | Show user@host segment |
| `PROMPT_SHOW_EXIT` | `on` | Show exit code on failure |
| `PROMPT_SHOW_DIR` | `on` | Show directory path |
| `PROMPT_SHOW_SSH` | `on` | Show SSH indicator when connected |
| `PROMPT_SHOW_TIME` | `off` | Show command duration when ≥2s |

**bash/zsh** (in `~/.bashrc` or `~/.zshrc`):

```bash
export PROMPT_COLOR=on         # or off for no colors
export PROMPT_STYLE=0          # 0=powerline, 1=basename, 2=abbreviated, 3=full path, 4=long text
export PROMPT_SHOW_USER=on
export PROMPT_SHOW_EXIT=on
export PROMPT_SHOW_DIR=on
export PROMPT_SHOW_SSH=on
export PROMPT_SHOW_TIME=off
```

**fish** (in `~/.config/fish/config.fish`):

```fish
set -g PROMPT_COLOR on         # or off for no colors
set -g PROMPT_STYLE 0          # 0=powerline, 1=basename, 2=abbreviated, 3=full path, 4=long text
set -g PROMPT_SHOW_USER on
set -g PROMPT_SHOW_EXIT on
set -g PROMPT_SHOW_DIR on
set -g PROMPT_SHOW_SSH on
set -g PROMPT_SHOW_TIME off
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

**Powerline mode** (default, `PROMPT_STYLE=0`) — same across bash, zsh, fish:

```
 user@host  ~/project   main +2 ~1 ?3 
❯❯
```

**Long text mode** (`PROMPT_STYLE=4`):

```
user@host ~/project ( main +2 ~1 ?3)
❯❯
```

## Performance

Termeric is optimized for speed:

- **Git status cache** — stores results in `~/.cache/termeric/`, only recomputes when HEAD or index changes
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

## Documentation

Full documentation is available on the [GitHub Pages site](https://modib.github.io/termeric/).

## License

MIT
