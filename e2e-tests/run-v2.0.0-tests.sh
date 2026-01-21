#!/bin/bash
# E2E Tests for check-my-toolkit v2.0.0 new features
# Tests features introduced between v1.6.0 and v2.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/v2.0.0-scenarios"
RESULTS_FILE="$SCRIPT_DIR/v2.0.0-test-results.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
BUGS_FOUND=()

echo "======================================"
echo "check-my-toolkit v2.0.0 E2E Tests"
echo "======================================"
echo ""
echo "Testing features introduced since v1.6.0"
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_dir="$2"
    local expected_result="$3"  # "pass" or "fail" or "contains:text"
    local command="$4"

    echo -n "Testing: $test_name... "

    cd "$test_dir"

    # Run the command and capture output
    output=$(eval "$command" 2>&1) || true
    exit_code=$?

    # Check result
    if [[ "$expected_result" == "pass" ]]; then
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected pass, got exit code $exit_code)"
            echo "  Output: $output"
            ((FAILED++))
            return 1
        fi
    elif [[ "$expected_result" == "fail" ]]; then
        if [[ $exit_code -ne 0 ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected fail, got pass)"
            echo "  Output: $output"
            ((FAILED++))
            return 1
        fi
    elif [[ "$expected_result" == contains:* ]]; then
        local expected_text="${expected_result#contains:}"
        if echo "$output" | grep -q "$expected_text"; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected output to contain: $expected_text)"
            echo "  Output: $output"
            ((FAILED++))
            return 1
        fi
    elif [[ "$expected_result" == not-contains:* ]]; then
        local unexpected_text="${expected_result#not-contains:}"
        if ! echo "$output" | grep -q "$unexpected_text"; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (output should NOT contain: $unexpected_text)"
            echo "  Output: $output"
            ((FAILED++))
            return 1
        fi
    fi
}

# Helper to create a test scenario
setup_scenario() {
    local scenario_dir="$1"
    rm -rf "$scenario_dir"
    mkdir -p "$scenario_dir"
    cd "$scenario_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
}

echo "=========================================="
echo "1. PROCESS.COMMITS - Commit Message Validation"
echo "=========================================="

# Test 1.1: Basic commit pattern validation
setup_scenario "$SCENARIOS_DIR/commits/pattern-valid"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
pattern = "^(feat|fix|docs|chore):"
EOF
echo "test" > file.txt && git add . && git commit -q -m "feat: initial"
run_test "1.1 Valid commit pattern" "$SCENARIOS_DIR/commits/pattern-valid" "pass" "cm validate config"

# Test 1.2: Commit types validation
setup_scenario "$SCENARIOS_DIR/commits/types"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix", "docs"]
EOF
run_test "1.2 Commit types config" "$SCENARIOS_DIR/commits/types" "pass" "cm validate config"

# Test 1.3: require_scope option
setup_scenario "$SCENARIOS_DIR/commits/require-scope"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix"]
require_scope = true
EOF
run_test "1.3 require_scope option" "$SCENARIOS_DIR/commits/require-scope" "pass" "cm validate config"

# Test 1.4: max_subject_length option
setup_scenario "$SCENARIOS_DIR/commits/max-subject"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
max_subject_length = 72
EOF
run_test "1.4 max_subject_length option" "$SCENARIOS_DIR/commits/max-subject" "pass" "cm validate config"

# Test 1.5: check-commit with valid conventional commit
setup_scenario "$SCENARIOS_DIR/commits/check-valid"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix", "docs"]
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
echo "feat: add new feature" > COMMIT_MSG
run_test "1.5 check-commit valid" "$SCENARIOS_DIR/commits/check-valid" "pass" "cm process check-commit COMMIT_MSG"

# Test 1.6: check-commit with invalid type
setup_scenario "$SCENARIOS_DIR/commits/check-invalid-type"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix", "docs"]
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
echo "invalid: wrong type" > COMMIT_MSG
run_test "1.6 check-commit invalid type" "$SCENARIOS_DIR/commits/check-invalid-type" "fail" "cm process check-commit COMMIT_MSG"

# Test 1.7: check-commit with scope when required
setup_scenario "$SCENARIOS_DIR/commits/check-scope-required"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix"]
require_scope = true
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
echo "feat: no scope" > COMMIT_MSG
run_test "1.7 check-commit missing scope" "$SCENARIOS_DIR/commits/check-scope-required" "fail" "cm process check-commit COMMIT_MSG"

# Test 1.8: check-commit with scope provided
setup_scenario "$SCENARIOS_DIR/commits/check-scope-provided"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = ["feat", "fix"]
require_scope = true
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
echo "feat(api): with scope" > COMMIT_MSG
run_test "1.8 check-commit with scope" "$SCENARIOS_DIR/commits/check-scope-provided" "pass" "cm process check-commit COMMIT_MSG"

# Test 1.9: check-commit subject too long
setup_scenario "$SCENARIOS_DIR/commits/check-subject-long"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
max_subject_length = 50
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
echo "feat: this is a very long commit message that exceeds the maximum subject length limit" > COMMIT_MSG
run_test "1.9 check-commit subject too long" "$SCENARIOS_DIR/commits/check-subject-long" "fail" "cm process check-commit COMMIT_MSG"

echo ""
echo "=========================================="
echo "2. PROCESS.CHANGESETS - Changeset Validation"
echo "=========================================="

# Test 2.1: Basic changesets config
setup_scenario "$SCENARIOS_DIR/changesets/basic"
cat > check.toml << 'EOF'
[process.changesets]
enabled = true
require_for_paths = ["src/**"]
EOF
run_test "2.1 Basic changesets config" "$SCENARIOS_DIR/changesets/basic" "pass" "cm validate config"

# Test 2.2: Changesets with exclude_paths
setup_scenario "$SCENARIOS_DIR/changesets/exclude"
cat > check.toml << 'EOF'
[process.changesets]
enabled = true
require_for_paths = ["src/**"]
exclude_paths = ["src/tests/**"]
EOF
run_test "2.2 Changesets with exclude_paths" "$SCENARIOS_DIR/changesets/exclude" "pass" "cm validate config"

# Test 2.3: Changesets validate_format
setup_scenario "$SCENARIOS_DIR/changesets/validate-format"
cat > check.toml << 'EOF'
[process.changesets]
enabled = true
validate_format = true
allowed_bump_types = ["patch", "minor"]
EOF
run_test "2.3 Changesets validate_format" "$SCENARIOS_DIR/changesets/validate-format" "pass" "cm validate config"

# Test 2.4: Changesets description requirements
setup_scenario "$SCENARIOS_DIR/changesets/description"
cat > check.toml << 'EOF'
[process.changesets]
enabled = true
require_description = true
min_description_length = 10
EOF
run_test "2.4 Changesets description requirements" "$SCENARIOS_DIR/changesets/description" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "3. PROCESS.CODEOWNERS - CODEOWNERS Validation"
echo "=========================================="

# Test 3.1: Basic codeowners config
setup_scenario "$SCENARIOS_DIR/codeowners/basic"
cat > check.toml << 'EOF'
[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@team/core"]
EOF
run_test "3.1 Basic codeowners config" "$SCENARIOS_DIR/codeowners/basic" "pass" "cm validate config"

# Test 3.2: Multiple codeowners rules
setup_scenario "$SCENARIOS_DIR/codeowners/multiple-rules"
cat > check.toml << 'EOF'
[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@team/core"]

[[process.codeowners.rules]]
pattern = "*.ts"
owners = ["@team/typescript"]

[[process.codeowners.rules]]
pattern = "docs/*"
owners = ["@team/docs", "@user1"]
EOF
run_test "3.2 Multiple codeowners rules" "$SCENARIOS_DIR/codeowners/multiple-rules" "pass" "cm validate config"

# Test 3.3: Codeowners empty rules array
setup_scenario "$SCENARIOS_DIR/codeowners/empty-rules"
cat > check.toml << 'EOF'
[process.codeowners]
enabled = true
rules = []
EOF
run_test "3.3 Codeowners empty rules (should fail or warn)" "$SCENARIOS_DIR/codeowners/empty-rules" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "4. PROCESS.DOCS - Documentation Checks"
echo "=========================================="

# Test 4.1: Basic docs config
setup_scenario "$SCENARIOS_DIR/docs/basic"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
path = "docs/"
EOF
mkdir -p docs
echo "# Documentation" > docs/README.md
run_test "4.1 Basic docs config" "$SCENARIOS_DIR/docs/basic" "pass" "cm validate config"

# Test 4.2: Docs with enforcement
setup_scenario "$SCENARIOS_DIR/docs/enforcement"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
enforcement = "block"
EOF
run_test "4.2 Docs enforcement option" "$SCENARIOS_DIR/docs/enforcement" "pass" "cm validate config"

# Test 4.3: Docs with size limits
setup_scenario "$SCENARIOS_DIR/docs/size-limits"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
max_files = 50
max_file_lines = 500
max_total_kb = 1024
EOF
run_test "4.3 Docs size limits" "$SCENARIOS_DIR/docs/size-limits" "pass" "cm validate config"

# Test 4.4: Docs staleness check
setup_scenario "$SCENARIOS_DIR/docs/staleness"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
staleness_days = 90

[process.docs.stale_mappings]
"src/api/**" = "docs/api.md"
"src/models/**" = "docs/models.md"
EOF
run_test "4.4 Docs staleness check" "$SCENARIOS_DIR/docs/staleness" "pass" "cm validate config"

# Test 4.5: Docs coverage requirement
setup_scenario "$SCENARIOS_DIR/docs/coverage"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
min_coverage = 80
coverage_paths = ["src/"]
exclude_patterns = ["*.test.ts"]
EOF
run_test "4.5 Docs coverage requirement" "$SCENARIOS_DIR/docs/coverage" "pass" "cm validate config"

# Test 4.6: Docs types with required sections
setup_scenario "$SCENARIOS_DIR/docs/types"
cat > check.toml << 'EOF'
[process.docs]
enabled = true

[process.docs.types.api]
required_sections = ["Overview", "Usage", "API Reference"]
frontmatter = ["title", "version"]

[process.docs.types.guide]
required_sections = ["Introduction", "Prerequisites"]
EOF
run_test "4.6 Docs types with required sections" "$SCENARIOS_DIR/docs/types" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "5. BUG VERIFICATION: process.coverage enforce_in (Bug #18)"
echo "=========================================="

# Test 5.1: Coverage with enforce_in = "config"
setup_scenario "$SCENARIOS_DIR/coverage/enforce-config"
cat > check.toml << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
enforce_in = "config"
EOF
run_test "5.1 Coverage enforce_in=config" "$SCENARIOS_DIR/coverage/enforce-config" "pass" "cm validate config"

# Test 5.2: Coverage with enforce_in = "ci"
setup_scenario "$SCENARIOS_DIR/coverage/enforce-ci"
cat > check.toml << 'EOF'
[process.coverage]
enabled = true
enforce_in = "ci"
ci_workflow = "ci.yml"
ci_job = "test"
EOF
run_test "5.2 Coverage enforce_in=ci" "$SCENARIOS_DIR/coverage/enforce-ci" "pass" "cm validate config"

# Test 5.3: Coverage with enforce_in = "both"
setup_scenario "$SCENARIOS_DIR/coverage/enforce-both"
cat > check.toml << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
enforce_in = "both"
ci_workflow = "ci.yml"
ci_job = "test"
EOF
run_test "5.3 Coverage enforce_in=both" "$SCENARIOS_DIR/coverage/enforce-both" "pass" "cm validate config"

# Test 5.4: Coverage check with lcov.info and min_threshold
setup_scenario "$SCENARIOS_DIR/coverage/with-lcov"
cat > check.toml << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
enforce_in = "config"
EOF
mkdir -p coverage
cat > coverage/lcov.info << 'EOF'
TN:
SF:src/index.ts
FN:1,main
FNDA:10,main
FNF:1
FNH:1
DA:1,10
DA:2,10
DA:3,0
LF:3
LH:2
BRF:0
BRH:0
end_of_record
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
run_test "5.4 Coverage check with lcov.info" "$SCENARIOS_DIR/coverage/with-lcov" "contains:Coverage" "cm process check"

echo ""
echo "=========================================="
echo "6. BUG VERIFICATION: process.pr.exclude (Bug #19)"
echo "=========================================="

# Test 6.1: PR exclude option now supported
setup_scenario "$SCENARIOS_DIR/pr-exclude/basic"
cat > check.toml << 'EOF'
[process.pr]
enabled = true
max_files = 10
max_lines = 200
exclude = ["*.lock", "*.generated.ts"]
EOF
run_test "6.1 PR exclude option" "$SCENARIOS_DIR/pr-exclude/basic" "pass" "cm validate config"

# Test 6.2: PR exclude with multiple patterns
setup_scenario "$SCENARIOS_DIR/pr-exclude/multiple"
cat > check.toml << 'EOF'
[process.pr]
enabled = true
max_files = 5
exclude = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "*.snap"]
EOF
run_test "6.2 PR exclude multiple patterns" "$SCENARIOS_DIR/pr-exclude/multiple" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "7. PROCESS.BRANCHES - Issue Requirements"
echo "=========================================="

# Test 7.1: Branch require_issue option
setup_scenario "$SCENARIOS_DIR/branches/require-issue"
cat > check.toml << 'EOF'
[process.branches]
enabled = true
require_issue = true
issue_pattern = "^[A-Z]+-[0-9]+"
EOF
run_test "7.1 Branch require_issue" "$SCENARIOS_DIR/branches/require-issue" "pass" "cm validate config"

# Test 7.2: Branch check valid with issue
setup_scenario "$SCENARIOS_DIR/branches/check-with-issue"
cat > check.toml << 'EOF'
[process.branches]
enabled = true
require_issue = true
issue_pattern = "PROJ-[0-9]+"
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
git checkout -q -b "feature/PROJ-123-add-feature"
run_test "7.2 Branch check with issue" "$SCENARIOS_DIR/branches/check-with-issue" "pass" "cm process check-branch"

# Test 7.3: Branch check missing issue
setup_scenario "$SCENARIOS_DIR/branches/check-missing-issue"
cat > check.toml << 'EOF'
[process.branches]
enabled = true
require_issue = true
issue_pattern = "PROJ-[0-9]+"
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
git checkout -q -b "feature/add-feature"
run_test "7.3 Branch check missing issue" "$SCENARIOS_DIR/branches/check-missing-issue" "fail" "cm process check-branch"

echo ""
echo "=========================================="
echo "8. PROCESS.HOOKS - Commands & Protected Branches"
echo "=========================================="

# Test 8.1: Hooks with commands
setup_scenario "$SCENARIOS_DIR/hooks/commands"
cat > check.toml << 'EOF'
[process.hooks]
enabled = true
require_husky = true
require_hooks = ["pre-commit", "pre-push"]

[process.hooks.commands]
"pre-commit" = ["npm run lint", "npm run format"]
"pre-push" = ["npm test"]
EOF
run_test "8.1 Hooks with commands" "$SCENARIOS_DIR/hooks/commands" "pass" "cm validate config"

# Test 8.2: Hooks with protected_branches
setup_scenario "$SCENARIOS_DIR/hooks/protected-branches"
cat > check.toml << 'EOF'
[process.hooks]
enabled = true
require_husky = true
protected_branches = ["main", "develop", "release/*"]
EOF
run_test "8.2 Hooks protected_branches" "$SCENARIOS_DIR/hooks/protected-branches" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "9. CODE.COVERAGE_RUN - Run Coverage"
echo "=========================================="

# Test 9.1: Basic coverage_run config
setup_scenario "$SCENARIOS_DIR/coverage-run/basic"
cat > check.toml << 'EOF'
[code.coverage_run]
enabled = true
min_threshold = 80
EOF
run_test "9.1 Basic coverage_run config" "$SCENARIOS_DIR/coverage-run/basic" "pass" "cm validate config"

# Test 9.2: Coverage_run with runner
setup_scenario "$SCENARIOS_DIR/coverage-run/with-runner"
cat > check.toml << 'EOF'
[code.coverage_run]
enabled = true
min_threshold = 80
runner = "vitest"
EOF
run_test "9.2 Coverage_run with runner" "$SCENARIOS_DIR/coverage-run/with-runner" "pass" "cm validate config"

# Test 9.3: Coverage_run with custom command
setup_scenario "$SCENARIOS_DIR/coverage-run/custom-command"
cat > check.toml << 'EOF'
[code.coverage_run]
enabled = true
min_threshold = 70
command = "pnpm test:coverage"
EOF
run_test "9.3 Coverage_run custom command" "$SCENARIOS_DIR/coverage-run/custom-command" "pass" "cm validate config"

# Test 9.4: Coverage_run auto-detect runner
setup_scenario "$SCENARIOS_DIR/coverage-run/auto-detect"
cat > check.toml << 'EOF'
[code.coverage_run]
enabled = true
min_threshold = 80
runner = "auto"
EOF
run_test "9.4 Coverage_run auto-detect" "$SCENARIOS_DIR/coverage-run/auto-detect" "pass" "cm validate config"

echo ""
echo "=========================================="
echo "10. PROCESS.REPO.RULESET - Updated Options"
echo "=========================================="

# Test 10.1: Ruleset with name
setup_scenario "$SCENARIOS_DIR/scan/ruleset-name"
cat > check.toml << 'EOF'
[process.repo]
enabled = true

[process.repo.ruleset]
name = "My Custom Ruleset"
branch = "main"
required_reviews = 2
EOF
run_test "10.1 Ruleset with name" "$SCENARIOS_DIR/scan/ruleset-name" "pass" "cm validate config"

# Test 10.2: Ruleset with enforcement
setup_scenario "$SCENARIOS_DIR/scan/ruleset-enforcement"
cat > check.toml << 'EOF'
[process.repo]
enabled = true

[process.repo.ruleset]
branch = "main"
enforcement = "evaluate"
EOF
run_test "10.2 Ruleset enforcement" "$SCENARIOS_DIR/scan/ruleset-enforcement" "pass" "cm validate config"

# Test 10.3: Ruleset with bypass_actors
setup_scenario "$SCENARIOS_DIR/scan/ruleset-bypass"
cat > check.toml << 'EOF'
[process.repo]
enabled = true

[process.repo.ruleset]
branch = "main"
required_reviews = 1

[[process.repo.ruleset.bypass_actors]]
actor_type = "OrganizationAdmin"
bypass_mode = "always"

[[process.repo.ruleset.bypass_actors]]
actor_type = "Integration"
actor_id = 12345
bypass_mode = "pull_request"
EOF
run_test "10.3 Ruleset bypass_actors" "$SCENARIOS_DIR/scan/ruleset-bypass" "pass" "cm validate config"

# Test 10.4: Ruleset invalid enforcement value
setup_scenario "$SCENARIOS_DIR/scan/ruleset-invalid-enforcement"
cat > check.toml << 'EOF'
[process.repo]
enabled = true

[process.repo.ruleset]
branch = "main"
enforcement = "invalid_value"
EOF
run_test "10.4 Ruleset invalid enforcement" "$SCENARIOS_DIR/scan/ruleset-invalid-enforcement" "fail" "cm validate config"

echo ""
echo "=========================================="
echo "11. EDGE CASES & VALIDATION"
echo "=========================================="

# Test 11.1: Empty commits types array
setup_scenario "$SCENARIOS_DIR/commits/empty-types"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
types = []
EOF
run_test "11.1 Empty commits types" "$SCENARIOS_DIR/commits/empty-types" "pass" "cm validate config"

# Test 11.2: Invalid runner value
setup_scenario "$SCENARIOS_DIR/coverage-run/invalid-runner"
cat > check.toml << 'EOF'
[code.coverage_run]
enabled = true
runner = "invalid_runner"
EOF
run_test "11.2 Invalid coverage_run runner" "$SCENARIOS_DIR/coverage-run/invalid-runner" "fail" "cm validate config"

# Test 11.3: Negative max_subject_length
setup_scenario "$SCENARIOS_DIR/commits/negative-length"
cat > check.toml << 'EOF'
[process.commits]
enabled = true
max_subject_length = -1
EOF
run_test "11.3 Negative max_subject_length" "$SCENARIOS_DIR/commits/negative-length" "fail" "cm validate config"

# Test 11.4: Invalid changeset bump type
setup_scenario "$SCENARIOS_DIR/changesets/invalid-bump"
cat > check.toml << 'EOF'
[process.changesets]
enabled = true
allowed_bump_types = ["patch", "breaking"]
EOF
run_test "11.4 Invalid changeset bump type" "$SCENARIOS_DIR/changesets/invalid-bump" "fail" "cm validate config"

# Test 11.5: Codeowners rule without required fields
setup_scenario "$SCENARIOS_DIR/codeowners/missing-fields"
cat > check.toml << 'EOF'
[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
EOF
run_test "11.5 Codeowners missing owners" "$SCENARIOS_DIR/codeowners/missing-fields" "fail" "cm validate config"

# Test 11.6: Docs invalid enforcement value
setup_scenario "$SCENARIOS_DIR/docs/invalid-enforcement"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
enforcement = "error"
EOF
run_test "11.6 Docs invalid enforcement" "$SCENARIOS_DIR/docs/invalid-enforcement" "fail" "cm validate config"

# Test 11.7: Coverage min_coverage out of range
setup_scenario "$SCENARIOS_DIR/docs/coverage-out-of-range"
cat > check.toml << 'EOF'
[process.docs]
enabled = true
min_coverage = 150
EOF
run_test "11.7 Docs coverage out of range" "$SCENARIOS_DIR/docs/coverage-out-of-range" "fail" "cm validate config"

# Test 11.8: Bypass actor invalid type
setup_scenario "$SCENARIOS_DIR/scan/bypass-invalid-type"
cat > check.toml << 'EOF'
[process.repo]
enabled = true

[process.repo.ruleset]
branch = "main"

[[process.repo.ruleset.bypass_actors]]
actor_type = "InvalidType"
EOF
run_test "11.8 Bypass actor invalid type" "$SCENARIOS_DIR/scan/bypass-invalid-type" "fail" "cm validate config"

echo ""
echo "=========================================="
echo "12. PREVIOUSLY OPEN BUGS - REGRESSION CHECK"
echo "=========================================="

# Test 12.1: Bug #14 - Custom ignore directories (forbidden_files)
setup_scenario "$SCENARIOS_DIR/regression/bug-14"
cat > check.toml << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
ignore = ["vendor/", "build/"]
EOF
mkdir -p vendor build src
echo "SECRET=abc" > vendor/.env
echo "SECRET=xyz" > build/.env
echo "test" > src/index.ts
echo "test" > file.txt && git add . && git commit -q -m "initial"
output=$(cm process check 2>&1) || true
if echo "$output" | grep -q "vendor/.env"; then
    echo -e "12.1 Bug #14 still present: ${RED}Custom ignore dirs not working${NC}"
    BUGS_FOUND+=("Bug #14 still present: Custom ignore directories not working")
else
    echo -e "12.1 Bug #14: ${GREEN}FIXED${NC} - Custom ignore dirs now work"
fi

# Test 12.2: Bug #17 - Ticket reference in commit body
setup_scenario "$SCENARIOS_DIR/regression/bug-17"
cat > check.toml << 'EOF'
[process.tickets]
enabled = true
pattern = "(PROJ|JIRA)-[0-9]+"
require_in_commits = true
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
cat > COMMIT_MSG << 'EOF'
Add new feature

This implements the feature described in PROJ-456.
EOF
output=$(cm process check-commit COMMIT_MSG 2>&1) || true
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    echo -e "12.2 Bug #17 still present: ${RED}Ticket in body not detected${NC}"
    BUGS_FOUND+=("Bug #17 still present: Ticket reference in commit body not detected")
else
    echo -e "12.2 Bug #17: ${GREEN}FIXED${NC} - Ticket in body now detected"
fi

# Test 12.3: Bug #18 - Coverage min_threshold ignored
setup_scenario "$SCENARIOS_DIR/regression/bug-18"
cat > check.toml << 'EOF'
[process.coverage]
enabled = true
min_threshold = 80
enforce_in = "config"
EOF
mkdir -p coverage
cat > coverage/lcov.info << 'EOF'
TN:
SF:src/index.ts
FN:1,main
FNDA:10,main
FNF:1
FNH:1
DA:1,10
DA:2,10
DA:3,10
DA:4,10
DA:5,10
DA:6,10
DA:7,10
DA:8,0
DA:9,0
DA:10,0
LF:10
LH:7
end_of_record
EOF
echo "test" > file.txt && git add . && git commit -q -m "initial"
output=$(cm process check 2>&1) || true
if echo "$output" | grep -q "No coverage threshold config found"; then
    echo -e "12.3 Bug #18 still present: ${RED}min_threshold ignored${NC}"
    BUGS_FOUND+=("Bug #18 still present: Coverage min_threshold from check.toml ignored")
else
    echo -e "12.3 Bug #18: ${GREEN}FIXED${NC} - min_threshold now works"
fi

# Test 12.4: Bug #25 - Empty CODEOWNERS not validated
setup_scenario "$SCENARIOS_DIR/regression/bug-25"
cat > check.toml << 'EOF'
[process.repo]
enabled = true
require_codeowners = true
EOF
mkdir -p .github
touch .github/CODEOWNERS
git remote add origin https://github.com/test/test.git 2>/dev/null || true
echo "test" > file.txt && git add . && git commit -q -m "initial"
output=$(cm process check 2>&1) || true
if echo "$output" | grep -qi "empty"; then
    echo -e "12.4 Bug #25: ${GREEN}FIXED${NC} - Empty CODEOWNERS now validated"
else
    echo -e "12.4 Bug #25 still present: ${YELLOW}Empty CODEOWNERS not validated${NC}"
    BUGS_FOUND+=("Bug #25 still present: Empty CODEOWNERS file not validated")
fi

echo ""
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ ${#BUGS_FOUND[@]} -gt 0 ]]; then
    echo "Bugs Found/Still Present:"
    for bug in "${BUGS_FOUND[@]}"; do
        echo -e "  - ${RED}$bug${NC}"
    done
fi

# Write results to file
cat > "$RESULTS_FILE" << EOF
check-my-toolkit v2.0.0 E2E Test Results
========================================
Date: $(date)
Version: $(cm --version)

Tests Passed: $PASSED
Tests Failed: $FAILED

Bugs Found/Still Present:
$(for bug in "${BUGS_FOUND[@]}"; do echo "- $bug"; done)

EOF

echo ""
echo "Results written to: $RESULTS_FILE"
