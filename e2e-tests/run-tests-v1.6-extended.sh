#!/bin/bash

# Extended E2E Test Suite for check-my-toolkit v1.6.0
# Tests additional features not covered in the v1.5-v1.6 suite

BASE_DIR="/Users/christopherlittle/Documents/GitHub/personal/cmt-e2e-process/e2e-tests"
SCENARIOS_DIR="$BASE_DIR/scenarios-v1.6-extended"
RESULTS_FILE="$BASE_DIR/test-results-v1.6-extended.txt"

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
        if ! echo "$output" | grep -qE "$expected_output"; then
            passed=false
            failure_reason="expected output '$expected_output' not found"
        fi
    fi

    # Check NOT expected output if provided
    if [ -n "$not_expected_output" ] && [ "$passed" = true ]; then
        if echo "$output" | grep -qE "$not_expected_output"; then
            passed=false
            failure_reason="unexpected output '$not_expected_output' found"
        fi
    fi

    if [ "$passed" = true ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} ($failure_reason)"
        echo "  Output: ${output:0:500}"
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
# BRANCH NAMING VALIDATION (process.branches)
# ============================================================================

setup_branch_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}BRANCH NAMING TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Valid branch name pattern
    local test_dir="$SCENARIOS_DIR/branch-1-valid"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = true
pattern = "^(feature|fix|hotfix)/[A-Z]+-[0-9]+/.+"
exclude = ["main", "develop"]
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "feature/PROJ-123/add-login" 2>/dev/null)

    # Test 2: Invalid branch name pattern
    local test_dir="$SCENARIOS_DIR/branch-2-invalid"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = true
pattern = "^(feature|fix|hotfix)/[A-Z]+-[0-9]+/.+"
exclude = ["main", "develop"]
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "my-feature-branch" 2>/dev/null)

    # Test 3: Excluded branch (main) - should pass
    local test_dir="$SCENARIOS_DIR/branch-3-excluded"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = true
pattern = "^(feature|fix|hotfix)/[A-Z]+-[0-9]+/.+"
exclude = ["main", "develop"]
EOF
    (cd "$test_dir" && git init --quiet)  # starts on main by default

    # Test 4: Branch pattern with version format
    local test_dir="$SCENARIOS_DIR/branch-4-version"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = true
pattern = "^(feature|fix)/v[0-9]+\\.[0-9]+\\.[0-9]+/.+"
exclude = ["main"]
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "feature/v1.2.3/new-feature" 2>/dev/null)

    # Test 5: Empty exclude array
    local test_dir="$SCENARIOS_DIR/branch-5-no-exclude"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = true
pattern = "^(feature|fix)/.+"
exclude = []
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "feature/test" 2>/dev/null)

    # Test 6: Disabled branches check
    local test_dir="$SCENARIOS_DIR/branch-6-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.branches]
enabled = false
pattern = "^(feature|fix)/.+"
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "any-name-works" 2>/dev/null)
}

run_branch_tests() {
    run_test "branch-1: valid branch name" \
        "$SCENARIOS_DIR/branch-1-valid" \
        0 \
        "cm process check-branch" \
        ""

    run_test "branch-2: invalid branch name" \
        "$SCENARIOS_DIR/branch-2-invalid" \
        1 \
        "cm process check-branch" \
        "branch\|pattern\|invalid"

    run_test "branch-3: excluded branch (main)" \
        "$SCENARIOS_DIR/branch-3-excluded" \
        0 \
        "cm process check-branch" \
        ""

    run_test "branch-4: version pattern match" \
        "$SCENARIOS_DIR/branch-4-version" \
        0 \
        "cm process check-branch" \
        ""

    run_test "branch-5: empty exclude array" \
        "$SCENARIOS_DIR/branch-5-no-exclude" \
        0 \
        "cm process check-branch" \
        ""

    run_test "branch-6: disabled branches check" \
        "$SCENARIOS_DIR/branch-6-disabled" \
        0 \
        "cm process check-branch" \
        ""
}

# ============================================================================
# COMMIT MESSAGE VALIDATION (process.check-commit)
# ============================================================================

setup_commit_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}COMMIT MESSAGE TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Valid commit message with ticket
    local test_dir="$SCENARIOS_DIR/commit-1-valid"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|JIRA)-[0-9]+"
require_in_commits = true
EOF
    echo "PROJ-123: Add new login feature" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)

    # Test 2: Missing ticket in commit
    local test_dir="$SCENARIOS_DIR/commit-2-missing-ticket"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|JIRA)-[0-9]+"
require_in_commits = true
EOF
    echo "Add new login feature" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)

    # Test 3: Ticket not required
    local test_dir="$SCENARIOS_DIR/commit-3-not-required"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|JIRA)-[0-9]+"
require_in_commits = false
EOF
    echo "Add new login feature" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)

    # Test 4: Disabled ticket check
    local test_dir="$SCENARIOS_DIR/commit-4-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = false
EOF
    echo "Any commit message works" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)

    # Test 5: Ticket in body, not subject
    local test_dir="$SCENARIOS_DIR/commit-5-body-ticket"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|JIRA)-[0-9]+"
require_in_commits = true
EOF
    cat > "$test_dir/COMMIT_MSG" << 'EOF'
Add new feature

This implements the feature described in PROJ-456.
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 6: Multiple ticket patterns
    local test_dir="$SCENARIOS_DIR/commit-6-multi-pattern"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|JIRA|ISSUE)-[0-9]+"
require_in_commits = true
EOF
    echo "ISSUE-789: Fix critical bug" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)
}

run_commit_tests() {
    run_test "commit-1: valid commit with ticket" \
        "$SCENARIOS_DIR/commit-1-valid" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""

    run_test "commit-2: missing ticket in commit" \
        "$SCENARIOS_DIR/commit-2-missing-ticket" \
        1 \
        "cm process check-commit COMMIT_MSG" \
        "ticket\|PROJ\|pattern"

    run_test "commit-3: ticket not required" \
        "$SCENARIOS_DIR/commit-3-not-required" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""

    run_test "commit-4: disabled ticket check" \
        "$SCENARIOS_DIR/commit-4-disabled" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""

    run_test "commit-5: ticket in body" \
        "$SCENARIOS_DIR/commit-5-body-ticket" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""

    run_test "commit-6: multiple ticket patterns" \
        "$SCENARIOS_DIR/commit-6-multi-pattern" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""
}

# ============================================================================
# COVERAGE THRESHOLD (process.coverage)
# ============================================================================

setup_coverage_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}COVERAGE THRESHOLD TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Coverage meets threshold
    local test_dir="$SCENARIOS_DIR/coverage-1-meets"
    mkdir -p "$test_dir/coverage"
    cat > "$test_dir/check.toml" << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
EOF
    # Create mock coverage report (lcov format)
    cat > "$test_dir/coverage/lcov.info" << 'EOF'
TN:
SF:/src/index.ts
FN:1,main
FNDA:10,main
FNF:1
FNH:1
DA:1,10
DA:2,10
DA:3,10
DA:4,10
DA:5,10
LH:5
LF:5
end_of_record
EOF

    # Test 2: Coverage below threshold
    local test_dir="$SCENARIOS_DIR/coverage-2-below"
    mkdir -p "$test_dir/coverage"
    cat > "$test_dir/check.toml" << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
EOF
    # Create mock coverage with low coverage
    cat > "$test_dir/coverage/lcov.info" << 'EOF'
TN:
SF:/src/index.ts
DA:1,1
DA:2,0
DA:3,0
DA:4,0
DA:5,0
LH:1
LF:5
end_of_record
EOF

    # Test 3: No coverage file
    local test_dir="$SCENARIOS_DIR/coverage-3-no-file"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
EOF

    # Test 4: Coverage disabled
    local test_dir="$SCENARIOS_DIR/coverage-4-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.coverage]
enabled = false
min_threshold = 80
EOF

    # Test 5: Threshold of 0
    local test_dir="$SCENARIOS_DIR/coverage-5-zero"
    mkdir -p "$test_dir/coverage"
    cat > "$test_dir/check.toml" << 'EOF'
[process.coverage]
enabled = true
min_threshold = 0
EOF
    cat > "$test_dir/coverage/lcov.info" << 'EOF'
TN:
SF:/src/index.ts
DA:1,0
LH:0
LF:1
end_of_record
EOF
}

run_coverage_tests() {
    run_test "coverage-1: meets threshold" \
        "$SCENARIOS_DIR/coverage-1-meets" \
        0 \
        "cm process check" \
        ""

    run_test "coverage-2: below threshold" \
        "$SCENARIOS_DIR/coverage-2-below" \
        1 \
        "cm process check" \
        "coverage\|threshold\|%"

    run_test "coverage-3: no coverage file" \
        "$SCENARIOS_DIR/coverage-3-no-file" \
        1 \
        "cm process check" \
        "coverage\|missing\|not found"

    run_test "coverage-4: disabled" \
        "$SCENARIOS_DIR/coverage-4-disabled" \
        0 \
        "cm process check" \
        ""

    run_test "coverage-5: threshold of 0" \
        "$SCENARIOS_DIR/coverage-5-zero" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# INFRA TAGGING (infra.tagging)
# ============================================================================

setup_infra_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}INFRA TAGGING TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Valid tagging config
    local test_dir="$SCENARIOS_DIR/infra-1-valid-config"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[infra.tagging]
enabled = true
region = "us-east-1"
required = ["Environment", "Owner", "CostCenter"]

[infra.tagging.values]
Environment = ["dev", "staging", "prod"]
EOF

    # Test 2: Invalid tagging config - missing required field
    local test_dir="$SCENARIOS_DIR/infra-2-invalid-config"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[infra.tagging]
enabled = true
required = ["Environment"]
EOF

    # Test 3: Disabled tagging
    local test_dir="$SCENARIOS_DIR/infra-3-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[infra.tagging]
enabled = false
EOF
}

run_infra_tests() {
    run_test "infra-1: valid tagging config" \
        "$SCENARIOS_DIR/infra-1-valid-config" \
        0 \
        "cm validate config" \
        ""

    run_test "infra-2: invalid tagging config" \
        "$SCENARIOS_DIR/infra-2-invalid-config" \
        0 \
        "cm validate config" \
        ""

    run_test "infra-3: disabled tagging" \
        "$SCENARIOS_DIR/infra-3-disabled" \
        0 \
        "cm validate config" \
        ""
}

# ============================================================================
# PR SIZE LIMITS (process.pr)
# ============================================================================

setup_pr_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}PR SIZE LIMIT TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Valid PR config
    local test_dir="$SCENARIOS_DIR/pr-1-valid"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.pr]
enabled = true
max_files = 20
max_lines = 500
EOF

    # Test 2: PR config with exclude patterns
    local test_dir="$SCENARIOS_DIR/pr-2-exclude"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.pr]
enabled = true
max_files = 10
max_lines = 200
exclude = ["*.lock", "*.generated.ts"]
EOF

    # Test 3: Zero max values (potential edge case)
    local test_dir="$SCENARIOS_DIR/pr-3-zero"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.pr]
enabled = true
max_files = 0
max_lines = 0
EOF

    # Test 4: Negative values (should fail validation)
    local test_dir="$SCENARIOS_DIR/pr-4-negative"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.pr]
enabled = true
max_files = -1
max_lines = -10
EOF
}

run_pr_tests() {
    run_test "pr-1: valid PR config" \
        "$SCENARIOS_DIR/pr-1-valid" \
        0 \
        "cm validate config" \
        ""

    run_test "pr-2: PR config with excludes" \
        "$SCENARIOS_DIR/pr-2-exclude" \
        0 \
        "cm validate config" \
        ""

    run_test "pr-3: zero max values" \
        "$SCENARIOS_DIR/pr-3-zero" \
        0 \
        "cm validate config" \
        ""

    run_test "pr-4: negative values rejected" \
        "$SCENARIOS_DIR/pr-4-negative" \
        2 \
        "cm validate config" \
        "invalid\|negative\|minimum"
}

# ============================================================================
# HOOKS VALIDATION (process.hooks)
# ============================================================================

setup_hooks_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}HOOKS VALIDATION TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: Husky hooks present
    local test_dir="$SCENARIOS_DIR/hooks-1-present"
    mkdir -p "$test_dir/.husky"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit"]
EOF
    echo "#!/bin/sh" > "$test_dir/.husky/pre-commit"
    echo "npm run lint" >> "$test_dir/.husky/pre-commit"
    chmod +x "$test_dir/.husky/pre-commit"
    (cd "$test_dir" && git init --quiet)

    # Test 2: Missing required hook
    local test_dir="$SCENARIOS_DIR/hooks-2-missing"
    mkdir -p "$test_dir/.husky"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit", "pre-push"]
EOF
    echo "#!/bin/sh" > "$test_dir/.husky/pre-commit"
    chmod +x "$test_dir/.husky/pre-commit"
    (cd "$test_dir" && git init --quiet)

    # Test 3: No husky directory
    local test_dir="$SCENARIOS_DIR/hooks-3-no-husky"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit"]
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 4: Disabled hooks
    local test_dir="$SCENARIOS_DIR/hooks-4-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = false
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 5: Husky not required
    local test_dir="$SCENARIOS_DIR/hooks-5-no-husky-req"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = false
EOF
    (cd "$test_dir" && git init --quiet)
}

run_hooks_tests() {
    run_test "hooks-1: husky hooks present" \
        "$SCENARIOS_DIR/hooks-1-present" \
        0 \
        "cm process check" \
        ""

    run_test "hooks-2: missing required hook" \
        "$SCENARIOS_DIR/hooks-2-missing" \
        1 \
        "cm process check" \
        "pre-push\|missing\|hook"

    run_test "hooks-3: no husky directory" \
        "$SCENARIOS_DIR/hooks-3-no-husky" \
        1 \
        "cm process check" \
        "husky\|missing"

    run_test "hooks-4: disabled hooks" \
        "$SCENARIOS_DIR/hooks-4-disabled" \
        0 \
        "cm process check" \
        ""

    run_test "hooks-5: husky not required" \
        "$SCENARIOS_DIR/hooks-5-no-husky-req" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# CODE QUALITY - DISABLE COMMENTS (extended)
# ============================================================================

setup_disable_comment_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}DISABLE COMMENTS TESTS (extended)${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: @ts-ignore detection
    local test_dir="$SCENARIOS_DIR/disable-1-ts-ignore"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    cat > "$test_dir/src/test.ts" << 'EOF'
// @ts-ignore
const x: number = "string";
EOF

    # Test 2: @ts-expect-error (should be allowed?)
    local test_dir="$SCENARIOS_DIR/disable-2-ts-expect"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    cat > "$test_dir/src/test.ts" << 'EOF'
// @ts-expect-error testing error handling
const x: number = "string";
EOF

    # Test 3: noqa comments (Python)
    local test_dir="$SCENARIOS_DIR/disable-3-noqa"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    cat > "$test_dir/src/test.py" << 'EOF'
import os  # noqa: F401
x = 1
EOF

    # Test 4: type: ignore (Python)
    local test_dir="$SCENARIOS_DIR/disable-4-type-ignore"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    cat > "$test_dir/src/test.py" << 'EOF'
def foo(x):  # type: ignore
    return x + 1
EOF

    # Test 5: Multiple disable comments in one file
    local test_dir="$SCENARIOS_DIR/disable-5-multiple"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = true
EOF
    cat > "$test_dir/src/test.ts" << 'EOF'
// eslint-disable-next-line
const x = 1;
/* eslint-disable */
const y = 2;
// @ts-ignore
const z: number = "3";
EOF

    # Test 6: Disabled check
    local test_dir="$SCENARIOS_DIR/disable-6-disabled"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[code.quality.disable-comments]
enabled = false
EOF
    cat > "$test_dir/src/test.ts" << 'EOF'
// eslint-disable-next-line
const x = 1;
EOF
}

run_disable_comment_tests() {
    run_test "disable-1: @ts-ignore detected" \
        "$SCENARIOS_DIR/disable-1-ts-ignore" \
        1 \
        "cm code check" \
        "ts-ignore\|disable"

    run_test "disable-2: @ts-expect-error" \
        "$SCENARIOS_DIR/disable-2-ts-expect" \
        1 \
        "cm code check" \
        "ts-expect\|disable"

    run_test "disable-3: noqa comment" \
        "$SCENARIOS_DIR/disable-3-noqa" \
        1 \
        "cm code check" \
        "noqa\|disable"

    run_test "disable-4: type: ignore" \
        "$SCENARIOS_DIR/disable-4-type-ignore" \
        1 \
        "cm code check" \
        "type.*ignore\|disable"

    run_test "disable-5: multiple disables" \
        "$SCENARIOS_DIR/disable-5-multiple" \
        1 \
        "cm code check" \
        "3\|multiple\|disable"

    run_test "disable-6: check disabled" \
        "$SCENARIOS_DIR/disable-6-disabled" \
        0 \
        "cm code check" \
        ""
}

# ============================================================================
# COMBINED CHECK COMMAND (cm check)
# ============================================================================

setup_combined_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}COMBINED CHECK TESTS${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: All checks pass
    local test_dir="$SCENARIOS_DIR/combined-1-pass"
    mkdir -p "$test_dir/.husky"
    mkdir -p "$test_dir/.github/workflows"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit"]

[process.ci]
enabled = true
require_workflows = ["ci.yml"]
EOF
    echo "#!/bin/sh" > "$test_dir/.husky/pre-commit"
    chmod +x "$test_dir/.husky/pre-commit"
    cat > "$test_dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 2: Mixed results
    local test_dir="$SCENARIOS_DIR/combined-2-mixed"
    mkdir -p "$test_dir/.husky"
    mkdir -p "$test_dir/src"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit"]

[code.quality.disable-comments]
enabled = true
EOF
    echo "#!/bin/sh" > "$test_dir/.husky/pre-commit"
    chmod +x "$test_dir/.husky/pre-commit"
    cat > "$test_dir/src/test.ts" << 'EOF'
// eslint-disable-next-line
const x = 1;
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 3: JSON output format
    local test_dir="$SCENARIOS_DIR/combined-3-json"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = false

[process.ci]
enabled = false
EOF
    (cd "$test_dir" && git init --quiet)
}

run_combined_tests() {
    run_test "combined-1: all checks pass" \
        "$SCENARIOS_DIR/combined-1-pass" \
        0 \
        "cm check" \
        ""

    run_test "combined-2: mixed results" \
        "$SCENARIOS_DIR/combined-2-mixed" \
        1 \
        "cm check" \
        "disable\|eslint"

    run_test "combined-3: JSON output" \
        "$SCENARIOS_DIR/combined-3-json" \
        0 \
        "cm check --format json" \
        '"\|{\|}'
}

# ============================================================================
# EDGE CASES AND ERROR HANDLING
# ============================================================================

setup_edge_tests() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}EDGE CASES AND ERROR HANDLING${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Test 1: No check.toml file
    local test_dir="$SCENARIOS_DIR/edge-1-no-config"
    mkdir -p "$test_dir"

    # Test 2: Empty check.toml
    local test_dir="$SCENARIOS_DIR/edge-2-empty-config"
    mkdir -p "$test_dir"
    touch "$test_dir/check.toml"

    # Test 3: Invalid TOML syntax
    local test_dir="$SCENARIOS_DIR/edge-3-invalid-toml"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[invalid
syntax here = true
EOF

    # Test 4: Unknown config key
    local test_dir="$SCENARIOS_DIR/edge-4-unknown-key"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
unknown_option = "value"
EOF

    # Test 5: Config with only disabled checks
    local test_dir="$SCENARIOS_DIR/edge-5-all-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = false

[process.ci]
enabled = false

[code.quality.disable-comments]
enabled = false
EOF
    (cd "$test_dir" && git init --quiet)

    # Test 6: Very long pattern string
    local test_dir="$SCENARIOS_DIR/edge-6-long-pattern"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << EOF
[process.branches]
enabled = true
pattern = "^(feature|fix|hotfix|bugfix|release|chore|docs|style|refactor|perf|test|build|ci|revert)/[A-Z]{2,10}-[0-9]{1,10}/.{1,100}"
EOF
    (cd "$test_dir" && git init --quiet && git checkout -b "feature/PROJ-123/test" 2>/dev/null)

    # Test 7: Unicode in patterns
    local test_dir="$SCENARIOS_DIR/edge-7-unicode"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.tickets]
enabled = true
pattern = "^(PROJ|任务)-[0-9]+"
require_in_commits = true
EOF
    echo "任务-123: 添加功能" > "$test_dir/COMMIT_MSG"
    (cd "$test_dir" && git init --quiet)
}

run_edge_tests() {
    run_test "edge-1: no config file" \
        "$SCENARIOS_DIR/edge-1-no-config" \
        2 \
        "cm check" \
        "config\|not found\|check.toml"

    run_test "edge-2: empty config file" \
        "$SCENARIOS_DIR/edge-2-empty-config" \
        0 \
        "cm validate config" \
        ""

    run_test "edge-3: invalid TOML syntax" \
        "$SCENARIOS_DIR/edge-3-invalid-toml" \
        2 \
        "cm validate config" \
        "TOML\|parse\|syntax\|invalid"

    run_test "edge-4: unknown config key" \
        "$SCENARIOS_DIR/edge-4-unknown-key" \
        2 \
        "cm validate config" \
        "unknown\|unrecognized\|invalid"

    run_test "edge-5: all checks disabled" \
        "$SCENARIOS_DIR/edge-5-all-disabled" \
        0 \
        "cm check" \
        ""

    run_test "edge-6: long pattern string" \
        "$SCENARIOS_DIR/edge-6-long-pattern" \
        0 \
        "cm process check-branch" \
        ""

    run_test "edge-7: unicode in patterns" \
        "$SCENARIOS_DIR/edge-7-unicode" \
        0 \
        "cm process check-commit COMMIT_MSG" \
        ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "check-my-toolkit Extended E2E Test Suite"
    echo "Version: 1.6.0"
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
    setup_branch_tests
    run_branch_tests

    setup_commit_tests
    run_commit_tests

    setup_coverage_tests
    run_coverage_tests

    setup_infra_tests
    run_infra_tests

    setup_pr_tests
    run_pr_tests

    setup_hooks_tests
    run_hooks_tests

    setup_disable_comment_tests
    run_disable_comment_tests

    setup_combined_tests
    run_combined_tests

    setup_edge_tests
    run_edge_tests

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
        echo "Version: check-my-toolkit 1.6.0 (extended tests)"
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
