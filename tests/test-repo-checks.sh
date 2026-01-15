#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASS_COUNT++))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAIL_COUNT++))
}

info() {
  echo -e "${YELLOW}→${NC} $1"
}

echo "========================================"
echo "Testing cm process repo checks"
echo "========================================"
echo ""

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Test 1: Branch protection enabled (cmt-protected)
info "Test 1: Branch protection enabled on cmt-protected"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-protected test-protected --quiet
cd test-protected

if cm process check 2>&1 | grep -q "passed\|✓"; then
  pass "cmt-protected - branch protection check passed"
else
  fail "cmt-protected - expected branch protection check to pass"
fi

# Test 2: Branch protection disabled (cmt-unprotected)  
info "Test 2: Branch protection disabled on cmt-unprotected"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-unprotected test-unprotected --quiet
cd test-unprotected

if cm process check 2>&1 | grep -qE "failed|violation|✗|No branch protection"; then
  pass "cmt-unprotected - branch protection check correctly failed"
else
  fail "cmt-unprotected - expected branch protection check to fail"
fi

# Test 3: CODEOWNERS exists (cmt-codeowners)
info "Test 3: CODEOWNERS file exists on cmt-codeowners"
cd "$WORK_DIR"
gh repo clone chrismlittle123-testing/cmt-codeowners test-codeowners --quiet
cd test-codeowners

if cm process check 2>&1 | grep -q "passed\|✓"; then
  pass "cmt-codeowners - CODEOWNERS check passed"
else
  fail "cmt-codeowners - expected CODEOWNERS check to pass"
fi

# Test 4: CODEOWNERS missing (cmt-unprotected has no CODEOWNERS)
info "Test 4: CODEOWNERS missing on cmt-unprotected"
cd "$WORK_DIR/test-unprotected"

# Add codeowners requirement to check.toml
cat >> check.toml << 'EOF'
require_codeowners = true
EOF

if cm process check 2>&1 | grep -qE "failed|violation|✗|CODEOWNERS"; then
  pass "cmt-unprotected - CODEOWNERS check correctly failed"
else
  fail "cmt-unprotected - expected CODEOWNERS check to fail"
fi

echo ""
echo "========================================"
echo "Repo Check Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

exit $FAIL_COUNT
