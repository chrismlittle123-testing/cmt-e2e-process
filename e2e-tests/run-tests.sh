#!/bin/bash

# E2E Test Suite for check-my-toolkit v1.3.0 - v1.4.0 features
# Tests: cm validate tier and [process.forbidden_files]

# set -e  # Don't exit on first failure

BASE_DIR="/Users/christopherlittle/Documents/GitHub/personal/cmt-e2e-process/e2e-tests"
RESULTS_FILE="$BASE_DIR/test-results.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

    echo -n "Testing: $test_name... "

    cd "$test_dir"
    output=$(eval "$command" 2>&1) || true
    actual_exit=$?

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        if [ -n "$expected_output" ]; then
            if echo "$output" | grep -q "$expected_output"; then
                echo -e "${GREEN}PASS${NC}"
                ((PASSED++))
            else
                echo -e "${RED}FAIL${NC} (output mismatch)"
                echo "  Expected: $expected_output"
                echo "  Got: $output"
                ((FAILED++))
                BUGS_FOUND+=("$test_name: Output mismatch - Expected '$expected_output'")
            fi
        else
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (exit code $actual_exit, expected $expected_exit)"
        echo "  Output: $output"
        ((FAILED++))
        BUGS_FOUND+=("$test_name: Exit code $actual_exit, expected $expected_exit - $output")
    fi
}

# Cleanup and create test directories
cleanup() {
    rm -rf "$BASE_DIR/scenarios"
    mkdir -p "$BASE_DIR/scenarios"
}

# ============================================================================
# VALIDATE TIER TESTS (1.3.0 feature)
# ============================================================================

setup_tier_tests() {
    echo ""
    echo "============================================"
    echo "VALIDATE TIER TESTS (v1.3.0)"
    echo "============================================"

    # Test 1: Production tier with production ruleset - should pass
    local test_dir="$BASE_DIR/scenarios/tier-1-prod-match"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production", "typescript"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 2: Production tier without production ruleset - should fail
    local test_dir="$BASE_DIR/scenarios/tier-2-prod-mismatch"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal", "typescript"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 3: Internal tier with internal ruleset - should pass
    local test_dir="$BASE_DIR/scenarios/tier-3-internal-match"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: internal
EOF

    # Test 4: Prototype tier with prototype ruleset - should pass
    local test_dir="$BASE_DIR/scenarios/tier-4-proto-match"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-prototype"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: prototype
EOF

    # Test 5: Missing repo-metadata.yaml - should default to internal
    local test_dir="$BASE_DIR/scenarios/tier-5-no-metadata"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF

    # Test 6: No extends section - should pass (no constraint)
    local test_dir="$BASE_DIR/scenarios/tier-6-no-extends"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[code.linting.eslint]
enabled = true
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 7: Invalid tier value - should default to internal
    local test_dir="$BASE_DIR/scenarios/tier-7-invalid-tier"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: invalid-tier-value
EOF

    # Test 8: Empty rulesets array - should pass
    local test_dir="$BASE_DIR/scenarios/tier-8-empty-rulesets"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = []
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 9: Multiple matching rulesets - should pass
    local test_dir="$BASE_DIR/scenarios/tier-9-multi-match"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production", "security-production", "typescript"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 10: JSON output format
    local test_dir="$BASE_DIR/scenarios/tier-10-json-format"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 11: No check.toml - should fail
    local test_dir="$BASE_DIR/scenarios/tier-11-no-config"
    mkdir -p "$test_dir"

    # Test 12: Malformed YAML in repo-metadata.yaml
    local test_dir="$BASE_DIR/scenarios/tier-12-bad-yaml"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: internal
  bad: yaml: here
EOF

    # Test 13: Empty repo-metadata.yaml
    local test_dir="$BASE_DIR/scenarios/tier-13-empty-metadata"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-internal"]
EOF
    touch "$test_dir/repo-metadata.yaml"

    # Test 14: Tier with different casing
    local test_dir="$BASE_DIR/scenarios/tier-14-case-sensitive"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-Production"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test 15: Whitespace in tier value
    local test_dir="$BASE_DIR/scenarios/tier-15-whitespace"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: " production "
EOF
}

run_tier_tests() {
    # Test 1: Production tier with production ruleset - should pass
    run_test "tier-1: prod tier + prod ruleset" \
        "$BASE_DIR/scenarios/tier-1-prod-match" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 2: Production tier without production ruleset - should fail
    run_test "tier-2: prod tier + internal ruleset" \
        "$BASE_DIR/scenarios/tier-2-prod-mismatch" \
        2 \
        "cm validate tier" \
        "failed"

    # Test 3: Internal tier with internal ruleset - should pass
    run_test "tier-3: internal tier + internal ruleset" \
        "$BASE_DIR/scenarios/tier-3-internal-match" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 4: Prototype tier with prototype ruleset - should pass
    run_test "tier-4: prototype tier + prototype ruleset" \
        "$BASE_DIR/scenarios/tier-4-proto-match" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 5: Missing repo-metadata.yaml - should default to internal and pass
    run_test "tier-5: no metadata defaults to internal" \
        "$BASE_DIR/scenarios/tier-5-no-metadata" \
        0 \
        "cm validate tier" \
        "default"

    # Test 6: No extends section - should pass
    run_test "tier-6: no extends = no constraint" \
        "$BASE_DIR/scenarios/tier-6-no-extends" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 7: Invalid tier value - should default to internal
    run_test "tier-7: invalid tier defaults to internal" \
        "$BASE_DIR/scenarios/tier-7-invalid-tier" \
        0 \
        "cm validate tier" \
        "default"

    # Test 8: Empty rulesets array - should pass
    run_test "tier-8: empty rulesets = no constraint" \
        "$BASE_DIR/scenarios/tier-8-empty-rulesets" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 9: Multiple matching rulesets - should pass
    run_test "tier-9: multiple matching rulesets" \
        "$BASE_DIR/scenarios/tier-9-multi-match" \
        0 \
        "cm validate tier" \
        "passed"

    # Test 10: JSON output format
    run_test "tier-10: json output format" \
        "$BASE_DIR/scenarios/tier-10-json-format" \
        0 \
        "cm validate tier --format json" \
        '"valid": true'

    # Test 11: No check.toml - should fail
    run_test "tier-11: no check.toml" \
        "$BASE_DIR/scenarios/tier-11-no-config" \
        2 \
        "cm validate tier" \
        "No check.toml found"

    # Test 12: Malformed YAML - should handle gracefully
    run_test "tier-12: malformed yaml" \
        "$BASE_DIR/scenarios/tier-12-bad-yaml" \
        0 \
        "cm validate tier" \
        ""

    # Test 13: Empty repo-metadata.yaml - should default to internal
    run_test "tier-13: empty metadata" \
        "$BASE_DIR/scenarios/tier-13-empty-metadata" \
        0 \
        "cm validate tier" \
        "default"

    # Test 14: Case sensitivity in rulesets
    run_test "tier-14: case sensitivity" \
        "$BASE_DIR/scenarios/tier-14-case-sensitive" \
        2 \
        "cm validate tier" \
        "failed"

    # Test 15: Whitespace in tier value
    run_test "tier-15: whitespace in tier" \
        "$BASE_DIR/scenarios/tier-15-whitespace" \
        0 \
        "cm validate tier" \
        ""
}

# ============================================================================
# FORBIDDEN FILES TESTS (1.4.0 feature)
# ============================================================================

setup_forbidden_files_tests() {
    echo ""
    echo "============================================"
    echo "FORBIDDEN FILES TESTS (v1.4.0)"
    echo "============================================"

    # Test 1: Basic .env file detection - should fail
    local test_dir="$BASE_DIR/scenarios/ff-1-basic-env"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 2: No forbidden files - should pass
    local test_dir="$BASE_DIR/scenarios/ff-2-no-forbidden"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF

    # Test 3: Glob pattern matching
    local test_dir="$BASE_DIR/scenarios/ff-3-glob-pattern"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["*.env", "**/*.secret"]
EOF
    echo "test" > "$test_dir/test.env"
    mkdir -p "$test_dir/nested"
    echo "secret" > "$test_dir/nested/data.secret"

    # Test 4: Custom message
    local test_dir="$BASE_DIR/scenarios/ff-4-custom-message"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
message = "Use secrets manager instead"
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 5: Disabled check
    local test_dir="$BASE_DIR/scenarios/ff-5-disabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = false
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 6: Empty files array
    local test_dir="$BASE_DIR/scenarios/ff-6-empty-files"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = []
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 7: Multiple forbidden patterns
    local test_dir="$BASE_DIR/scenarios/ff-7-multi-patterns"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env", ".env.local", "credentials.json", "*.pem"]
EOF
    echo "SECRET=value" > "$test_dir/.env"
    echo "LOCAL=value" > "$test_dir/.env.local"

    # Test 8: Hidden directories
    local test_dir="$BASE_DIR/scenarios/ff-8-hidden-dirs"
    mkdir -p "$test_dir/.hidden"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/.hidden/.env"

    # Test 9: Nested deep files
    local test_dir="$BASE_DIR/scenarios/ff-9-deep-nested"
    mkdir -p "$test_dir/a/b/c/d"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/a/b/c/d/.env"

    # Test 10: JSON output format
    local test_dir="$BASE_DIR/scenarios/ff-10-json-format"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 11: Pattern with special characters
    local test_dir="$BASE_DIR/scenarios/ff-11-special-chars"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["file[1].txt"]
EOF
    touch "$test_dir/file[1].txt"

    # Test 12: .env.example should not match .env pattern
    local test_dir="$BASE_DIR/scenarios/ff-12-env-example"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "EXAMPLE=value" > "$test_dir/.env.example"

    # Test 13: Symlink to forbidden file
    local test_dir="$BASE_DIR/scenarios/ff-13-symlink"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/real-env"
    ln -sf "$test_dir/real-env" "$test_dir/.env"

    # Test 14: Files with unicode names
    local test_dir="$BASE_DIR/scenarios/ff-14-unicode"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["секрет.txt"]
EOF
    touch "$test_dir/секрет.txt"

    # Test 15: Very long file path
    local test_dir="$BASE_DIR/scenarios/ff-15-long-path"
    mkdir -p "$test_dir/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/.env"

    # Test 16: Forbidden file config without enabled flag
    local test_dir="$BASE_DIR/scenarios/ff-16-no-enabled"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"

    # Test 17: Combining with other process checks
    local test_dir="$BASE_DIR/scenarios/ff-17-combined"
    mkdir -p "$test_dir/.husky"
    cat > "$test_dir/check.toml" << 'EOF'
[process.hooks]
enabled = true
require_husky = true

[process.forbidden_files]
enabled = true
files = [".env"]
EOF
    echo "SECRET=value" > "$test_dir/.env"
    touch "$test_dir/.husky/pre-commit"

    # Test 18: Recursive glob with specific extension
    local test_dir="$BASE_DIR/scenarios/ff-18-recursive-ext"
    mkdir -p "$test_dir/config"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/*.key"]
EOF
    touch "$test_dir/config/server.key"
    touch "$test_dir/public.key"

    # Test 19: Edge case - forbidden file is directory
    local test_dir="$BASE_DIR/scenarios/ff-19-dir-match"
    mkdir -p "$test_dir/.env"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
EOF

    # Test 20: Case sensitivity in patterns
    local test_dir="$BASE_DIR/scenarios/ff-20-case-sensitive"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".ENV"]
EOF
    echo "SECRET=value" > "$test_dir/.env"
}

run_forbidden_files_tests() {
    # Test 1: Basic .env file detection
    run_test "ff-1: detect .env file" \
        "$BASE_DIR/scenarios/ff-1-basic-env" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 2: No forbidden files - should pass
    run_test "ff-2: no forbidden files" \
        "$BASE_DIR/scenarios/ff-2-no-forbidden" \
        0 \
        "cm process check" \
        ""

    # Test 3: Glob pattern matching
    run_test "ff-3: glob pattern matching" \
        "$BASE_DIR/scenarios/ff-3-glob-pattern" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 4: Custom message
    run_test "ff-4: custom error message" \
        "$BASE_DIR/scenarios/ff-4-custom-message" \
        1 \
        "cm process check" \
        "secrets manager"

    # Test 5: Disabled check - should pass
    run_test "ff-5: disabled check passes" \
        "$BASE_DIR/scenarios/ff-5-disabled" \
        0 \
        "cm process check" \
        ""

    # Test 6: Empty files array - should pass
    run_test "ff-6: empty files array" \
        "$BASE_DIR/scenarios/ff-6-empty-files" \
        0 \
        "cm process check" \
        ""

    # Test 7: Multiple forbidden patterns
    run_test "ff-7: multiple patterns" \
        "$BASE_DIR/scenarios/ff-7-multi-patterns" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 8: Hidden directories
    run_test "ff-8: hidden directory files" \
        "$BASE_DIR/scenarios/ff-8-hidden-dirs" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 9: Nested deep files
    run_test "ff-9: deeply nested files" \
        "$BASE_DIR/scenarios/ff-9-deep-nested" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 10: JSON output format
    run_test "ff-10: json output format" \
        "$BASE_DIR/scenarios/ff-10-json-format" \
        1 \
        "cm process check --format json" \
        "forbidden-files"

    # Test 11: Pattern with special characters
    run_test "ff-11: special chars in pattern" \
        "$BASE_DIR/scenarios/ff-11-special-chars" \
        1 \
        "cm process check" \
        ""

    # Test 12: .env.example should not match .env
    run_test "ff-12: .env.example not matched" \
        "$BASE_DIR/scenarios/ff-12-env-example" \
        0 \
        "cm process check" \
        ""

    # Test 13: Symlink to forbidden file
    run_test "ff-13: symlink detection" \
        "$BASE_DIR/scenarios/ff-13-symlink" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 14: Unicode filenames
    run_test "ff-14: unicode filename" \
        "$BASE_DIR/scenarios/ff-14-unicode" \
        1 \
        "cm process check" \
        ""

    # Test 15: Long path
    run_test "ff-15: long path" \
        "$BASE_DIR/scenarios/ff-15-long-path" \
        1 \
        "cm process check" \
        "Forbidden file"

    # Test 16: Missing enabled flag (should default to false)
    run_test "ff-16: missing enabled flag" \
        "$BASE_DIR/scenarios/ff-16-no-enabled" \
        0 \
        "cm process check" \
        ""

    # Test 17: Combined with other checks
    run_test "ff-17: combined checks" \
        "$BASE_DIR/scenarios/ff-17-combined" \
        1 \
        "cm process check" \
        ""

    # Test 18: Recursive extension glob
    run_test "ff-18: recursive extension" \
        "$BASE_DIR/scenarios/ff-18-recursive-ext" \
        1 \
        "cm process check" \
        ""

    # Test 19: Directory matching (should not match directories)
    run_test "ff-19: directory not matched" \
        "$BASE_DIR/scenarios/ff-19-dir-match" \
        0 \
        "cm process check" \
        ""

    # Test 20: Case sensitivity
    run_test "ff-20: case sensitivity" \
        "$BASE_DIR/scenarios/ff-20-case-sensitive" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# ADDITIONAL EDGE CASE TESTS
# ============================================================================

setup_edge_case_tests() {
    echo ""
    echo "============================================"
    echo "EDGE CASE TESTS"
    echo "============================================"

    # Test: Invalid TOML syntax
    local test_dir="$BASE_DIR/scenarios/edge-1-invalid-toml"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files
enabled = true
EOF

    # Test: Extra fields in config
    local test_dir="$BASE_DIR/scenarios/edge-2-extra-fields"
    mkdir -p "$test_dir"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = [".env"]
unknown_field = "test"
EOF

    # Test: Tier validation with custom config path
    local test_dir="$BASE_DIR/scenarios/edge-3-custom-config"
    mkdir -p "$test_dir/custom"
    cat > "$test_dir/custom/my-config.toml" << 'EOF'
[extends]
registry = "github:example/standards"
rulesets = ["base-production"]
EOF
    cat > "$test_dir/repo-metadata.yaml" << 'EOF'
tier: production
EOF

    # Test: Very large number of forbidden patterns
    local test_dir="$BASE_DIR/scenarios/edge-4-many-patterns"
    mkdir -p "$test_dir"
    patterns=""
    for i in {1..100}; do
        patterns="$patterns\"pattern$i.txt\", "
    done
    patterns="${patterns%, }"
    cat > "$test_dir/check.toml" << EOF
[process.forbidden_files]
enabled = true
files = [$patterns]
EOF

    # Test: Forbidden file in node_modules (should be ignored)
    local test_dir="$BASE_DIR/scenarios/edge-5-node-modules"
    mkdir -p "$test_dir/node_modules/some-package"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/node_modules/some-package/.env"

    # Test: Forbidden file in .git (should be ignored)
    local test_dir="$BASE_DIR/scenarios/edge-6-git-dir"
    mkdir -p "$test_dir/.git/hooks"
    cat > "$test_dir/check.toml" << 'EOF'
[process.forbidden_files]
enabled = true
files = ["**/.env"]
EOF
    echo "SECRET=value" > "$test_dir/.git/hooks/.env"
}

run_edge_case_tests() {
    # Test: Invalid TOML syntax
    run_test "edge-1: invalid TOML" \
        "$BASE_DIR/scenarios/edge-1-invalid-toml" \
        2 \
        "cm process check" \
        ""

    # Test: Extra fields in config (strict mode)
    run_test "edge-2: extra config fields" \
        "$BASE_DIR/scenarios/edge-2-extra-fields" \
        2 \
        "cm process check" \
        ""

    # Test: Custom config path for tier validation
    run_test "edge-3: custom config path" \
        "$BASE_DIR/scenarios/edge-3-custom-config" \
        0 \
        "cm validate tier --config custom/my-config.toml" \
        "passed"

    # Test: Many patterns
    run_test "edge-4: many patterns" \
        "$BASE_DIR/scenarios/edge-4-many-patterns" \
        0 \
        "cm process check" \
        ""

    # Test: Ignored node_modules
    run_test "edge-5: node_modules ignored" \
        "$BASE_DIR/scenarios/edge-5-node-modules" \
        0 \
        "cm process check" \
        ""

    # Test: Ignored .git directory
    run_test "edge-6: .git dir ignored" \
        "$BASE_DIR/scenarios/edge-6-git-dir" \
        0 \
        "cm process check" \
        ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "check-my-toolkit E2E Test Suite"
    echo "Version: 1.3.0 - 1.4.0 features"
    echo "=========================================="

    cleanup

    setup_tier_tests
    run_tier_tests

    setup_forbidden_files_tests
    run_forbidden_files_tests

    setup_edge_case_tests
    run_edge_case_tests

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

    exit $FAILED
}

main "$@"
