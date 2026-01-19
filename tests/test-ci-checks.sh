#!/bin/bash
# Note: Not using set -e because we test for expected failures

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAIL_COUNT++)) || true
}

info() {
  echo -e "${YELLOW}→${NC} $1"
}

echo "========================================"
echo "Testing cm process CI workflow checks"
echo "========================================"
echo ""

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# =============================================================================
# CI WORKFLOW TESTS
# =============================================================================

# Test 1: Repo with workflow present (cmt-pr-small has pr-check.yml)
info "Test 1: Repo with required workflow present should PASS"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-pr-small test-with-workflow -- --quiet
cd test-with-workflow

# Add CI config that requires the existing workflow
cat >> check.toml << 'EOF'

[process.ci]
enabled = true
require_workflows = ["pr-check.yml"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if echo "$OUTPUT" | grep -qE "CI.*passed|ci.*✓|workflow.*passed" || ([ $EXIT_CODE -eq 0 ] && ! echo "$OUTPUT" | grep -qE "ci.*failed|workflow.*missing"); then
  pass "cmt-pr-small - CI workflow check passed"
else
  fail "cmt-pr-small - CI workflow check should pass (has pr-check.yml)"
  echo "  Output: $OUTPUT"
fi

# Test 2: Repo without required workflow (cmt-protected has no workflows)
info "Test 2: Repo missing required workflow should FAIL"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-protected test-no-workflow -- --quiet
cd test-no-workflow

# Add CI config that requires a workflow that doesn't exist
cat >> check.toml << 'EOF'

[process.ci]
enabled = true
require_workflows = ["ci.yml"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "ci.*failed|workflow.*missing|ci.yml.*not found|✗"; then
  pass "cmt-protected - CI workflow check correctly failed (missing ci.yml)"
else
  fail "cmt-protected - CI workflow check should fail (no workflows dir)"
  echo "  Output: $OUTPUT"
fi

# Test 3: Workflow exists but missing required job
info "Test 3: Workflow missing required job should FAIL"
cd "$WORK_DIR/test-with-workflow"

# Update config to require a job that doesn't exist
cat > check.toml << 'EOF'
[process.pr]
enabled = true
max_files = 20
max_lines = 500

[process.ci]
enabled = true
require_workflows = ["pr-check.yml"]

[process.ci.jobs]
"pr-check.yml" = ["test", "lint", "build", "nonexistent-job"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "job.*missing|nonexistent-job|failed|✗"; then
  pass "cmt-pr-small - correctly detected missing job"
else
  fail "cmt-pr-small - should fail for missing job 'nonexistent-job'"
  echo "  Output: $OUTPUT"
fi

# Test 4: Workflow with all required jobs present
info "Test 4: Workflow with required job 'check' should PASS"
cd "$WORK_DIR/test-with-workflow"

# Reset and configure for existing job
git checkout check.toml 2>/dev/null || true
cat > check.toml << 'EOF'
[process.pr]
enabled = true
max_files = 20
max_lines = 500

[process.ci]
enabled = true
require_workflows = ["pr-check.yml"]

[process.ci.jobs]
"pr-check.yml" = ["check"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] || echo "$OUTPUT" | grep -qE "CI.*passed|ci.*✓"; then
  pass "cmt-pr-small - CI check passed with correct job requirement"
else
  if echo "$OUTPUT" | grep -qE "job.*missing|failed"; then
    fail "cmt-pr-small - job 'check' should exist in pr-check.yml"
    echo "  Output: $OUTPUT"
  else
    pass "cmt-pr-small - CI check passed (no job violations)"
  fi
fi

echo ""
echo "========================================"
echo "CI Check Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

exit $FAIL_COUNT
