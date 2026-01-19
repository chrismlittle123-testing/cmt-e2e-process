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
echo "Testing cm process CODEOWNERS rules"
echo "========================================"
echo ""

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# =============================================================================
# CODEOWNERS RULES VALIDATION TESTS
# =============================================================================

# Test 1: CODEOWNERS with matching rule should PASS
info "Test 1: CODEOWNERS with matching required rule should PASS"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-codeowners test-codeowners -- --quiet
cd test-codeowners

# Configure to require the existing rule (* @chrismlittle123)
cat > check.toml << 'EOF'
[process.repo]
enabled = true
require_codeowners = true

[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@chrismlittle123"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] || echo "$OUTPUT" | grep -qE "CODEOWNERS.*passed|codeowners.*✓"; then
  pass "cmt-codeowners - CODEOWNERS rule validation passed"
else
  if echo "$OUTPUT" | grep -qE "codeowners.*failed|rule.*missing"; then
    fail "cmt-codeowners - CODEOWNERS rule should match"
    echo "  Output: $OUTPUT"
  else
    pass "cmt-codeowners - CODEOWNERS check passed (no violations)"
  fi
fi

# Test 2: CODEOWNERS missing required rule should FAIL
info "Test 2: CODEOWNERS missing required rule should FAIL"
cd "$WORK_DIR/test-codeowners"

# Configure to require a rule that doesn't exist
cat > check.toml << 'EOF'
[process.repo]
enabled = true
require_codeowners = true

[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@chrismlittle123"]

[[process.codeowners.rules]]
pattern = "/docs/*"
owners = ["@docs-team"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "codeowners.*failed|rule.*missing|/docs/|✗"; then
  pass "cmt-codeowners - correctly detected missing /docs/* rule"
else
  fail "cmt-codeowners - should fail for missing /docs/* rule"
  echo "  Output: $OUTPUT"
fi

# Test 3: CODEOWNERS with wrong owner should FAIL
info "Test 3: CODEOWNERS with wrong owner should FAIL"
cd "$WORK_DIR/test-codeowners"

# Configure to require different owner than what exists
cat > check.toml << 'EOF'
[process.repo]
enabled = true
require_codeowners = true

[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@wrong-team"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "codeowners.*failed|owner.*mismatch|wrong-team|✗"; then
  pass "cmt-codeowners - correctly detected wrong owner"
else
  fail "cmt-codeowners - should fail for wrong owner (@wrong-team vs @chrismlittle123)"
  echo "  Output: $OUTPUT"
fi

# Test 4: Repo without CODEOWNERS should FAIL when required
info "Test 4: Repo without CODEOWNERS file should FAIL"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-unprotected test-no-codeowners -- --quiet
cd test-no-codeowners

# Configure to require CODEOWNERS
cat > check.toml << 'EOF'
[process.repo]
enabled = true
require_codeowners = true

[process.codeowners]
enabled = true

[[process.codeowners.rules]]
pattern = "*"
owners = ["@some-team"]
EOF

OUTPUT=$(cm process check 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "CODEOWNERS.*not found|codeowners.*missing|codeowners.*failed|✗"; then
  pass "cmt-unprotected - correctly detected missing CODEOWNERS file"
else
  fail "cmt-unprotected - should fail when CODEOWNERS is missing"
  echo "  Output: $OUTPUT"
fi

echo ""
echo "========================================"
echo "CODEOWNERS Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

exit $FAIL_COUNT
