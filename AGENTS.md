# Agent Guide — termeric

## Repo structure

```
termeric/
├── termeric_bash           # bash prompt (optimized, cached)
├── termeric_zsh            # zsh prompt  (optimized, cached)
├── termeric_fish           # fish prompt (optimized, cached)
├── bin/termeric            # CLI entry point
├── completions/            # shell completions
│   ├── termeric.bash
│   ├── termeric.zsh
│   └── termeric.fish
├── packaging/
│   ├── Makefile
│   ├── deb/                # Debian package
│   ├── rpm/                # RPM package
│   └── aur/                # Arch AUR
├── .github/workflows/
│   ├── ci.yml              # Test + lint + build
│   └── release.yml         # GitHub Release
├── install.sh              # Universal installer
├── LICENSE
├── README.md
├── VERSION
└── AGENTS.md               # this file
```

## Conventions

### Prompt parity
`termeric_bash`, `termeric_zsh`, and `termeric_fish` must maintain **visual parity** — same layout, same features, same colors. Only the implementation mechanism differs.

### Feature toggles (env vars)
All features controlled via `on`/`off` values. Backward compat: `1`/`0` also accepted.

| Variable | Default | Purpose |
|----------|---------|---------|
| `PROMPT_COLOR` | `on` | Master color switch (`on`/`off`) |
| `PROMPT_STYLE` | `0` | Prompt style: `0`=powerline, `1`=basename, `2`=abbreviated, `3`=full path, `4`=long text |
| `PROMPT_SHOW_USER` | `on` | Show user@host segment |
| `PROMPT_SHOW_EXIT` | `on` | Show exit code on failure |
| `PROMPT_SHOW_DIR` | `on` | Show directory path |
| `PROMPT_SHOW_SSH` | `on` | Show SSH indicator when connected |
| `PROMPT_SHOW_TIME` | `off` | Show command duration when ≥2s |
| `PROMPT_VENV` | `off` | Show Python virtualenv/conda name |
| `PROMPT_NODE` | `off` | Show Node.js version |
| `PROMPT_K8S` | `off` | Show Kubernetes context |

### Git status caching
- Uses `~/.cache/termeric/<repo-hash>.{cache,result}` (XDG-compliant)
- Cache key: mtime of `.git/HEAD` + `.git/index`
- Invalidated automatically on commit, checkout, etc.
- Old per-repo cache files (`.git/.termeric_*`) auto-cleaned on cache write

### Adding new features
1. Add in all 3 shell files (`termeric_bash`, `termeric_zsh`, `termeric_fish`)
2. Add an env var toggle in the `on`/`off` convention
3. Update `bin/termeric` if any CLI logic changes
4. Update `README.md` with the new feature
5. Update this file

### Testing changes
- Run `bash -n termeric_bash` for bash syntax check
- Run `zsh -n termeric_zsh` for zsh syntax check
- Run `fish -n termeric_fish` for fish syntax check
- Run `bash -n bin/termeric` for CLI syntax check
- Run `./bin/termeric doctor` to verify system readiness
- Source the file in a new shell and verify the prompt renders
- Verify powerline mode (`PROMPT_STYLE=0`) and text modes (`PROMPT_STYLE=1`, `2`, `3`, `4`)
- Verify monochrome mode (`PROMPT_COLOR=off`)

### Versioning
- Update `VERSION` file before release
- GitHub Actions auto-builds packages on tag push
- Before first release that uses auto-publish: create a GitHub classic PAT with `public_repo` scope, save as `HOMEBREW_TAP_TOKEN` in repo secrets

## Roadmap

### Phase 1 — Done
- Fix all `PROMPT_USER_HOST` default documentation mismatches (README, header comments, Homebrew, AGENTS.md)
- Remove `PROMPT_USER_HOST` from fish docs example (fish didn't implement the toggle)
- Fix header `PROMPT_CMD_TIME` default from `on` → `off`

### Phase 2 — Done
- Eliminate `whoami`/`hostname` forks in fish prompt (use `$USER` + cached `hostname`)
- Guard `date +%s` preexec fork behind `PROMPT_CMD_TIME=on` check
- Add `PROMPT_USER_HOST` toggle to fish (all 3 modes: powerline, normal, monochrome)
- Convert fish color definitions to function with early-return guard (dynamic mode switching)
- Add trailing space after line 2 arrow for cleaner command alignment
- Fix install/uninstall blank-line accumulation in rc files

### Phase 2.5 — Done
- Fix `PROMPT_COMMAND` overwrite in bash prompt (use array/scalar append instead of clobber)
- Add `PROMPT_STYLE` to all docs (install.sh help, Homebrew caveats, test suite)
- Align post-install messages across `install.sh` and `termeric install` (source rc instead of exec)
- Unify version across all files (VERSION, bin/termeric, install.sh)
- Add PROMPT_COMMAND preservation tests to test suite

### Phase 3 — Done
- Python virtualenv/conda segment (`PROMPT_VENV=off`)
- Node.js version segment (`PROMPT_NODE=off`)
- Kubernetes context segment (`PROMPT_K8S=off`)
- Added color variables (BG_VENV, BG_NODE, BG_K8S, ARROW_VENV, ARROW_NODE, ARROW_K8S, TXT_VENV, TXT_NODE, TXT_K8S) and info functions to all 3 shells
- Added segment rendering in all 4 style paths (powerline, style 4, styles 1/2, monochrome)
- Updated bin/termeric (help, config template, status, doctor)
- Updated install.sh help, Homebrew caveats, README.md, AGENTS.md

### Phase 4 — Future
- AI features (intent detection, command explanation, error translation, natural language)
