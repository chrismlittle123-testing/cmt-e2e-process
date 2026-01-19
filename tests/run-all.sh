#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  check-my-toolkit E2E Tests                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v gh &> /dev/null; then
  echo "Error: gh CLI not found. Please install GitHub CLI."
  exit 1
fi

if ! command -v cm &> /dev/null; then
  echo "Error: cm (check-my-toolkit) not found. Installing..."
  npm install -g check-my-toolkit
fi

if ! gh auth status &> /dev/null; then
  echo "Error: gh CLI not authenticated. Run 'gh auth login' first."
  exit 1
fi

echo "Prerequisites OK"
echo ""

TOTAL_FAIL=0

# =============================================================================
# PROCESS DOMAIN TESTS
# =============================================================================

# Run repo checks
echo "────────────────────────────────────────"
echo "Running Repo Checks Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-repo-checks.sh"; then
  echo ""
else
  REPO_FAIL=$?
  ((TOTAL_FAIL += REPO_FAIL)) || true
fi

echo ""

# Run PR checks
echo "────────────────────────────────────────"
echo "Running PR Checks Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-pr-checks.sh"; then
  echo ""
else
  PR_FAIL=$?
  ((TOTAL_FAIL += PR_FAIL)) || true
fi

echo ""

# Run branch/commit checks
echo "────────────────────────────────────────"
echo "Running Branch/Commit Checks Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-branch-commit-checks.sh"; then
  echo ""
else
  BC_FAIL=$?
  ((TOTAL_FAIL += BC_FAIL)) || true
fi

echo ""

# Run CI workflow checks
echo "────────────────────────────────────────"
echo "Running CI Workflow Checks Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-ci-checks.sh"; then
  echo ""
else
  CI_FAIL=$?
  ((TOTAL_FAIL += CI_FAIL)) || true
fi

echo ""

# Run CODEOWNERS rules checks
echo "────────────────────────────────────────"
echo "Running CODEOWNERS Rules Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-codeowners-rules.sh"; then
  echo ""
else
  CO_FAIL=$?
  ((TOTAL_FAIL += CO_FAIL)) || true
fi

echo ""

# =============================================================================
# CODE DOMAIN TESTS
# =============================================================================

# Run code checks (requires npm install, takes longer)
echo "────────────────────────────────────────"
echo "Running CODE Domain Tests..."
echo "────────────────────────────────────────"
if "$SCRIPT_DIR/test-code-checks.sh"; then
  echo ""
else
  CODE_FAIL=$?
  ((TOTAL_FAIL += CODE_FAIL)) || true
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Final Results                                             ║"
echo "╚════════════════════════════════════════════════════════════╝"

if [ $TOTAL_FAIL -eq 0 ]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ $TOTAL_FAIL test(s) failed"
  exit 1
fi
