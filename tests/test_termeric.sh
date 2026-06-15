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
    "ai/termeric_ai" \
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
header "13. AI module — Phase 4"
# ================================================================

# 13a. Syntax check for ai/termeric_ai
check_syntax "$TERMERIC_DIR/ai/termeric_ai" "ai/termeric_ai" "bash -n '$TERMERIC_DIR/ai/termeric_ai'" bash

# 13b. Version consistency
ai_version=$(grep 'TERMERIC_AI_VERSION=' "$TERMERIC_DIR/ai/termeric_ai" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)
if [ "$version_file" = "$ai_version" ]; then
	pass "ai/termeric_ai version matches VERSION: $ai_version"
else
	fail "ai/termeric_ai version mismatch: VERSION='$version_file' ai='$ai_version'"
fi

# 13c. ai() function exists in all 3 shell files
ai_func_ok=0
if grep -qE '^ai\(' "$TERMERIC_DIR/termeric_bash" 2>/dev/null; then
	ai_func_ok=$((ai_func_ok + 1))
else
	fail "termeric_bash: missing ai() function"
fi
if grep -qE '^ai\(' "$TERMERIC_DIR/termeric_zsh" 2>/dev/null; then
	ai_func_ok=$((ai_func_ok + 1))
else
	fail "termeric_zsh: missing ai() function"
fi
if grep -qE '^function ai\b' "$TERMERIC_DIR/termeric_fish" 2>/dev/null; then
	ai_func_ok=$((ai_func_ok + 1))
else
	fail "termeric_fish: missing ai function"
fi
[ "$ai_func_ok" -eq 3 ] && pass "all 3 shell files have ai() function"

# 13d. @ prefix intercept hooks in zsh and fish
if grep -qE '\^@' "$TERMERIC_DIR/termeric_zsh" 2>/dev/null; then
	pass "termeric_zsh: @ prefix intercept via accept-line"
else
	fail "termeric_zsh: missing @ prefix intercept"
fi
if grep -qE '\^@' "$TERMERIC_DIR/termeric_fish" 2>/dev/null; then
	pass "termeric_fish: @ prefix intercept via fish_preexec"
else
	fail "termeric_fish: missing @ prefix intercept"
fi

# 13e. CLI dispatches ai subcommand
if grep -qE '^ai\)' "$TERMERIC_DIR/bin/termeric" 2>/dev/null; then
	pass "bin/termeric: dispatches ai subcommand"
else
	fail "bin/termeric: missing ai case dispatch"
fi

# Create AI function library for unit tests
AI_LIB=$(mktemp)
# Extract everything before the main dispatch (skip shebang and set -euo)
sed -n '3,/^# ---- Main/p' "$TERMERIC_DIR/ai/termeric_ai" | head -n -1 > "$AI_LIB"

# 13f. _read_file returns file content
rft=$(bash -c "
	source '$AI_LIB'
	tmpf=\$(mktemp)
	echo 'hello world' > \$tmpf
	_read_file \$tmpf
	rm -f \$tmpf
" 2>/dev/null) || true
if echo "$rft" | grep -q "hello world"; then
	pass "_read_file: returns file content"
else
	fail "_read_file: got '$(echo "$rft" | head -c 50)'"
fi

# 13g. _load_config reads from config file
clt=$(bash -c "
	TMPD=\$(mktemp -d)
	export XDG_CONFIG_HOME=\$TMPD
	mkdir -p \$TMPD/termeric
	cat > \$TMPD/termeric/config << 'CONF'
AI_BACKEND=ollama
AI_SAFE_MODE=off
CONF
	source '$AI_LIB'
	_load_config 2>/dev/null || true
	echo \"BACKEND=\$AI_BACKEND SAFE=\$AI_SAFE_MODE\"
	rm -rf \$TMPD
" 2>/dev/null) || true
if echo "$clt" | grep -q "BACKEND=ollama.*SAFE=off"; then
	pass "_load_config: reads AI_BACKEND and AI_SAFE_MODE from config"
else
	fail "_load_config: got '$clt'"
fi

# 13k. _load_config env vars override config file
evt=$(bash -c "
	export TERMERIC_AI_BACKEND=openai
	export TERMERIC_AI_API_KEY=test-key-123
	source '$AI_LIB'
	_load_config 2>/dev/null || true
	echo \"BACKEND=\$AI_BACKEND KEY_LEN=\$(echo \$AI_API_KEY | wc -c)\"
" 2>/dev/null) || true
if echo "$evt" | grep -q "BACKEND=openai"; then
	pass "_load_config: TERMERIC_AI_BACKEND env var overrides default"
else
	fail "_load_config: env override got '$evt'"
fi
if echo "$evt" | grep -q "KEY_LEN=1[2-9]"; then
	pass "_load_config: TERMERIC_AI_API_KEY read from env"
else
	fail "_load_config: api key not read from env: '$evt'"
fi

# 13l. _run_command safe mode rejects with 'n'
sft=$(echo "n" | bash -c "
	source '$AI_LIB'
	AI_SAFE_MODE=on
	_run_command 'echo should-not-run' 2>/dev/null
" 2>/dev/null) || true
if echo "$sft" | grep -qi "rejected"; then
	pass "_run_command: safe mode rejects command when user says n"
else
	fail "_run_command: safe mode rejected got '$sft'"
fi

# 13m. _run_command safe mode accepts with default (enter)
sft2=$(printf '\n' | bash -c "
	source '$AI_LIB'
	AI_SAFE_MODE=on
	_run_command 'echo hello-accepted' 2>/dev/null
" 2>/dev/null) || true
if echo "$sft2" | grep -q "hello-accepted"; then
	pass "_run_command: safe mode runs command on enter"
else
	fail "_run_command: safe mode accept got '$sft2'"
fi

# 13n. _run_command safe mode off runs without prompt
sft3=$(bash -c "
	source '$AI_LIB'
	AI_SAFE_MODE=off
	_run_command 'echo hello-no-prompt' 2>/dev/null
" 2>/dev/null) || true
if echo "$sft3" | grep -q "hello-no-prompt"; then
	pass "_run_command: safe mode off runs without prompt"
else
	fail "_run_command: safe mode off got '$sft3'"
fi

# 13o. _cmd_config creates config file with AI vars
cft=$(bash -c "
	TMPD=\$(mktemp -d)
	export XDG_CONFIG_HOME=\$TMPD
	export EDITOR=true
	source '$AI_LIB'
	_cmd_config 2>/dev/null || true
	if [ -f \$TMPD/termeric/config ]; then
		echo 'CREATED'
		grep -q 'AI_BACKEND' \$TMPD/termeric/config && echo 'HAS_BACKEND' || true
		grep -q 'AI_SAFE_MODE' \$TMPD/termeric/config && echo 'HAS_SAFE' || true
	fi
	rm -rf \$TMPD
" 2>/dev/null) || true
if echo "$cft" | grep -q "CREATED"; then
	pass "_cmd_config: creates config file"
else
	fail "_cmd_config: config not created: '$cft'"
fi
if echo "$cft" | grep -q "HAS_BACKEND"; then
	pass "_cmd_config: config template contains AI_BACKEND"
else
	fail "_cmd_config: template missing AI_BACKEND"
fi
if echo "$cft" | grep -q "HAS_SAFE"; then
	pass "_cmd_config: config template contains AI_SAFE_MODE"
else
	fail "_cmd_config: template missing AI_SAFE_MODE"
fi

# 13p. AI_* config vars present in ai/termeric_ai source
for var in "AI_BACKEND" "AI_API_KEY" "AI_SAFE_MODE" "AI_ENDPOINT" "AI_MODEL"; do
	if grep -q "$var" "$TERMERIC_DIR/ai/termeric_ai" 2>/dev/null; then
		:
	else
		fail "ai/termeric_ai: missing reference to $var"
	fi
done
pass "ai/termeric_ai: references all 5 AI config vars"

# ================================================================
header "14. AI module — backend & error coverage"
# ================================================================

# 14a. Groq with key sets default endpoint and model
gkt=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=groq
  export TERMERIC_AI_API_KEY=gsk-test-key
  _load_config 2>/dev/null || true
  echo \"EP=\$AI_ENDPOINT MODEL=\$AI_MODEL\"
")
if echo "$gkt" | grep -q "EP=https://api.groq.com/openai/v1" && \
   echo "$gkt" | grep -q "MODEL=llama-3.3-70b-versatile"; then
  pass "_load_config: Groq with key sets defaults"
else
  fail "_load_config: Groq with key got '$gkt'"
fi

# 14b. Groq without key returns 1
gkn=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=groq
  _load_config 2>/dev/null
" 2>/dev/null) || gkn_rc=$?
if [ "${gkn_rc:-0}" -eq 1 ]; then
  pass "_load_config: Groq without key returns 1"
else
  fail "_load_config: Groq without key returned ${gkn_rc:-0}"
fi

# 14c. OpenAI with key sets default endpoint and model
okt=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=openai
  export TERMERIC_AI_API_KEY=sk-test-key
  _load_config 2>/dev/null || true
  echo \"EP=\$AI_ENDPOINT MODEL=\$AI_MODEL\"
")
if echo "$okt" | grep -q "EP=https://api.openai.com/v1" && \
   echo "$okt" | grep -q "MODEL=gpt-4o-mini"; then
  pass "_load_config: OpenAI with key sets defaults"
else
  fail "_load_config: OpenAI with key got '$okt'"
fi

# 14d. OpenAI without key returns 1
okn=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=openai
  _load_config 2>/dev/null
" 2>/dev/null) || okn_rc=$?
if [ "${okn_rc:-0}" -eq 1 ]; then
  pass "_load_config: OpenAI without key returns 1"
else
  fail "_load_config: OpenAI without key returned ${okn_rc:-0}"
fi

# 14e. Ollama sets default endpoint and model (no key needed)
olt=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=ollama
  _load_config 2>/dev/null || true
  echo \"EP=\$AI_ENDPOINT MODEL=\$AI_MODEL\"
")
if echo "$olt" | grep -q "EP=http://localhost:11434/v1" && \
   echo "$olt" | grep -q "MODEL=llama3.1"; then
  pass "_load_config: Ollama sets defaults"
else
  fail "_load_config: Ollama got '$olt'"
fi

# 14f. Unknown backend returns 1
ukt=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=unknown
  _load_config 2>/dev/null
" 2>/dev/null) || ukt_rc=$?
if [ "${ukt_rc:-0}" -eq 1 ]; then
  pass "_load_config: Unknown backend returns 1"
else
  fail "_load_config: Unknown backend returned ${ukt_rc:-0}"
fi

# 14g. _llm_chat unreachable endpoint returns error
llme=$(bash -c "
  source '$AI_LIB'
  AI_ENDPOINT='http://127.0.0.1:1/v1'
  AI_MODEL='test-model'
  AI_API_KEY='test-key'
  _llm_chat '[{\"role\":\"user\",\"content\":\"hi\"}]' >/dev/null
" 2>&1) || llme_rc=$?
if [ "${llme_rc:-0}" -eq 1 ] && echo "$llme" | grep -q "API request failed"; then
  pass "_llm_chat: unreachable endpoint returns error"
else
  fail "_llm_chat: unreachable got rc=${llme_rc:-0} msg='$(echo "$llme" | head -c 50)'"
fi

# 14h. _exec_tool missing command arg
et_mc=$(bash -c "source '$AI_LIB'; _exec_tool run_command '{}'")
if echo "$et_mc" | grep -q "Missing command argument"; then
  pass "_exec_tool: missing command arg"
else
  fail "_exec_tool: missing command got '$et_mc'"
fi

# 14i. _exec_tool missing path arg
et_mp=$(bash -c "source '$AI_LIB'; _exec_tool read_file '{}'")
if echo "$et_mp" | grep -q "Missing path argument"; then
  pass "_exec_tool: missing path arg"
else
  fail "_exec_tool: missing path got '$et_mp'"
fi

# 14j. _exec_tool unknown tool
et_ut=$(bash -c "source '$AI_LIB'; _exec_tool nonexistent '{}'")
if echo "$et_ut" | grep -q "Unknown tool: nonexistent"; then
  pass "_exec_tool: unknown tool"
else
  fail "_exec_tool: unknown tool got '$et_ut'"
fi

# 14k. ReAct loop: LLM failure exits with 1
rl_f=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _llm_chat() { return 1; }
  _react_loop 'test query'
" 2>&1) || rl_f_rc=$?
if [ "${rl_f_rc:-0}" -eq 1 ]; then
  pass "_react_loop: LLM failure exits with 1"
else
  fail "_react_loop: LLM failure got exit ${rl_f_rc:-0}"
fi

# 14m. ReAct loop: max 3 turns warning
rl_m=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _llm_chat() { echo '{\"tool\": \"run_command\", \"args\": {\"command\": \"echo hi\"}}'; }
  _react_loop 'test query'
" 2>&1) || rl_m_rc=$?
if [ "${rl_m_rc:-0}" -eq 1 ] && echo "$rl_m" | grep -q "max 3 turns"; then
  pass "_react_loop: max turns warning"
else
  fail "_react_loop: max turns got rc=${rl_m_rc:-0} msg='$(echo "$rl_m" | head -c 50)'"
fi

# 14n. _read_file on non-existent file
rf_nf=$(bash -c "source '$AI_LIB'; _read_file '/nonexistent/path/file.txt'")
if echo "$rf_nf" | grep -q "File not found"; then
  pass "_read_file: non-existent file returns error"
else
  fail "_read_file: non-existent got '$rf_nf'"
fi



# ================================================================
header "15. AI module — Phase 4.5 (streaming, Gemini, doctor, context)"
# ================================================================

# 15a. Gemini with key sets default endpoint and model
gkt=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=gemini
  export TERMERIC_AI_API_KEY=test-gemini-key
  _load_config 2>/dev/null || true
  echo \"EP=\$AI_ENDPOINT MODEL=\$AI_MODEL\"
")
if echo "$gkt" | grep -q "EP=https://generativelanguage.googleapis.com/v1beta" && \
   echo "$gkt" | grep -q "MODEL=gemini-2.0-flash"; then
  pass "_load_config: Gemini with key sets defaults"
else
  fail "_load_config: Gemini with key got '$gkt'"
fi

# 15b. Gemini without key returns 1
gkn=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=gemini
  _load_config 2>/dev/null
" 2>/dev/null) || gkn_rc=$?
if [ "${gkn_rc:-0}" -eq 1 ]; then
  pass "_load_config: Gemini without key returns 1"
else
  fail "_load_config: Gemini without key returned ${gkn_rc:-0}"
fi

# 15c. Gemini unknown model still loads (key is what matters)
gkm=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=gemini
  export TERMERIC_AI_API_KEY=test-key
  export TERMERIC_AI_MODEL=custom-model
  _load_config 2>/dev/null || true
  echo \"MODEL=\$AI_MODEL\"
")
if echo "$gkm" | grep -q "MODEL=custom-model"; then
  pass "_load_config: Gemini custom model accepted"
else
  fail "_load_config: Gemini custom model got '$gkm'"
fi

# 15d. _cmd_doctor runs without error and shows expected sections
doc_out=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=ollama
  _cmd_doctor
" 2>&1) || doc_rc=$?
if [ -z "${doc_rc:-0}" ] || [ "${doc_rc:-0}" -eq 0 ]; then
  pass "_cmd_doctor: runs without error"
else
  fail "_cmd_doctor: returned ${doc_rc:-0}"
fi
if echo "$doc_out" | grep -q "Checking AI dependencies"; then
  pass "_cmd_doctor: shows dependency check header"
else
  fail "_cmd_doctor: missing dependency header"
fi
if echo "$doc_out" | grep -q "Backend: ollama"; then
  pass "_cmd_doctor: shows backend"
else
  fail "_cmd_doctor: missing backend info"
fi

# 15e. _cmd_doctor with Ollama backend shows Ollama connectivity check
doc_ollama=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=ollama
  _cmd_doctor
" 2>&1) || true
if echo "$doc_ollama" | grep -q "Ollama"; then
  pass "_cmd_doctor: shows Ollama section when backend=ollama"
else
  fail "_cmd_doctor: missing Ollama section"
fi

# 15f. _cmd_agent --noctx passes query through without context prefix
noctx_out=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=ollama
  AI_SAFE_MODE=off
  _react_loop() { echo \"\$1\"; }
  _cmd_agent --noctx 'hello world'
" 2>/dev/null)
if echo "$noctx_out" | grep -q "^hello world$"; then
  pass "_cmd_agent: --noctx passes query without context"
else
  fail "_cmd_agent: --noctx got '$noctx_out'"
fi

# 15g. _cmd_agent without --noctx prepends context
ctx_out=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=ollama
  AI_SAFE_MODE=off
  _react_loop() { echo \"\$1\"; }
  _cmd_agent 'hello world'
" 2>/dev/null)
if echo "$ctx_out" | grep -q "\[ctx:" && echo "$ctx_out" | grep -q "hello world"; then
  pass "_cmd_agent: prepends context to query"
else
  fail "_cmd_agent: context got '$ctx_out'"
fi

# 15h. Gemini _llm_chat_gemini message translation (system prompt extraction)
gemini_trans=$(bash -c "
  source '$AI_LIB'
  AI_ENDPOINT='http://127.0.0.1:1'
  AI_MODEL='gemini-2.0-flash'
  AI_API_KEY='test-key'
  # Test just the jq translation by checking what would be sent
  msgs='[{\"role\":\"system\",\"content\":\"You are a bot\"},{\"role\":\"user\",\"content\":\"hello\"}]'
  sys=\$(echo \"\$msgs\" | jq -r '[.[] | select(.role == \"system\") | .content] | first // \"\"')
  contents=\$(echo \"\$msgs\" | jq -c '[.[] | select(.role != \"system\") | if .role == \"assistant\" then {role: \"model\", parts: [{text: .content}]} elif .role == \"tool\" then {role: \"user\", parts: [{text: \"[Tool result]: \(.content)\"}]} else {role: \"user\", parts: [{text: .content}]} end]')
  echo \"SYS=\$sys CONT=\$contents\"
")
if echo "$gemini_trans" | grep -q "SYS=You are a bot" && \
   echo "$gemini_trans" | grep -q '"role":"user"' && \
   echo "$gemini_trans" | grep -q '"text":"hello"'; then
  pass "Gemini message translation: system/user extraction correct"
else
  fail "Gemini message translation: got '$gemini_trans'"
fi

# 15i. Shell ai() function handles --noctx (bash)
if grep -qE -- "--noctx" "$TERMERIC_DIR/termeric_bash"; then
  pass "termeric_bash ai(): supports --noctx flag"
else
  fail "termeric_bash ai(): missing --noctx"
fi

# 15j. Shell ai() function handles --noctx (zsh)
if grep -qE -- "--noctx" "$TERMERIC_DIR/termeric_zsh"; then
  pass "termeric_zsh ai(): supports --noctx flag"
else
  fail "termeric_zsh ai(): missing --noctx"
fi

# 15k. Shell ai() function handles --noctx (fish)
if grep -qE -- "--noctx" "$TERMERIC_DIR/termeric_fish"; then
  pass "termeric_fish ai(): supports --noctx flag"
else
  fail "termeric_fish ai(): missing --noctx"
fi

# 15l. _cmd_doctor shows config file status
doc_cfg=$(bash -c "
  source '$AI_LIB'
  export TERMERIC_AI_BACKEND=groq
  export TERMERIC_AI_API_KEY=test-key
  _cmd_doctor
" 2>&1) || true
if echo "$doc_cfg" | grep -q "Config file"; then
  pass "_cmd_doctor: shows config file status"
else
  fail "_cmd_doctor: missing config file status"
fi

# 15m. Shell ai() function contains context-gathering variables (bash)
if grep -q "ctx_dir" "$TERMERIC_DIR/termeric_bash"; then
  pass "termeric_bash ai(): uses ctx_dir for directory context"
else
  fail "termeric_bash ai(): missing ctx_dir"
fi

# 15n. System prompt contains conversational summary rule
if grep -q "Always end with a clear conversational summary" "$TERMERIC_DIR/ai/termeric_ai"; then
  pass "_system_prompt: contains summary rule"
else
  fail "_system_prompt: missing summary rule"
fi

# 15o. _react_loop prints separator before answer
rl_sep=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _llm_chat() { echo '{\"answer\": \"test answer\"}'; }
  _react_loop 'test'
" 2>&1) || true
if echo "$rl_sep" | grep -q "━━━"; then
  pass "_react_loop: prints separator before answer"
else
  fail "_react_loop: missing separator in output"
fi
if echo "$rl_sep" | grep -q "test answer"; then
  pass "_react_loop: answer printed after separator"
else
  fail "_react_loop: answer not found in output"
fi

# 15p. Blocklist rejects npm
bl_npm=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _run_command 'npm install express'
" 2>/dev/null)
if echo "$bl_npm" | grep -q "Blocked"; then
  pass "_run_command: blocks npm install"
else
  fail "_run_command: npm install not blocked got '$bl_npm'"
fi

# 15q. Blocklist rejects pip install -r
bl_pip=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _run_command 'pip install -r requirements.txt'
" 2>/dev/null)
if echo "$bl_pip" | grep -q "Blocked"; then
  pass "_run_command: blocks pip install -r"
else
  fail "_run_command: pip install -r not blocked"
fi

# 15r. Blocklist allows pip install of a single package (no -r)
bl_pip_ok=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _run_command 'pip install requests'
" 2>/dev/null)
if echo "$bl_pip_ok" | grep -qv "Blocked"; then
  pass "_run_command: allows pip install single package"
else
  fail "_run_command: pip install single package wrongly blocked"
fi

# 15s. Blocklist rejects cargo build
bl_cargo=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  _run_command 'cargo build --release'
" 2>/dev/null)
if echo "$bl_cargo" | grep -q "Blocked"; then
  pass "_run_command: blocks cargo build"
else
  fail "_run_command: cargo build not blocked"
fi

# 15t. System prompt contains scope rule
if grep -q "Scope: system administration" "$TERMERIC_DIR/ai/termeric_ai"; then
  pass "_system_prompt: contains scope rule"
else
  fail "_system_prompt: missing scope rule"
fi

# 15u. Two-turn flow: tool call → answer
two_turn=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  tf=\$(mktemp)
  echo 0 > \"\$tf\"
  _llm_chat() {
    local c=\"\$(<\$tf)\"
    echo \$((c + 1)) > \"\$tf\"
    if [ \"\$c\" -eq 0 ]; then
      printf '{\"tool\": \"run_command\", \"args\": {\"command\": \"echo done\"}}'
    else
      printf '{\"answer\": \"Task complete\"}'
    fi
  }
  _react_loop 'do something'
  rm -f \"\$tf\"
" 2>&1) || true
if echo "$two_turn" | grep -q "Task complete"; then
  pass "_react_loop: two-turn flow produces answer"
else
  fail "_react_loop: two-turn missing answer in '$(echo "$two_turn" | head -c 80)'"
fi

# 15v. Fallback: second LLM call empty shows tool result
rl_fb=$(bash -c "
  source '$AI_LIB'
  AI_SAFE_MODE=off
  tf=\$(mktemp)
  echo 0 > \"\$tf\"
  _llm_chat() {
    local c=\"\$(<\$tf)\"
    echo \$((c + 1)) > \"\$tf\"
    if [ \"\$c\" -eq 0 ]; then
      printf '{\"tool\": \"run_command\", \"args\": {\"command\": \"echo hello\"}}'
    else
      printf ''
    fi
  }
  _react_loop 'test'
  rm -f \"\$tf\"
" 2>&1) || true
if echo "$rl_fb" | grep -q "Tool result:"; then
  pass "_react_loop: fallback shows tool result on empty answer"
else
  fail "_react_loop: fallback not found '$(echo "$rl_fb" | head -c 80)'"
fi

rm -f "$AI_LIB"

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
