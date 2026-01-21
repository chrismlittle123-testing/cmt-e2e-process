#!/bin/bash

# E2E Test Suite for check-my-toolkit v1.5.0 - v1.6.0 features
# Tests new features introduced since v1.4.0

BASE_DIR="/Users/christopherlittle/Documents/GitHub/personal/cmt-e2e-process/e2e-tests"
SCENARIOS_DIR="$BASE_DIR/scenarios-v1.5-v1.6"
RESULTS_FILE="$BASE_DIR/test-results-v1.5-v1.6.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
BUGS_FOUND=()

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_dir="$2"
    local expected_exit="$3"
    local command="$4"
    local expected_output="$5"
    local not_expected_output="$6"

    echo -n "Testing: $test_name... "

    cd "$test_dir"
    output=$(eval "$command" 2>&1)
    actual_exit=$?

    local passed=true
    local failure_reason=""

    # Check exit code
    if [ "$actual_exit" -ne "$expected_exit" ]; then
        passed=false
        failure_reason="exit code $actual_exit, expected $expected_exit"
    fi

    # Check expected output if provided
    if [ -n "$expected_output" ] && [ "$passed" = true ]; then
        if ! echo "$output" | grep -q "$expected_output"; then
            passed=false
            failure_reason="expected output '$expected_output' not found"
        fi
    fi

    # Check NOT expected output if provided
    if [ -n "$not_expected_output" ] && [ "$passed" = true ]; then
        if echo "$output" | grep -q "$not_expected_output"; then
            passed=false
            failure_reason="unexpected output '$not_expected_output' found"
        fi
    fi

    if [ "$passed" = true ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} ($failure_reason)"
        echo "  Output: $output"
        ((FAILED++))
        BUGS_FOUND+=("$test_name: $failure_reason")
    fi
}

# Cleanup and create test directories
cleanup() {
    rm -rf "$SCENARIOS_DIR"
    mkdir -p "$SCENARIOS_DIR"
}

# ============================================================================
# v1.6.0 TESTS: CI COMMANDS ENFORCEMENT
# ============================================================================

setup_ci_commands_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}CI COMMANDS TESTS (v1.6.0)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Basic CI command requirement - command present
    local test_dir="$SCENARIOS_DIR/ci-cmd-1-present"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install
      - run: npm test
EOF

    # Test 2: CI command requirement - command missing
    local test_dir="$SCENARIOS_DIR/ci-cmd-2-missing"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test", "npm run lint"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install
      - run: npm test
EOF

    # Test 3: CI command with conditional (if:) - should detect
    local test_dir="$SCENARIOS_DIR/ci-cmd-3-conditional"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - run: npm test
EOF

    # Test 4: CI command commented out - should detect
    local test_dir="$SCENARIOS_DIR/ci-cmd-4-commented"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # - run: npm test
      - run: echo "skipped"
EOF

    # Test 5: CI command with substring match
    local test_dir="$SCENARIOS_DIR/ci-cmd-5-substring"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test -- --coverage
EOF

    # Test 6: Multiple workflows with different commands
    local test_dir="$SCENARIOS_DIR/ci-cmd-6-multi-workflow"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml", "deploy.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
"deploy.yml" = ["npm run build"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
EOF
    cat > "$test_dir/.github/workflows/deploy.yml" << 'EOF'
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
EOF

    # Test 7: Job-level commands requirement
    local test_dir="$SCENARIOS_DIR/ci-cmd-7-job-level"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.jobs]
"ci.yml" = ["test", "lint"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint
EOF

    # Test 8: PR trigger validation
    local test_dir="$SCENARIOS_DIR/ci-cmd-8-pr-trigger"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = ["npm test"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on:
  pull_request:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
EOF

    # Test 9: Empty commands array - should pass
    local test_dir="$SCENARIOS_DIR/ci-cmd-9-empty"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]

[process.ci.commands]
"ci.yml" = []
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "hello"
EOF

    # Test 10: No commands config - should pass workflow check only
    local test_dir="$SCENARIOS_DIR/ci-cmd-10-no-commands"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.ci]
enabled = true
require_workflows = ["ci.yml"]
EOF
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "hello"
EOF
}

run_ci_commands_tests() {
    # Test 1: Command present - should pass
    run_test "ci-cmd-1: command present" \
        "$SCENARIOS_DIR/ci-cmd-1-present" \
        0 \
        "cm process check" \
        ""

    # Test 2: Command missing - should fail
    run_test "ci-cmd-2: command missing" \
        "$SCENARIOS_DIR/ci-cmd-2-missing" \
        1 \
        "cm process check" \
        "lint"

    # Test 3: Conditional command - should warn/detect
    run_test "ci-cmd-3: conditional execution" \
        "$SCENARIOS_DIR/ci-cmd-3-conditional" \
        1 \
        "cm process check" \
        "conditional"

    # Test 4: Commented command - should detect
    run_test "ci-cmd-4: commented command" \
        "$SCENARIOS_DIR/ci-cmd-4-commented" \
        1 \
        "cm process check" \
        ""

    # Test 5: Substring match - should pass
    run_test "ci-cmd-5: substring match" \
        "$SCENARIOS_DIR/ci-cmd-5-substring" \
        0 \
        "cm process check" \
        ""

    # Test 6: Multiple workflows - should pass
    run_test "ci-cmd-6: multiple workflows" \
        "$SCENARIOS_DIR/ci-cmd-6-multi-workflow" \
        0 \
        "cm process check" \
        ""

    # Test 7: Job level + commands - should pass
    run_test "ci-cmd-7: job level commands" \
        "$SCENARIOS_DIR/ci-cmd-7-job-level" \
        0 \
        "cm process check" \
        ""

    # Test 8: PR trigger - should pass
    run_test "ci-cmd-8: PR trigger" \
        "$SCENARIOS_DIR/ci-cmd-8-pr-trigger" \
        0 \
        "cm process check" \
        ""

    # Test 9: Empty commands - should pass
    run_test "ci-cmd-9: empty commands" \
        "$SCENARIOS_DIR/ci-cmd-9-empty" \
        0 \
        "cm process check" \
        ""

    # Test 10: No commands config - should pass
    run_test "ci-cmd-10: no commands config" \
        "$SCENARIOS_DIR/ci-cmd-10-no-commands" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# v1.5.7 TESTS: FORBIDDEN FILES IGNORE OPTION + EXIT CODES
# ============================================================================

setup_v157_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}FORBIDDEN FILES IGNORE + EXIT CODES (v1.5.7)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Custom ignore directories
    local test_dir="$SCENARIOS_DIR/ff-ignore-1-custom"
    mkdir -p "$test_dir/vendor"
    mkdir -p "$test_dir/build"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
ignore = ["vendor/", "build/"]
EOF
    echo "SECRET=value" > "$test_dir/vendor/.env"
    echo "SECRET=value" > "$test_dir/build/.env"

    # Test 2: Default ignore (node_modules, .git) still works
    local test_dir="$SCENARIOS_DIR/ff-ignore-2-defaults"
    mkdir -p "$test_dir/node_modules/pkg"
    mkdir -p "$test_dir/.git/hooks"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/node_modules/pkg/.env"
    echo "SECRET=value" > "$test_dir/.git/hooks/.env"

    # Test 3: Ignore with glob pattern
    local test_dir="$SCENARIOS_DIR/ff-ignore-3-glob"
    mkdir -p "$test_dir/dist-v1"
    mkdir -p "$test_dir/dist-v2"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
ignore = ["dist-*/"]
EOF
    echo "SECRET=value" > "$test_dir/dist-v1/.env"
    echo "SECRET=value" > "$test_dir/dist-v2/.env"
    echo "SECRET=value" > "$test_dir/src/.env"

    # Test 4: Empty ignore array
    local test_dir="$SCENARIOS_DIR/ff-ignore-4-empty"
    mkdir -p "$test_dir/node_modules"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
ignore = []
EOF
    echo "SECRET=value" > "$test_dir/node_modules/.env"

    # Test 5: CLI exit code 1 for invalid arguments (Commander.js returns 1)
    local test_dir="$SCENARIOS_DIR/exit-code-1-invalid-arg"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = false
EOF

    # Test 6: CLI exit code for invalid format option
    local test_dir="$SCENARIOS_DIR/exit-code-2-invalid-format"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = false
EOF
}

run_v157_tests() {
    # Test 1: Custom ignore - files in ignored dirs should not trigger
    run_test "ff-ignore-1: custom ignore dirs" \
        "$SCENARIOS_DIR/ff-ignore-1-custom" \
        0 \
        "cm process check" \
        ""

    # Test 2: Default ignore still works
    run_test "ff-ignore-2: default ignore (node_modules, .git)" \
        "$SCENARIOS_DIR/ff-ignore-2-defaults" \
        0 \
        "cm process check" \
        ""

    # Test 3: Ignore with glob - dist-* ignored, src not
    run_test "ff-ignore-3: glob ignore pattern" \
        "$SCENARIOS_DIR/ff-ignore-3-glob" \
        1 \
        "cm process check" \
        "src"

    # Test 4: Empty ignore array - should check node_modules too
    run_test "ff-ignore-4: empty ignore array" \
        "$SCENARIOS_DIR/ff-ignore-4-empty" \
        1 \
        "cm process check" \
        "node_modules"

    # Test 5: Invalid CLI argument returns exit code 1 (Commander.js behavior)
    run_test "exit-code-1: invalid argument" \
        "$SCENARIOS_DIR/exit-code-1-invalid-arg" \
        1 \
        "cm process check -f invalid_format" \
        "invalid"

    # Test 6: Invalid format option
    run_test "exit-code-2: invalid format" \
        "$SCENARIOS_DIR/exit-code-2-invalid-format" \
        1 \
        "cm process check --format xyz" \
        "invalid"
}

# ============================================================================
# v1.5.6 TESTS: DUPLICATE EXTENSIONS + BLOCK COMMENTS
# ============================================================================

setup_v156_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}DUPLICATE EXTENSIONS + BLOCK COMMENTS (v1.5.6)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Duplicate extensions in naming rules - should fail validation
    local test_dir="$SCENARIOS_DIR/dup-ext-1-duplicate"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.naming]
enabled = true

[[code.naming.rules]]
extensions = ["ts", "tsx"]
file_case = "kebab-case"
folder_case = "kebab-case"

[[code.naming.rules]]
extensions = ["ts", "js"]
file_case = "camelCase"
folder_case = "kebab-case"
EOF

    # Test 2: No duplicate extensions - should pass validation
    local test_dir="$SCENARIOS_DIR/dup-ext-2-no-dup"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.naming]
enabled = true

[[code.naming.rules]]
extensions = ["ts", "tsx"]
file_case = "kebab-case"
folder_case = "kebab-case"

[[code.naming.rules]]
extensions = ["js", "jsx"]
file_case = "camelCase"
folder_case = "kebab-case"
EOF

    # Test 3: Block comment disable detection
    local test_dir="$SCENARIOS_DIR/block-comment-1-detect"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    mkdir -p "$test_dir/src"
    cat > "$test_dir/src/test.ts" << 'EOF'
/* eslint-disable */
const x = 1;
/* eslint-enable */
EOF

    # Test 4: Line comment disable (existing functionality)
    local test_dir="$SCENARIOS_DIR/block-comment-2-line"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    mkdir -p "$test_dir/src"
    cat > "$test_dir/src/test.ts" << 'EOF'
// eslint-disable-next-line
const x = 1;
EOF

    # Test 5: No disable comments - should pass
    local test_dir="$SCENARIOS_DIR/block-comment-3-clean"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    mkdir -p "$test_dir/src"
    cat > "$test_dir/src/test.ts" << 'EOF'
const x = 1;
const y = 2;
EOF
}

run_v156_tests() {
    # Test 1: Duplicate extensions should fail config validation
    run_test "dup-ext-1: duplicate extensions rejected" \
        "$SCENARIOS_DIR/dup-ext-1-duplicate" \
        2 \
        "cm validate config" \
        "Extension"

    # Test 2: No duplicates should pass
    run_test "dup-ext-2: no duplicate extensions" \
        "$SCENARIOS_DIR/dup-ext-2-no-dup" \
        0 \
        "cm validate config" \
        ""

    # Test 3: Block comment detection
    run_test "block-comment-1: detect block comment disable" \
        "$SCENARIOS_DIR/block-comment-1-detect" \
        1 \
        "cm code check" \
        "eslint-disable"

    # Test 4: Line comment detection
    run_test "block-comment-2: detect line comment disable" \
        "$SCENARIOS_DIR/block-comment-2-line" \
        1 \
        "cm code check" \
        "eslint-disable"

    # Test 5: Clean file passes
    run_test "block-comment-3: clean file passes" \
        "$SCENARIOS_DIR/block-comment-3-clean" \
        0 \
        "cm code check" \
        ""
}

# ============================================================================
# v1.5.5 TESTS: TIER VALIDATION IMPROVEMENTS
# ============================================================================

setup_v155_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}TIER VALIDATION IMPROVEMENTS (v1.5.5)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Git root lookup (Bug #4 fix) - metadata in project root
    local test_dir="$SCENARIOS_DIR/tier-fix-1-git-root"
    mkdir -p "$test_dir/config"
    cat > "$test_dir/config/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF
    # Initialize as git repo
    (cd "$test_dir" && git init --quiet 2>/dev/null)

    # Test 2: YAML parse error warning (Bug #6 fix)
    local test_dir="$SCENARIOS_DIR/tier-fix-2-yaml-warning"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
  invalid: yaml: here
EOF
    # Initialize as git repo for tier lookup to work
    (cd "$test_dir" && git init --quiet 2>/dev/null)

    # Test 3: Empty rulesets warning (Bug #8 fix)
    local test_dir="$SCENARIOS_DIR/tier-fix-3-empty-rulesets"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = []
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF
    # Initialize as git repo for tier lookup to work
    (cd "$test_dir" && git init --quiet 2>/dev/null)

    # Test 4: Invalid tier shows valid values (Bug #9 fix)
    local test_dir="$SCENARIOS_DIR/tier-fix-4-valid-values"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: staging
EOF
    # Initialize as git repo for tier lookup to work
    (cd "$test_dir" && git init --quiet 2>/dev/null)

    # Test 5: Empty vs missing metadata distinction (Bug #7 fix)
    local test_dir="$SCENARIOS_DIR/tier-fix-5-empty-metadata"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    touch "$test_dir/repo-metadata.yaml"
    # Initialize as git repo for tier lookup to work
    (cd "$test_dir" && git init --quiet 2>/dev/null)

    # Test 6: Glob pattern validation for forbidden_files
    local test_dir="$SCENARIOS_DIR/tier-fix-6-glob-validation"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["[invalid"]
EOF
}

run_v155_tests() {
    # Test 1: Git root lookup - should find metadata in root
    run_test "tier-fix-1: git root metadata lookup" \
        "$SCENARIOS_DIR/tier-fix-1-git-root" \
        0 \
        "cm validate tier --config config/check.toml" \
        "production"

    # Test 2: YAML parse error - should warn
    run_test "tier-fix-2: YAML parse error warning" \
        "$SCENARIOS_DIR/tier-fix-2-yaml-warning" \
        0 \
        "cm validate tier 2>&1" \
        "warning\|error\|parse\|invalid"

    # Test 3: Empty rulesets - should warn
    run_test "tier-fix-3: empty rulesets warning" \
        "$SCENARIOS_DIR/tier-fix-3-empty-rulesets" \
        0 \
        "cm validate tier 2>&1" \
        "warning\|empty"

    # Test 4: Invalid tier - should show valid options (warning is shown, validation may still fail)
    run_test "tier-fix-4: invalid tier shows valid values" \
        "$SCENARIOS_DIR/tier-fix-4-valid-values" \
        0 \
        "cm validate tier 2>&1" \
        "Invalid tier.*Valid values"

    # Test 5: Empty metadata - should indicate empty
    run_test "tier-fix-5: empty metadata distinction" \
        "$SCENARIOS_DIR/tier-fix-5-empty-metadata" \
        0 \
        "cm validate tier 2>&1" \
        "empty\|default"

    # Test 6: Invalid glob pattern - should fail validation
    run_test "tier-fix-6: glob pattern validation" \
        "$SCENARIOS_DIR/tier-fix-6-glob-validation" \
        2 \
        "cm validate config" \
        "pattern\|invalid\|glob"
}

# ============================================================================
# v1.5.4 TESTS: FORBIDDEN FILES FIX VERIFICATION (Bug #1 fix)
# ============================================================================

setup_v154_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}FORBIDDEN FILES FIX VERIFICATION (v1.5.4)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Basic forbidden files now works (was completely broken)
    local test_dir="$SCENARIOS_DIR/ff-fix-1-basic"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 2: Forbidden files with glob pattern now works
    local test_dir="$SCENARIOS_DIR/ff-fix-2-glob"
    mkdir -p "$test_dir/secrets"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/*.key", "**/*.pem"]
EOF
    touch "$test_dir/secrets/server.key"
    touch "$test_dir/server.pem"

    # Test 3: JSON output includes forbidden files check
    local test_dir="$SCENARIOS_DIR/ff-fix-3-json"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 4: Exit code is 1 when violations found
    local test_dir="$SCENARIOS_DIR/ff-fix-4-exit"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 5: No false positives when file doesn't exist
    local test_dir="$SCENARIOS_DIR/ff-fix-5-clean"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env", "credentials.json"]
EOF
}

run_v154_tests() {
    # Test 1: Basic forbidden files detection works
    run_test "ff-fix-1: basic detection works" \
        "$SCENARIOS_DIR/ff-fix-1-basic" \
        1 \
        "cm process check" \
        "forbidden\|.env"

    # Test 2: Glob pattern works
    run_test "ff-fix-2: glob pattern works" \
        "$SCENARIOS_DIR/ff-fix-2-glob" \
        1 \
        "cm process check" \
        "forbidden\|.key\|.pem"

    # Test 3: JSON output includes forbidden files
    run_test "ff-fix-3: JSON output format" \
        "$SCENARIOS_DIR/ff-fix-3-json" \
        1 \
        "cm process check --format json" \
        "forbidden"

    # Test 4: Exit code is 1
    run_test "ff-fix-4: exit code 1 on violation" \
        "$SCENARIOS_DIR/ff-fix-4-exit" \
        1 \
        "cm process check" \
        ""

    # Test 5: Clean repo passes
    run_test "ff-fix-5: clean repo passes" \
        "$SCENARIOS_DIR/ff-fix-5-clean" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# v1.5.0 TESTS: TYPESCRIPT NAMING CONVENTIONS
# ============================================================================

setup_v150_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}TYPESCRIPT NAMING CONVENTIONS (v1.5.0)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Note: These tests require eslint and typescript setup
    # We'll test config validation and basic behavior

    # Test 1: Naming convention config accepted
    local test_dir="$SCENARIOS_DIR/naming-1-config"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.naming]
enabled = true

[[code.naming.rules]]
extensions = ["ts", "tsx"]
file_case = "kebab-case"
folder_case = "kebab-case"
EOF

    # Test 2: Multiple naming rules
    local test_dir="$SCENARIOS_DIR/naming-2-multi"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.naming]
enabled = true

[[code.naming.rules]]
extensions = ["ts"]
file_case = "kebab-case"
folder_case = "kebab-case"

[[code.naming.rules]]
extensions = ["tsx"]
file_case = "PascalCase"
folder_case = "kebab-case"

[[code.naming.rules]]
extensions = ["test.ts"]
file_case = "kebab-case"
folder_case = "kebab-case"
EOF
}

run_v150_tests() {
    # Test 1: Config is valid
    run_test "naming-1: naming convention config valid" \
        "$SCENARIOS_DIR/naming-1-config" \
        0 \
        "cm validate config" \
        ""

    # Test 2: Multiple rules config valid
    run_test "naming-2: multiple naming rules valid" \
        "$SCENARIOS_DIR/naming-2-multi" \
        0 \
        "cm validate config" \
        ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "check-my-toolkit E2E Test Suite"
    echo "Version: 1.5.0 - 1.6.0 features"
    echo "=========================================="

    # Check cm is available
    if ! command -v cm &> /dev/null; then
        echo -e "${RED}Error: cm (check-my-toolkit) not found${NC}"
        echo "Installing check-my-toolkit@1.6.0..."
        npm install -g check-my-toolkit@1.6.0
    fi

    # Show version
    echo "Using: $(cm --version 2>/dev/null || echo 'version unknown')"
    echo ""

    cleanup

    # Run all test suites
    setup_ci_commands_tests
    run_ci_commands_tests

    setup_v157_tests
    run_v157_tests

    setup_v156_tests
    run_v156_tests

    setup_v155_tests
    run_v155_tests

    setup_v154_tests
    run_v154_tests

    setup_v150_tests
    run_v150_tests

    echo ""
    echo "=========================================="
    echo "RESULTS"
    echo "=========================================="
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"

    if [ ${#BUGS_FOUND[@]} -gt 0 ]; then
        echo ""
        echo "=========================================="
        echo "POTENTIAL BUGS FOUND:"
        echo "=========================================="
        for bug in "${BUGS_FOUND[@]}"; do
            echo -e "${RED}- $bug${NC}"
        done
    fi

    # Save results to file
    {
        echo "Test Results - $(date)"
        echo "Version: check-my-toolkit 1.5.0 - 1.6.0"
        echo "==================="
        echo "Passed: $PASSED"
        echo "Failed: $FAILED"
        echo ""
        if [ ${#BUGS_FOUND[@]} -gt 0 ]; then
            echo "Bugs Found:"
            for bug in "${BUGS_FOUND[@]}"; do
                echo "- $bug"
            done
        fi
    } > "$RESULTS_FILE"

    echo ""
    echo "Results saved to: $RESULTS_FILE"

    exit $FAILED
}

main "$@"
