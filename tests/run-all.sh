#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  check-my-toolkit Process E2E Tests                        ║"
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

TOTAL_PASS=0
TOTAL_FAIL=0

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
