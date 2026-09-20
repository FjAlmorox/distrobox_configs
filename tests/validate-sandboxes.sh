#!/usr/bin/env bash
# tests/validate-sandboxes.sh
# Automated validation script to verify repository structural integrity,
# sandbox conformance, script permissions, and bash syntax.
#
# Usage:
#   ./tests/validate-sandboxes.sh          # Standard validation (shellcheck optional)
#   ./tests/validate-sandboxes.sh --strict # Strict mode (fails if shellcheck is missing)

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STRICT_MODE=false
if [ "$1" = "--strict" ]; then
    STRICT_MODE=true
fi

ERRORS_FOUND=0
ALL_SCRIPTS=()

error() {
    echo -e "${RED}❌ $1${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}🔍 Running Automated Sandbox & Repository Audit...${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# ---------------------------------------------------------
# 1. Unix LF Line Endings Validation
# ---------------------------------------------------------
echo -e "${BLUE}1. Checking Unix LF line endings...${NC}"
CRLF_FILES=$(grep -r -l $'\r' --exclude-dir=".git" "$ROOT_DIR" 2>/dev/null || true)
if [ -n "$CRLF_FILES" ]; then
    error "Detected CRLF line endings in the following files:"
    echo "$CRLF_FILES" | head -n 5
else
    success "All tracked repository files use Unix LF line endings."
fi

# ---------------------------------------------------------
# 2. Host Orchestration & Git Hooks Scripts Validation
# ---------------------------------------------------------
echo -e "\n${BLUE}2. Validating host orchestration scripts and hooks...${NC}"
HOST_SCRIPTS=(
    "$ROOT_DIR/create.sh"
    "$ROOT_DIR/enter.sh"
    "$ROOT_DIR/.githooks/pre-commit"
    "$ROOT_DIR/.githooks/pre-push"
    "$ROOT_DIR/tests/validate-sandboxes.sh"
)

for script in "${HOST_SCRIPTS[@]}"; do
    rel_path="${script#"$ROOT_DIR/"}"
    if [ ! -f "$script" ]; then
        error "Missing required script: $rel_path"
        continue
    fi

    if [ ! -x "$script" ]; then
        error "Script is not executable (chmod +x required): $rel_path"
    fi

    if ! bash -n "$script" 2>/dev/null; then
        error "Syntax error (bash -n failed) in: $rel_path"
    else
        ALL_SCRIPTS+=("$script")
    fi
done

if [ $ERRORS_FOUND -eq 0 ]; then
    success "Host orchestration scripts and Git hooks are executable and syntax-clean."
fi

# ---------------------------------------------------------
# 3. Discover and Validate All Sandboxes (*-dev/)
# ---------------------------------------------------------
echo -e "\n${BLUE}3. Validating development sandboxes (*-dev/)...${NC}"
SANDBOX_DIRS=()
while IFS= read -r -d '' d; do
    SANDBOX_DIRS+=("$d")
done < <(find "$ROOT_DIR" -maxdepth 1 -type d -name "*-dev" -print0 | sort -z)

if [ ${#SANDBOX_DIRS[@]} -eq 0 ]; then
    error "No sandbox directories (*-dev) found in repository root!"
fi

DISTROBOX_INI="$ROOT_DIR/distrobox.ini"
README_FILE="$ROOT_DIR/README.md"

if [ ! -f "$DISTROBOX_INI" ]; then
    error "Missing single source of truth: distrobox.ini"
fi

if [ ! -f "$README_FILE" ]; then
    error "Missing root catalog: README.md"
fi

for sandbox_dir in "${SANDBOX_DIRS[@]}"; do
    sandbox_name="$(basename "$sandbox_dir")"
    echo -e "   Checking sandbox: ${BLUE}$sandbox_name${NC}..."

    # a. Check declaration in distrobox.ini
    if ! grep -q "^\[$sandbox_name\]" "$DISTROBOX_INI" 2>/dev/null; then
        error "Sandbox '$sandbox_name' is missing section [$sandbox_name] in distrobox.ini"
    fi

    # b. Check required setup.sh
    setup_script="$sandbox_dir/setup.sh"
    if [ ! -f "$setup_script" ]; then
        error "Sandbox '$sandbox_name' is missing setup.sh"
    else
        if [ ! -x "$setup_script" ]; then
            error "$sandbox_name/setup.sh is not executable (chmod +x required)"
        fi
        if ! bash -n "$setup_script" 2>/dev/null; then
            error "Syntax error (bash -n failed) in: $sandbox_name/setup.sh"
        fi
        ALL_SCRIPTS+=("$setup_script")
    fi

    # c. Check required README.md
    sandbox_readme="$sandbox_dir/README.md"
    if [ ! -f "$sandbox_readme" ] || [ ! -s "$sandbox_readme" ]; then
        error "Sandbox '$sandbox_name' is missing or has empty README.md"
    fi

    # d. Check anti-duplication boundary (forbidden create.sh / enter.sh)
    if [ -f "$sandbox_dir/create.sh" ] || [ -f "$sandbox_dir/enter.sh" ]; then
        error "Architectural Invariant Violation: Found duplicate create.sh or enter.sh inside $sandbox_name/"
    fi

    # e. Check bin/ directory commands if present
    bin_dir="$sandbox_dir/bin"
    if [ -d "$bin_dir" ]; then
        while IFS= read -r -d '' cmd_file; do
            cmd_name="$(basename "$cmd_file")"
            # Forbidden: .sh extension inside bin/
            if [[ "$cmd_name" == *.sh ]]; then
                error "CLI command '$cmd_name' in $sandbox_name/bin/ MUST NOT have .sh extension"
            fi
            if [ ! -x "$cmd_file" ]; then
                error "CLI command '$sandbox_name/bin/$cmd_name' is not executable (chmod +x required)"
            fi
            # Validate syntax if it's a bash script
            if head -n 1 "$cmd_file" 2>/dev/null | grep -q "bash"; then
                if ! bash -n "$cmd_file" 2>/dev/null; then
                    error "Syntax error (bash -n failed) in: $sandbox_name/bin/$cmd_name"
                fi
                ALL_SCRIPTS+=("$cmd_file")
            fi
        done < <(find "$bin_dir" -maxdepth 1 -type f -print0)
    fi

    # f. Check registration in root README.md
    if ! grep -q "$sandbox_name" "$README_FILE" 2>/dev/null; then
        warn "Sandbox '$sandbox_name' is not explicitly referenced in root README.md"
    fi
done

# ---------------------------------------------------------
# 4. Check for Orphaned Sections in distrobox.ini
# ---------------------------------------------------------
echo -e "\n${BLUE}4. Checking for orphaned sections in distrobox.ini...${NC}"
INI_SECTIONS=$(grep -E "^\[.*-dev\]" "$DISTROBOX_INI" | tr -d '[]' || true)
for section in $INI_SECTIONS; do
    if [ ! -d "$ROOT_DIR/$section" ]; then
        error "Section [$section] exists in distrobox.ini but directory $section/ does not exist!"
    fi
done
if [ $ERRORS_FOUND -eq 0 ]; then
    success "All sections in distrobox.ini match existing sandbox directories."
fi

# ---------------------------------------------------------
# 5. Static Linting with ShellCheck
# ---------------------------------------------------------
echo -e "\n${BLUE}5. Static script analysis (ShellCheck)...${NC}"
if command -v shellcheck &>/dev/null; then
    info "Found ShellCheck. Running static analysis on ${#ALL_SCRIPTS[@]} scripts..."
    for script in "${ALL_SCRIPTS[@]}"; do
        rel_path="${script#"$ROOT_DIR/"}"
        if ! shellcheck "$script"; then
            error "ShellCheck found issues in: $rel_path"
        fi
    done
    if [ $ERRORS_FOUND -eq 0 ]; then
        success "All scripts passed ShellCheck validation with zero warnings."
    fi
else
    if [ "$STRICT_MODE" = true ]; then
        error "ShellCheck is required in strict mode, but was not found in PATH."
    else
        info "ShellCheck not installed locally; skipping static linting (enforced in CI)."
    fi
fi

# ---------------------------------------------------------
# 6. Final Summary & Exit
# ---------------------------------------------------------
echo -e "\n${BLUE}======================================================${NC}"
if [ $ERRORS_FOUND -ne 0 ]; then
    echo -e "${RED}🚫 Structural validation failed with $ERRORS_FOUND error(s).${NC}"
    echo -e "${YELLOW}Please fix the architectural violations reported above.${NC}"
    echo -e "${BLUE}======================================================${NC}\n"
    exit 1
else
    echo -e "${GREEN}✨ Structural validation PASSED! All sandboxes adhere to repository standards.${NC}"
    echo -e "${BLUE}======================================================${NC}\n"
    exit 0
fi
