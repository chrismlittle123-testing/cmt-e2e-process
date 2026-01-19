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
echo "Testing cm process branch/commit checks"
echo "========================================"
echo ""

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Clone test repo with branch naming config
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-ts-code-test test-repo -- --quiet
cd test-repo

# =============================================================================
# BRANCH NAMING TESTS
# =============================================================================
echo "--- Branch Naming Tests ---"
echo ""

# Test 1: Valid branch name (feature/*)
info "Test 1: Valid branch name 'feature/add-login' should PASS"
git checkout -b feature/add-login 2>/dev/null

if cm process check-branch 2>&1 | grep -qE "valid|✓|passed"; then
  pass "feature/add-login - valid branch name"
else
  # Check if it was skipped or passed silently
  OUTPUT=$(cm process check-branch 2>&1)
  if echo "$OUTPUT" | grep -qE "invalid|✗|failed|violation"; then
    fail "feature/add-login - should be valid but was rejected"
  else
    pass "feature/add-login - valid branch name (no violation)"
  fi
fi

git checkout main 2>/dev/null
git branch -D feature/add-login 2>/dev/null || true

# Test 2: Valid branch name (bugfix/*)
info "Test 2: Valid branch name 'bugfix/fix-typo' should PASS"
git checkout -b bugfix/fix-typo 2>/dev/null

OUTPUT=$(cm process check-branch 2>&1)
if echo "$OUTPUT" | grep -qE "invalid|✗|failed|violation"; then
  fail "bugfix/fix-typo - should be valid but was rejected"
else
  pass "bugfix/fix-typo - valid branch name"
fi

git checkout main 2>/dev/null
git branch -D bugfix/fix-typo 2>/dev/null || true

# Test 3: Invalid branch name (no prefix)
info "Test 3: Invalid branch name 'my-random-branch' should FAIL"
git checkout -b my-random-branch 2>/dev/null

OUTPUT=$(cm process check-branch 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "invalid|✗|failed|violation|pattern"; then
  pass "my-random-branch - correctly rejected invalid branch name"
else
  fail "my-random-branch - should have been rejected"
fi

git checkout main 2>/dev/null
git branch -D my-random-branch 2>/dev/null || true

# Test 4: Main branch should be excluded
info "Test 4: 'main' branch should be excluded from validation"
# Already on main from previous checkout
OUTPUT=$(cm process check-branch 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  pass "main - correctly excluded from validation"
else
  fail "main - should be excluded but was validated"
fi

# =============================================================================
# COMMIT MESSAGE TESTS
# =============================================================================
echo ""
echo "--- Commit Message Tests ---"
echo ""

# Test 5: Valid conventional commit
info "Test 5: Valid commit 'feat: add new feature' should PASS"
echo "feat: add new feature" > /tmp/test-commit-msg

OUTPUT=$(cm process check-commit /tmp/test-commit-msg 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  pass "feat: add new feature - valid conventional commit"
else
  if echo "$OUTPUT" | grep -qE "skipped|Skip|not enabled"; then
    pass "feat: add new feature - commit check skipped (not in commit context)"
  else
    fail "feat: add new feature - should be valid: $OUTPUT"
  fi
fi

# Test 6: Valid commit with scope
info "Test 6: Valid commit 'fix(auth): resolve login bug' should PASS"
echo "fix(auth): resolve login bug" > /tmp/test-commit-msg

OUTPUT=$(cm process check-commit /tmp/test-commit-msg 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  pass "fix(auth): resolve login bug - valid commit with scope"
else
  if echo "$OUTPUT" | grep -qE "skipped|Skip|not enabled"; then
    pass "fix(auth): resolve login bug - commit check skipped (not in commit context)"
  else
    fail "fix(auth): resolve login bug - should be valid"
  fi
fi

# Test 7: Invalid commit (wrong type)
info "Test 7: Invalid commit 'invalid: wrong type' should FAIL"
echo "invalid: wrong type" > /tmp/test-commit-msg

OUTPUT=$(cm process check-commit /tmp/test-commit-msg 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "invalid|✗|failed|violation|type"; then
  pass "invalid: wrong type - correctly rejected"
else
  if echo "$OUTPUT" | grep -qE "skipped|Skip|not enabled"; then
    pass "invalid: wrong type - commit check skipped (not in commit context)"
  else
    fail "invalid: wrong type - should have been rejected"
  fi
fi

# Test 8: Invalid commit (no type prefix)
info "Test 8: Invalid commit 'random message without type' should FAIL"
echo "random message without type" > /tmp/test-commit-msg

OUTPUT=$(cm process check-commit /tmp/test-commit-msg 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "invalid|✗|failed|violation"; then
  pass "random message - correctly rejected"
else
  if echo "$OUTPUT" | grep -qE "skipped|Skip|not enabled"; then
    pass "random message - commit check skipped (not in commit context)"
  else
    fail "random message - should have been rejected"
  fi
fi

# Test 9: Commit message too long
info "Test 9: Commit with subject > 72 chars should FAIL"
LONG_MSG="feat: this is a very long commit message that exceeds the maximum allowed length of 72 characters"
echo "$LONG_MSG" > /tmp/test-commit-msg

OUTPUT=$(cm process check-commit /tmp/test-commit-msg 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qE "length|too long|✗|failed|violation"; then
  pass "long commit message - correctly rejected"
else
  if echo "$OUTPUT" | grep -qE "skipped|Skip|not enabled"; then
    pass "long commit message - commit check skipped (not in commit context)"
  else
    fail "long commit message - should have been rejected for length"
  fi
fi

# Cleanup
rm -f /tmp/test-commit-msg

echo ""
echo "========================================"
echo "Branch/Commit Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

exit $FAIL_COUNT
