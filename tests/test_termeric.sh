#!/usr/bin/env bash
# termeric test suite — run locally before committing
# Usage: bash tests/test_termeric.sh

set -euo pipefail

TERMERIC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# ── Colors ──────────────────────────────────────────────────────
if [ -t 1 ]; then
    GREEN='\033[32m'
    RED='\033[31m'
    YELLOW='\033[33m'
    CYAN='\033[36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

pass() { PASS=$((PASS+1)); printf "%b %s\n" "${GREEN}✓${RESET}" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "%b %s\n" "${RED}✗${RESET}" "$1"; }
skip() { SKIP=$((SKIP+1)); printf "%b %s\n" "${YELLOW}⊘${RESET}" "$1"; }
header() { printf "\n%b%b%s%b\n" "${CYAN}${BOLD}" "─── " "$1 " "${RESET}"; }
check() {
    if [ "$1" -eq 0 ]; then pass "$2"; else fail "$2"; fi
    return "$1"
}

# ================================================================
header "1. Syntax checks"
# ================================================================

check_syntax() {
    local file="$1" name="$2" cmd="$3" lang="$4"
    if ! command -v "$lang" &>/dev/null; then
        skip "syntax: $name ($lang not installed)"
        return 0
    fi
    if eval "$cmd" 2>/dev/null; then
        pass "syntax: $name"
        return 0
    else
        fail "syntax: $name"
        return 1
    fi
}

check_syntax "$TERMERIC_DIR/termeric_bash" "termeric_bash"      "bash -n '$TERMERIC_DIR/termeric_bash'" bash
check_syntax "$TERMERIC_DIR/termeric_zsh"  "termeric_zsh"       "zsh -n  '$TERMERIC_DIR/termeric_zsh'"  zsh
check_syntax "$TERMERIC_DIR/bin/termeric"  "bin/termeric"       "bash -n '$TERMERIC_DIR/bin/termeric'" bash
check_syntax "$TERMERIC_DIR/install.sh"    "install.sh"         "bash -n '$TERMERIC_DIR/install.sh'"   bash
if command -v fish &>/dev/null; then
    check_syntax "$TERMERIC_DIR/termeric_fish" "termeric_fish" "fish --no-execute '$TERMERIC_DIR/termeric_fish'" fish
else
    skip "syntax: termeric_fish (fish not installed)"
fi

# ================================================================
header "2. File existence"
# ================================================================

files_missing=0
for f in \
    "termeric_bash" "termeric_zsh" "termeric_fish" \
    "bin/termeric" \
    "install.sh" \
    "completions/termeric.bash" "completions/termeric.zsh" "completions/termeric.fish" \
    "packaging/Makefile" \
    "packaging/deb/control" \
    "packaging/rpm/termeric.spec" \
    "packaging/aur/PKGBUILD" \
    "docs/index.html" \
    "VERSION" "LICENSE" "README.md" "AGENTS.md" \
    "fonts/MesloLGLNerdFont-Regular.ttf" \
; do
    if [ -f "$TERMERIC_DIR/$f" ]; then
        pass "exists: $f"
    else
        fail "exists: $f (MISSING)"
        files_missing=$((files_missing+1))
    fi
done

# ================================================================
header "3. Toggle name audit — no old names"
# ================================================================

for shell_file in "$TERMERIC_DIR/termeric_bash" "$TERMERIC_DIR/termeric_zsh" "$TERMERIC_DIR/termeric_fish"; do
    name=$(basename "$shell_file")
    for old in "PROMPT_COLOR_MODE" "PROMPT_EXIT_CODE" "PROMPT_CMD_TIME" "PROMPT_USER_HOST" "PROMPT_SHORT"; do
        if grep -q "$old" "$shell_file" 2>/dev/null; then
            fail "$name: contains OLD toggle name $old"
        else
            :
            # Don't pass for each absence — too much noise. Only fail if found.
        fi
    done
done
# Invert: check all new names present
for shell_file in "$TERMERIC_DIR/termeric_bash" "$TERMERIC_DIR/termeric_zsh" "$TERMERIC_DIR/termeric_fish"; do
    name=$(basename "$shell_file")
    for new in "PROMPT_COLOR" "PROMPT_SHOW_USER" "PROMPT_SHOW_EXIT" "PROMPT_SHOW_DIR" "PROMPT_SHOW_SSH" "PROMPT_SHOW_TIME" "PROMPT_STYLE"; do
        if grep -q "$new" "$shell_file" 2>/dev/null; then
            pass "$name: contains $new"
        else
            fail "$name: missing toggle $new"
        fi
    done
done

# ================================================================
header "4. CLI and docs toggle name audit"
# ================================================================

for doc_file in "$TERMERIC_DIR/bin/termeric" "$TERMERIC_DIR/README.md" "$TERMERIC_DIR/install.sh" "$TERMERIC_DIR/docs/index.html"; do
    name=$(basename "$doc_file")
    for old in "PROMPT_COLOR_MODE" "PROMPT_EXIT_CODE" "PROMPT_CMD_TIME" "PROMPT_USER_HOST" "PROMPT_SHORT"; do
        if grep -q "$old" "$doc_file" 2>/dev/null; then
            fail "$name: still has OLD toggle $old"
        fi
    done
done

# Verify ALL toggle names present in ALL doc/CLI files
for doc_file in "$TERMERIC_DIR/bin/termeric" "$TERMERIC_DIR/README.md" "$TERMERIC_DIR/install.sh" "$TERMERIC_DIR/AGENTS.md"; do
    name=$(basename "$doc_file")
    for toggle in "PROMPT_COLOR" "PROMPT_STYLE" "PROMPT_SHOW_USER" "PROMPT_SHOW_EXIT" "PROMPT_SHOW_DIR" "PROMPT_SHOW_SSH" "PROMPT_SHOW_TIME"; do
        if ! grep -q "$toggle" "$doc_file" 2>/dev/null; then
            fail "$name: missing toggle $toggle"
        fi
    done
done

# ================================================================
header "5. Style rendering tests"
# ================================================================

# --- zsh ---
if command -v zsh &>/dev/null; then
    for style in 0 1 2 3 4; do
        output=$(zsh -c "
            source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
            PROMPT_STYLE=$style
            __termeric_prompt 2>/dev/null
            printf '%s' \"\$PROMPT\"
        " 2>/dev/null) || true
        if [ -n "$output" ]; then
            pass "zsh STYLE=$style: produces output (${#output} chars)"
        else
            fail "zsh STYLE=$style: empty output"
        fi
    done

    # Invalid style
    invalid_out=$(zsh -c "
        PROMPT_STYLE=99
        source '$TERMERIC_DIR/termeric_zsh' 2>&1 >/dev/null
    " 2>/dev/null) || true
    if echo "$invalid_out" | grep -q "invalid PROMPT_STYLE"; then
        pass "zsh invalid style: shows warning"
    else
        fail "zsh invalid style: no warning"
    fi

    # Default to 1
    default_style=$(zsh -c "
        PROMPT_STYLE=99
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        printf '%s' \"\$PROMPT_STYLE\"
    " 2>/dev/null) || true
    if [ "$default_style" = "1" ]; then
        pass "zsh invalid style: defaults to 1"
    else
        fail "zsh invalid style: defaults to $default_style (expected 1)"
    fi

    # Style 0 leading cap (ARROW_DARK in BG_FAIL + transition)
    cap_check=$(zsh -c "
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        PROMPT_STYLE=0
        PROMPT_SHOW_EXIT=off
        __termeric_prompt 2>/dev/null
        printf '%s' \"\$PROMPT\"
    " 2>/dev/null) || true
    if echo "$cap_check" | grep -q "48;2;60;60;60m.*38;2;60;60;60m"; then
        pass "zsh STYLE=0: ARROW_DARK in BG_FAIL (leading cap)"
    else
        fail "zsh STYLE=0: leading cap not found (BG_FAIL + ARROW_DARK)"
    fi

    # Style 3 shows full tilde path (not abbreviated)
    style3_path=$(zsh -c "
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        PROMPT_STYLE=3
        __termeric_prompt 2>/dev/null
        printf '%s' \"\$PROMPT\"
    " 2>/dev/null) || true
    # Style 3 should have at least some path characters (not empty)
    if [ -n "$style3_path" ]; then
        pass "zsh STYLE=3: produces output"
    else
        fail "zsh STYLE=3: empty output"
    fi

    # Runtime validation: PROMPT_STYLE=99 AFTER source should still render
    runtime_zsh=$(zsh -c "
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        PROMPT_STYLE=99
        __termeric_prompt 2>/dev/null
        printf '%s' \"\$PROMPT\"
    " 2>/dev/null) || true
    if [ -n "$runtime_zsh" ]; then
        pass "zsh STYLE=99 at runtime: produces output"
    else
        fail "zsh STYLE=99 at runtime: empty output"
    fi

    # Runtime warning on first use
    runtime_warn=$(zsh -c "
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        PROMPT_STYLE=99
        __termeric_prompt 2>&1
    " 2>/dev/null) || true
    if echo "$runtime_warn" | grep -q "invalid PROMPT_STYLE"; then
        pass "zsh STYLE=99 at runtime: shows warning"
    else
        fail "zsh STYLE=99 at runtime: no warning"
    fi

    # Style 0 fail segment: ARROW_FAIL should not appear (dark grey leading cap)
    fail_arrow_zsh=$(zsh -c "
        source '$TERMERIC_DIR/termeric_zsh' >/dev/null 2>&1
        PROMPT_STYLE=0
        false
        __termeric_prompt 2>/dev/null
        printf '%s' \"\$PROMPT\"
    " 2>/dev/null) || true
    red_count=$(echo "$fail_arrow_zsh" | grep -c "38;2;220;50;50" || true)
    if [ "$red_count" -eq 0 ]; then
        pass "zsh STYLE=0 fail arrow: 0 occurrences (ARROW_FAIL not used)"
    else
        fail "zsh STYLE=0 fail arrow: $red_count ARROW_FAIL occurrences (expected 0)"
    fi
else
    skip "zsh not available — skipping zsh tests"
fi

# --- bash ---
bash_styles_pass=0
for style in 0 1 2 3 4; do
    output=$(bash -c "
        source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
        PROMPT_STYLE=$style
        __termeric_ps1 2>/dev/null
        printf '%s' \"\$PS1\"
    " 2>/dev/null) || true
    if [ -n "$output" ]; then
        bash_styles_pass=$((bash_styles_pass+1))
    else
        fail "bash STYLE=$style: empty output"
    fi
done
[ "$bash_styles_pass" -eq 5 ] && pass "bash styles 0-4: all produce output"

# Invalid style
invalid_bash=$(bash -c "
    PROMPT_STYLE=99
    source '$TERMERIC_DIR/termeric_bash' 2>&1 >/dev/null
" 2>/dev/null) || true
if echo "$invalid_bash" | grep -q "invalid PROMPT_STYLE"; then
    pass "bash invalid style: shows warning"
else
    fail "bash invalid style: no warning"
fi

# Default to 1
default_bash=$(bash -c "
    PROMPT_STYLE=99
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    printf '%s' \"\$PROMPT_STYLE\"
" 2>/dev/null) || true
if [ "$default_bash" = "1" ]; then
    pass "bash invalid style: defaults to 1"
else
    fail "bash invalid style: defaults to $default_bash (expected 1)"
fi

# Style 0 leading cap
cap_bash=$(bash -c "
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    PROMPT_STYLE=0
    PROMPT_SHOW_EXIT=off
    __termeric_ps1 2>/dev/null
    printf '%s' \"\$PS1\"
" 2>/dev/null) || true
if echo "$cap_bash" | grep -q "48;2;60;60;60m.*38;2;60;60;60m"; then
    pass "bash STYLE=0: ARROW_DARK in BG_FAIL (leading cap)"
else
    fail "bash STYLE=0: leading cap not found"
fi

# Style 3 path
style3_bash=$(bash -c "
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    PROMPT_STYLE=3
    __termeric_ps1 2>/dev/null
    printf '%s' \"\$PS1\"
" 2>/dev/null) || true
if [ -n "$style3_bash" ]; then
    pass "bash STYLE=3: produces output"
else
    fail "bash STYLE=3: empty output"
fi

# Runtime validation: PROMPT_STYLE=99 AFTER source should still render
runtime_bash=$(bash -c "
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    PROMPT_STYLE=99
    __termeric_ps1 2>/dev/null
    printf '%s' \"\$PS1\"
" 2>/dev/null) || true
if [ -n "$runtime_bash" ]; then
    pass "bash STYLE=99 at runtime: produces output"
else
    fail "bash STYLE=99 at runtime: empty output"
fi

# Runtime warning on first use
runtime_warn_bash=$(bash -c "
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    PROMPT_STYLE=99
    __termeric_ps1 2>&1
" 2>/dev/null) || true
if echo "$runtime_warn_bash" | grep -q "invalid PROMPT_STYLE"; then
    pass "bash STYLE=99 at runtime: shows warning"
else
    fail "bash STYLE=99 at runtime: no warning"
fi

# Style 0 fail segment: ARROW_FAIL should not appear (dark grey leading cap)
fail_arrow_bash=$(bash -c "
    source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
    PROMPT_STYLE=0
    false
    __termeric_ps1 2>/dev/null
    printf '%s' \"\$PS1\"
" 2>/dev/null) || true
red_count=$(echo "$fail_arrow_bash" | grep -c "38;2;220;50;50" || true)
if [ "$red_count" -eq 0 ]; then
    pass "bash STYLE=0 fail arrow: 0 occurrences (ARROW_FAIL not used)"
else
    fail "bash STYLE=0 fail arrow: $red_count ARROW_FAIL occurrences (expected 0)"
fi

# --- fish ---
if command -v fish &>/dev/null && [ -z "${SKIP_FISH_TESTS:-}" ]; then
    FISH_TEST=$(fish -c 'source '$TERMERIC_DIR'/termeric_fish >/dev/null 2>&1; set -g PROMPT_STYLE 0; fish_prompt 2>/dev/null; printf "%s" "$data"' 2>/dev/null) || true
    if [ -n "$FISH_TEST" ]; then
        pass "fish STYLE=0: produces output"
    else
        fail "fish STYLE=0: empty output"
    fi

    for style in 1 2 3 4; do
        fout=$(fish -c "
            source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
            set -g PROMPT_STYLE $style
            fish_prompt 2>/dev/null
        " 2>/dev/null) || true
        if [ -n "$fout" ]; then
            :
        else
            fail "fish STYLE=$style: empty output"
        fi
    done
    pass "fish styles 1-4: all produce output"

    # Invalid style
    finvalid=$(fish -c "
        set -g PROMPT_STYLE 99
        source '$TERMERIC_DIR/termeric_fish' 2>&1 >/dev/null
    " 2>/dev/null) || true
    if echo "$finvalid" | grep -q "invalid PROMPT_STYLE"; then
        pass "fish invalid style: shows warning"
    else
        fail "fish invalid style: no warning"
    fi

    # Leading cap
    fcap=$(fish -c "
        source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
        set -g PROMPT_STYLE 0
        set -g PROMPT_SHOW_EXIT off
        fish_prompt 2>/dev/null
    " 2>/dev/null) || true
    if echo "$fcap" | grep -q "48;2;60;60;60m.*38;2;60;60;60m"; then
        pass "fish STYLE=0: ARROW_DARK in BG_FAIL (leading cap)"
    else
        fail "fish STYLE=0: leading cap not found"
    fi

    # Runtime validation: PROMPT_STYLE=99 AFTER source should still render
    runtime_fish=$(fish -c "
        source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
        set -g PROMPT_STYLE 99
        fish_prompt 2>/dev/null
    " 2>/dev/null) || true
    if [ -n "$runtime_fish" ]; then
        pass "fish STYLE=99 at runtime: produces output"
    else
        fail "fish STYLE=99 at runtime: empty output"
    fi

    # Style 0 fail segment: ARROW_FAIL should not appear (dark grey leading cap)
    fail_arrow_fish=$(fish -c "
        source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
        set -g PROMPT_STYLE 0
        false
        fish_prompt 2>/dev/null
    " 2>/dev/null) || true
    red_count=$(echo "$fail_arrow_fish" | grep -c "220;50;50" || true)
    if [ "$red_count" -eq 0 ]; then
        pass "fish STYLE=0 fail arrow: 0 occurrences (ARROW_FAIL not used)"
    else
        fail "fish STYLE=0 fail arrow: $red_count ARROW_FAIL occurrences (expected 0)"
    fi
else
    skip "fish not available — skipping fish tests"
fi

# ── Leading cap space color: BG_FAIL precedes space ──
# All leading cap patterns use BG_FAIL background with a space before the next segment's arrow
if grep -qE '\$\{BG_FAIL\} \$\{BG_' "$TERMERIC_DIR/termeric_zsh" 2>/dev/null; then
    pass "zsh leading cap: BG_FAIL before space"
else
    fail "zsh leading cap: missing BG_FAIL pattern"
fi
if grep -qE '\$\{BG_FAIL\} \$\{BG_' "$TERMERIC_DIR/termeric_bash" 2>/dev/null; then
    pass "bash leading cap: BG_FAIL before space"
else
    fail "bash leading cap: missing BG_FAIL pattern"
fi
if grep -qE '\$BG_FAIL \$BG_' "$TERMERIC_DIR/termeric_fish" 2>/dev/null; then
    pass "fish leading cap: BG_FAIL before space"
else
    fail "fish leading cap: missing BG_FAIL pattern"
fi

# ── _get_rc_val matches non-exported variables ──
rc_test_dir=$(mktemp -d)
rc_test_out=$(SHELL=/bin/bash bash -c "
    HOME='$rc_test_dir'
    mkdir -p \"\$HOME\"
    printf 'PROMPT_STYLE=2\n' > \"\$HOME/.bashrc\"
    export HOME
    bash '$TERMERIC_DIR/bin/termeric' status 2>/dev/null || true
" 2>/dev/null) || true
if echo "$rc_test_out" | grep -q "PROMPT_STYLE.*rc: 2"; then
    pass "status: reads PROMPT_STYLE without export"
else
    fail "status: did not read PROMPT_STYLE without export"
fi
rm -rf "$rc_test_dir"

# ================================================================
header "6. PROMPT_COMMAND preservation"
# ================================================================

# Verify PROMPT_COMMAND appends (doesn't overwrite)
pc_bash=$(bash -c '
    PROMPT_COMMAND=( "existing_func" )
    source "'$TERMERIC_DIR'/termeric_bash" >/dev/null 2>&1
    declare -p PROMPT_COMMAND 2>/dev/null
' 2>/dev/null) || true
if echo "$pc_bash" | grep -q "__termeric_ps1"; then
    pass "PROMPT_COMMAND: contains __termeric_ps1 after source"
else
    fail "PROMPT_COMMAND: __termeric_ps1 not found"
fi

# Array mode: __termeric_ps1 should be first
if echo "$pc_bash" | grep -q "declare -a"; then
    if echo "$pc_bash" | grep -q '__termeric_ps1.*existing_func'; then
        pass "PROMPT_COMMAND: __termeric_ps1 prepended (array)"
    else
        fail "PROMPT_COMMAND: array order incorrect"
    fi
    pass "PROMPT_COMMAND: preserved as array"
else
    # Scalar mode
    pc_scalar=$(bash -c '
        PROMPT_COMMAND="old_func"
        source "'$TERMERIC_DIR'/termeric_bash" >/dev/null 2>&1
        printf "%s" "$PROMPT_COMMAND"
    ' 2>/dev/null) || true
    if echo "$pc_scalar" | grep -q "__termeric_ps1.*old_func"; then
        pass "PROMPT_COMMAND: __termeric_ps1 chained with ; (scalar)"
    else
        fail "PROMPT_COMMAND: scalar chaining failed"
    fi
fi

# Empty PROMPT_COMMAND should still work
pc_empty=$(bash -c '
    unset PROMPT_COMMAND
    source "'$TERMERIC_DIR'/termeric_bash" >/dev/null 2>&1
    printf "%s" "$PROMPT_COMMAND"
' 2>/dev/null) || true
if [ "$pc_empty" = "__termeric_ps1" ]; then
    pass "PROMPT_COMMAND: works with unset PROMPT_COMMAND"
else
    fail "PROMPT_COMMAND: unset case failed (got: $pc_empty)"
fi

# ================================================================
header "7. Path shortening"
# ================================================================

# bash
if [ "$TERMERIC_DIR" = "$HOME/Workspace/dotfiles" ]; then
    skip "path shortening: not in workspace test dir"
else
    level1=$(bash -c "
        source '$TERMERIC_DIR/termeric_bash' >/dev/null 2>&1
        cd '$TERMERIC_DIR'
        __tmerm_shortened_path 1
    " 2>/dev/null) || true
    if [ "$level1" = "termeric" ]; then
        pass "bash __tmerm_shortened_path(1): basename"
    else
        fail "bash __tmerm_shortened_path(1): got '$level1' expected 'termeric'"
    fi
fi

# ================================================================
header "8. Install/uninstall simulation"
# ================================================================

TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

# Create fake HOME with rc files
mkdir -p "$TMPDIR"/{.config/fish,.local/bin}
touch "$TMPDIR/.bashrc" "$TMPDIR/.zshrc" "$TMPDIR/.config/fish/config.fish"

# Simulate install by running CLI in isolated env
HOME="$TMPDIR" bash "$TERMERIC_DIR/bin/termeric" install 2>/dev/null

# Check files copied
install_ok=0
for f in ".termeric_bash" ".termeric_zsh"; do
    if [ -f "$TMPDIR/$f" ]; then
        install_ok=$((install_ok+1))
    fi
done
[ "$install_ok" -eq 2 ] && pass "install: copied files to home" || fail "install: files missing"

# Check rc blocks have comment markers
for rc in ".bashrc" ".zshrc"; do
    if grep -q "termeric — golden prompt" "$TMPDIR/$rc" 2>/dev/null; then
        pass "install: $rc has comment marker"
    else
        fail "install: $rc missing comment marker"
    fi
done

# Check fish config
if grep -q "termeric_fish" "$TMPDIR/.config/fish/config.fish" 2>/dev/null; then
    pass "install: fish config has source line"
else
    fail "install: fish config missing source line"
fi

# Now simulate uninstall
HOME="$TMPDIR" bash "$TERMERIC_DIR/bin/termeric" uninstall 2>/dev/null || true

# Check files removed
uninstall_ok=0
for f in ".termeric_bash" ".termeric_zsh"; do
    if [ ! -f "$TMPDIR/$f" ]; then
        uninstall_ok=$((uninstall_ok+1))
    fi
done
[ "$uninstall_ok" -eq 2 ] && pass "uninstall: files removed" || fail "uninstall: files not removed"

# Check blocks removed from rc files
for rc in ".bashrc" ".zshrc"; do
    if grep -q "termeric" "$TMPDIR/$rc" 2>/dev/null; then
        fail "uninstall: $rc still has termeric reference"
    else
        pass "uninstall: $rc cleaned"
    fi
done

# Check fish config cleaned
if grep -q "termeric" "$TMPDIR/.config/fish/config.fish" 2>/dev/null; then
    fail "uninstall: fish config still has termeric reference"
else
    pass "uninstall: fish config cleaned"
fi

# Clear trap and clean up
trap - EXIT
rm -rf "$TMPDIR"

# --- CLI reads PROMPT_STYLE from rc file ---
rc_test_dir=$(mktemp -d)
rc_test_out=$(SHELL=/bin/bash bash -c "
    HOME='$rc_test_dir'
    mkdir -p \"\$HOME\"
    echo 'export PROMPT_STYLE=2' > \"\$HOME/.bashrc\"
    export HOME
    bash '$TERMERIC_DIR/bin/termeric' status 2>/dev/null || true
" 2>/dev/null) || true
if echo "$rc_test_out" | grep -q "PROMPT_STYLE.*rc: 2"; then
    pass "status: reads PROMPT_STYLE from .bashrc"
else
    fail "status: did not read PROMPT_STYLE from .bashrc"
fi
rm -rf "$rc_test_dir"

# ================================================================
header "9. Uninstall fallback: blocks without comment markers"
# ================================================================

TMPDIR2=$(mktemp -d)
trap "rm -rf '$TMPDIR2'" EXIT

mkdir -p "$TMPDIR2/.config/fish"
# Write old-style blocks WITHOUT comment markers
cat > "$TMPDIR2/.bashrc" << 'EOF'
# something else
if [ -f ~/.termeric_bash ]; then
    . ~/.termeric_bash
fi
# other stuff
EOF
cat > "$TMPDIR2/.zshrc" << 'EOF'
if [ -f ~/.termeric_zsh ]; then
    . ~/.termeric_zsh
fi
EOF
cat > "$TMPDIR2/.config/fish/config.fish" << 'EOF'
source ~/.config/fish/termeric_fish
EOF

HOME="$TMPDIR2" bash "$TERMERIC_DIR/bin/termeric" uninstall 2>/dev/null || true

for rc in ".bashrc" ".zshrc" ".config/fish/config.fish"; do
    if grep -q "termeric" "$TMPDIR2/$rc" 2>/dev/null; then
        fail "uninstall fallback: $rc still has termeric (old-style block)"
    else
        pass "uninstall fallback: $rc cleaned (old-style block)"
    fi
done

trap - EXIT
rm -rf "$TMPDIR2"

# ================================================================
header "10. Default values"
# ================================================================

# Bash and zsh use inline defaults via ${VAR:-default}; fish sets them with set -g
# Verify default patterns exist in source files
for f in "$TERMERIC_DIR/termeric_bash" "$TERMERIC_DIR/termeric_zsh"; do
    name=$(basename "$f")
    local_pass=0
    grep -q 'PROMPT_COLOR:-on' "$f"  2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_STYLE:-0' "$f"   2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_SHOW_USER:-on' "$f"   2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_SHOW_EXIT:-on' "$f"   2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_SHOW_DIR:-on' "$f"    2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_SHOW_SSH:-on' "$f"    2>/dev/null && local_pass=$((local_pass+1))
    grep -q 'PROMPT_SHOW_TIME:-off' "$f"  2>/dev/null && local_pass=$((local_pass+1))
    if [ "$local_pass" -eq 7 ]; then
        pass "$name: all 7 default values present"
    else
        fail "$name: $local_pass/7 default values found"
    fi
done

# Fish sets defaults at source time — source and check
if command -v fish &>/dev/null && [ -z "${SKIP_FISH_TESTS:-}" ]; then
    fish -c "
        source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
        [ \"\$PROMPT_COLOR\" = on ] && exit 0 || exit 1
    " 2>/dev/null && pass "fish PROMPT_COLOR default: on" || fail "fish PROMPT_COLOR default: mismatch"
    for var in PROMPT_SHOW_USER PROMPT_SHOW_EXIT PROMPT_SHOW_DIR PROMPT_SHOW_SSH; do
        fish -c "
            source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
            [ \"\$$var\" = on ] && exit 0 || exit 1
        " 2>/dev/null && pass "fish $var default: on" || fail "fish $var default: mismatch"
    done
    fish -c "
        source '$TERMERIC_DIR/termeric_fish' >/dev/null 2>&1
        [ \"\$PROMPT_SHOW_TIME\" = off ] && exit 0 || exit 1
    " 2>/dev/null && pass "fish PROMPT_SHOW_TIME default: off" || fail "fish PROMPT_SHOW_TIME default: mismatch"
else
    skip "fish defaults: not available"
fi

# ================================================================
header "11. Version consistency"
# ================================================================

version_file=$(cat "$TERMERIC_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')
version_cli=$(bash -c "source '$TERMERIC_DIR/bin/termeric' >/dev/null 2>&1; printf '%s' \"\$TERMERIC_VERSION\"" 2>/dev/null)
if [ "$version_file" = "$version_cli" ]; then
    pass "VERSION file matches bin/termeric: $version_file"
else
    fail "VERSION mismatch: file='$version_file' cli='$version_cli'"
fi

# Check install.sh version
version_inst=$(grep 'TERMERIC_VERSION=' "$TERMERIC_DIR/install.sh" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)
if [ "$version_file" = "$version_inst" ]; then
    pass "VERSION file matches install.sh: $version_file"
else
    fail "VERSION mismatch: file='$version_file' install.sh='$version_inst'"
fi

# ================================================================
header "12. Complete files — old toggle names check"
# ================================================================

# Check ALL non-shell files for remaining old toggle names
old_names="PROMPT_COLOR_MODE|PROMPT_EXIT_CODE|PROMPT_CMD_TIME|PROMPT_USER_HOST|PROMPT_SHORT"
# Allow matches in AGENTS.md roadmap (historical notes)
old_found=0
for f in "$TERMERIC_DIR/README.md" "$TERMERIC_DIR/bin/termeric" "$TERMERIC_DIR/install.sh" \
         "$TERMERIC_DIR/docs/index.html"; do
    name=$(basename "$f")
    matches=$(grep -cE "$old_names" "$f" 2>/dev/null || true)
    if [ "$matches" -gt 0 ]; then
        fail "$name: $matches old toggle name(s) found"
        old_found=$((old_found+matches))
    fi
done
# Accept AGENTS.md having some in roadmap section
agent_matches=$(grep -cE "$old_names" "$TERMERIC_DIR/AGENTS.md" 2>/dev/null || true)
if [ "$agent_matches" -gt 0 ]; then
    pass "AGENTS.md: $agent_matches old name(s) in roadmap (acceptable)"
fi

# ================================================================
# Results
# ================================================================

echo ""
echo "─────────────────────────────────────"
printf "%b%bTest Results%b\n" "${BOLD}" "${CYAN}" "${RESET}"
printf "  ${GREEN}Pass:${RESET} %d\n" "$PASS"
printf "  ${RED}Fail:${RESET} %d\n" "$FAIL"
printf "  ${YELLOW}Skip:${RESET} %d\n" "$SKIP"
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "%b%bAll tests passed!%b\n" "${GREEN}${BOLD}" "✓" "${RESET}"
else
    printf "%b%b$FAIL test(s) failed!%b\n" "${RED}${BOLD}" "✗" "${RESET}"
    exit 1
fi
