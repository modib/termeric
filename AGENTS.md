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
├── Homebrew/
│   └── termeric.rb         # Homebrew formula
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
`termeric_bash` and `termeric_zsh` must maintain **visual parity** — same layout, same features, same colors. Only the implementation mechanism differs.

### Feature toggles (env vars)
All features controlled via `on`/`off` values. Backward compat: `1`/`0` also accepted.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GIT_COLORS` | `on` | Powerline-style background segments |
| `PROMPT_EXIT_CODE` | `on` | Show ✓/✗ exit code indicator |
| `PROMPT_CMD_TIME` | `off` | Show command duration when ≥2s |

### Git status caching
- Uses `.git/.termeric_cache` and `.git/.termeric_result`
- Cache key: mtime of `.git/HEAD` + `.git/index`
- Invalidated automatically on commit, checkout, etc.

### Adding new features
1. Add in both `termeric_bash` and `termeric_zsh` (maintain parity)
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
- Verify both powerline mode (`GIT_COLORS=on`) and normal mode

### Versioning
- Update `VERSION` file before release
- GitHub Actions auto-builds packages on tag push
