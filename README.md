# cmt-e2e-process

End-to-end test suite for check-my-toolkit `cm process` checks.

## What it tests

| Test | Target Repo | Expected Result |
|------|-------------|-----------------|
| PR within limits | cmt-pr-small | PASS |
| PR exceeds file limit | cmt-pr-large | FAIL |
| PR exceeds line limit | cmt-pr-large | FAIL |
| Branch protection enabled | cmt-protected | PASS |
| Branch protection disabled | cmt-unprotected | FAIL |
| CODEOWNERS exists | cmt-codeowners | PASS |
| CODEOWNERS missing | cmt-unprotected | FAIL |

## Prerequisites

- `gh` CLI authenticated with access to chrismlittle123-testing org
- `cm` (check-my-toolkit) installed globally
- Node.js 20+

## Running locally

```bash
# Run all tests
./tests/run-all.sh

# Run specific test suites
./tests/test-repo-checks.sh
./tests/test-pr-checks.sh
```

## CI

Tests run automatically on push to main and can be triggered manually.

## Test Repos

- [cmt-pr-small](https://github.com/chrismlittle123-testing/cmt-pr-small) - PR limits: 20 files, 500 lines
- [cmt-pr-large](https://github.com/chrismlittle123-testing/cmt-pr-large) - PR limits: 5 files, 100 lines  
- [cmt-protected](https://github.com/chrismlittle123-testing/cmt-protected) - Branch protection ON
- [cmt-unprotected](https://github.com/chrismlittle123-testing/cmt-unprotected) - Branch protection OFF
- [cmt-codeowners](https://github.com/chrismlittle123-testing/cmt-codeowners) - Has CODEOWNERS file
