# Bugs Found in check-my-toolkit v1.3.0 - v1.6.0

This document lists bugs discovered during E2E testing of the new features introduced in check-my-toolkit versions 1.3.0 through 1.6.0.

**Testing Environment:**
- check-my-toolkit version: 1.6.0
- Node.js version: 25.2.1
- Platform: macOS (Darwin 25.2.0)

---

## Bug Status Summary

### Fixed Bugs (verified in v1.5.x - v1.6.0)

| Bug # | Fixed In | Feature | Description |
|-------|----------|---------|-------------|
| 1 | v1.5.4 | forbidden_files | Config merge fix - feature now works |
| 4 | v1.5.5 | validate tier | Git root metadata lookup now correct |
| 6 | v1.5.5 | validate tier | YAML parse errors now show warning |
| 7 | v1.5.5 | validate tier | Empty vs missing metadata now distinguished |
| 8 | v1.5.5 | validate tier | Empty rulesets now show warning |
| 9 | v1.5.5 | validate tier | Invalid tier now shows valid values |

### New Features Working Correctly (v1.5.0 - v1.6.0)

| Version | Feature | Status |
|---------|---------|--------|
| v1.6.0 | CI Commands Enforcement | Working - all 10 tests passed |
| v1.5.7 | CLI exit codes for invalid args | Working |
| v1.5.6 | Duplicate extensions validation | Working |
| v1.5.6 | Block comment detection | Working |
| v1.5.5 | Tier validation improvements | Mostly working (see new bugs) |
| v1.5.4 | Forbidden files merge | Working |
| v1.5.0 | TypeScript naming conventions | Working |

---

## New Bugs Found in v1.5.0 - v1.6.0

### Bug #14: Custom ignore directories not working (v1.5.7)

**Severity:** Medium

**Version Affected:** 1.5.7 - 1.6.0

**Description:**
The `ignore` option in `[process.forbidden_files]` does not work with custom directory patterns. Files in directories specified in the `ignore` array are still detected as violations.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.forbidden_files]
   enabled = true
   files = ["**/.env"]
   ignore = ["vendor/", "build/"]
   ```
2. Create forbidden files in ignored directories:
   ```
   vendor/.env
   build/.env
   ```
3. Run `cm process check`

**Expected Result:**
- Files in `vendor/` and `build/` should be ignored
- No violations should be reported

**Actual Result:**
```
✗ Forbidden Files: 2 violation(s)
    vendor/.env error  Forbidden file exists: vendor/.env (matched pattern: **/.env)
    build/.env error  Forbidden file exists: build/.env (matched pattern: **/.env)
```

**Note:** Default ignores (`node_modules/`, `.git/`) work correctly. Only custom ignore patterns fail.

---

### Bug #15: Empty ignore array doesn't override defaults (v1.5.7)

**Severity:** Low

**Version Affected:** 1.5.7 - 1.6.0

**Description:**
Setting `ignore = []` in `[process.forbidden_files]` does not disable the default ignore patterns (node_modules/, .git/). There is no way to scan files in these directories.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.forbidden_files]
   enabled = true
   files = ["**/.env"]
   ignore = []
   ```
2. Create a forbidden file in node_modules:
   ```
   node_modules/.env
   ```
3. Run `cm process check`

**Expected Result:**
- With explicit empty `ignore = []`, defaults should be overridden
- File in `node_modules/.env` should be detected

**Actual Result:**
- `node_modules/` is still ignored (default behavior)
- No violation reported for `node_modules/.env`

**Note:** This may be intentional behavior, but there's no documented way to scan node_modules if needed.

---

### Bug #16: Invalid glob patterns not validated (v1.5.5)

**Severity:** Low

**Version Affected:** 1.5.5 - 1.6.0

**Description:**
The changelog for v1.5.5 states "Glob pattern validation added for forbidden_files configuration", but invalid glob patterns are accepted without error.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.forbidden_files]
   enabled = true
   files = ["[invalid"]  # Unclosed bracket - invalid glob syntax
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail with error about invalid glob pattern

**Actual Result:**
```
✓ Valid: check.toml
```

**Impact:** Invalid patterns will fail silently at runtime instead of being caught during config validation.

---

## Previously Documented Bugs (v1.3.0 - v1.4.0)

### Bug #1: [FIXED in v1.5.4] forbidden_files configuration not merged

**Status:** FIXED

**Description:**
The `[process.forbidden_files]` feature was completely non-functional because `mergeProcess()` didn't include `forbidden_files` in its merge logic.

**Fix:** v1.5.4 integrated `forbidden_files` into the merge process.

---

### Bug #2: Tier validation case sensitivity not documented (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0 - 1.6.0

**Status:** Still present, but less impactful with Bug #9 fix

**Description:**
Tier values in `repo-metadata.yaml` are case-sensitive. Using "Production" instead of "production" defaults to "internal" tier. With v1.5.5, a warning is now shown when an invalid tier is used, which helps users identify this issue.

---

### Bug #3: Tier validation doesn't trim whitespace (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0 - 1.6.0

**Status:** Still present

**Description:**
Whitespace in tier values is not trimmed, causing unexpected failures.

---

### Bug #4: [FIXED in v1.5.5] Custom config path breaks tier metadata resolution

**Status:** FIXED

**Description:**
When using `--config` with a subdirectory path, tier validation looked for `repo-metadata.yaml` relative to config instead of git root.

**Fix:** v1.5.5 corrected repo-metadata.yaml lookup to use git root.

---

### Bug #5: Ruleset matching is case-sensitive without warning (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0 - 1.6.0

**Status:** Still present

**Description:**
Ruleset suffix matching is case-sensitive. A ruleset named "base-Production" won't match tier "production".

---

### Bug #6: [FIXED in v1.5.5] Invalid YAML silently defaults to internal

**Status:** FIXED

**Description:**
Invalid YAML in repo-metadata.yaml silently defaulted to "internal".

**Fix:** v1.5.5 displays a warning when repo-metadata.yaml contains YAML parsing errors.

---

### Bug #7: [FIXED in v1.5.5] Empty repo-metadata.yaml not distinguished from missing file

**Status:** FIXED

**Description:**
Empty and missing metadata files showed the same source.

**Fix:** v1.5.5 distinguishes between missing, empty, and invalid repo-metadata files.

---

### Bug #8: [FIXED in v1.5.5] No validation that rulesets array isn't empty

**Status:** FIXED

**Description:**
Empty rulesets with configured extends passed silently.

**Fix:** v1.5.5 issues a warning when extends.registry is configured but rulesets remain empty.

---

### Bug #9: [FIXED in v1.5.5] tier validation error message doesn't suggest valid values

**Status:** FIXED

**Description:**
Invalid tier values didn't show what valid options were available.

**Fix:** v1.5.5 displays valid tier options when invalid tier values are encountered.

---

### Bug #10: No audit command for forbidden_files (v1.4.0)

**Severity:** Low

**Version Affected:** 1.4.0 - 1.6.0

**Status:** Still present (related to Bug #16)

**Description:**
The `cm process audit` command doesn't verify that forbidden_files patterns are valid glob patterns.

---

### Bug #11: forbidden_files patterns with special glob characters may not work as expected

**Severity:** Low

**Version Affected:** 1.4.0 - 1.6.0

**Status:** Still present

**Description:**
Patterns containing special characters like `[`, `]`, `{`, `}` may not match files correctly.

---

### Bug #12: tier validation JSON output doesn't include all diagnostic information (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0 - 1.6.0

**Status:** Still present

---

### Bug #13: No way to validate tier without having extends configured (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0 - 1.6.0

**Status:** Still present

---

## New Bugs Found in Extended v1.6.0 Testing

### Bug #17: Ticket reference in commit body not detected (v1.6.0)

**Severity:** Medium

**Version Affected:** 1.6.0

**Description:**
When `require_in_commits = true` is set in `[process.tickets]`, the tool only looks for ticket references in the commit message subject line. Ticket references in the commit body are not detected.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.tickets]
   enabled = true
   pattern = "^(PROJ|JIRA)-[0-9]+"
   require_in_commits = true
   ```
2. Create a commit message file with ticket in body:
   ```
   Add new feature

   This implements the feature described in PROJ-456.
   ```
3. Run `cm process check-commit COMMIT_MSG`

**Expected Result:**
- Ticket `PROJ-456` in the body should be detected
- Check should pass

**Actual Result:**
```
✗ Invalid commit message:
  Missing ticket reference matching: ^(PROJ|JIRA)-[0-9]+
```

**Impact:** Users who follow conventional commits (ticket in body) will have false failures.

---

### Bug #18: Coverage min_threshold from check.toml ignored (v1.6.0)

**Severity:** High

**Version Affected:** 1.6.0

**Description:**
The `min_threshold` setting in `[process.coverage]` is completely ignored. The coverage check only works if you have a coverage threshold configured in vitest.config.ts, jest.config.js, or .nycrc. The check.toml setting is non-functional.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.coverage]
   enabled = true
   min_threshold = 80
   ```
2. Create a coverage/lcov.info file with coverage data
3. Run `cm process check`

**Expected Result:**
- Coverage should be read from lcov.info
- Threshold should be compared against `min_threshold` (80)

**Actual Result:**
```
✗ Coverage: 1 violation(s)
    error  No coverage threshold config found (checked vitest, jest, nyc)
```

**Impact:** The `min_threshold` config option is non-functional. Users cannot enforce coverage thresholds without tool-specific config files.

---

### Bug #19: PR exclude option documented but not supported (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
The `exclude` option for `[process.pr]` causes a config validation error, even though excluding files from PR size limits is a reasonable feature expectation.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.pr]
   enabled = true
   max_files = 10
   max_lines = 200
   exclude = ["*.lock", "*.generated.ts"]
   ```
2. Run `cm validate config`

**Expected Result:**
- Config should be valid
- Lock files and generated files should be excluded from PR size calculation

**Actual Result:**
```
✗ Invalid: Invalid check.toml configuration:
  - process.pr: Unrecognized key(s) in object: 'exclude'
```

**Note:** This is a missing feature rather than a bug, but the expectation is reasonable based on similar exclude options in other checks.

---

## New Bugs Found in Branch Protection & Rulesets Testing (v1.6.0)

### Bug #20: required_reviews > 6 not validated (v1.6.0)

**Severity:** Medium

**Version Affected:** 1.6.0

**Description:**
The `required_reviews` setting in `[process.repo.branch_protection]` accepts values greater than 6, but GitHub's API has a maximum of 6 required reviewers. Invalid values pass config validation and will fail at runtime when trying to apply to GitHub.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_branch_protection = true

   [process.repo.branch_protection]
   branch = "main"
   required_reviews = 10
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail with error: "required_reviews must be between 0 and 6"

**Actual Result:**
```
✓ Valid: check.toml
```

**Impact:** Users won't discover the invalid value until they try to sync to GitHub, where the API will reject it.

---

### Bug #21: Empty branch name not validated (v1.6.0)

**Severity:** Medium

**Version Affected:** 1.6.0

**Description:**
An empty string for `branch` in `[process.repo.branch_protection]` passes config validation but would fail at runtime.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_branch_protection = true

   [process.repo.branch_protection]
   branch = ""
   required_reviews = 1
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail with error: "branch cannot be empty"

**Actual Result:**
```
✓ Valid: check.toml
```

---

### Bug #22: Empty tag patterns array not validated (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
An empty `patterns` array in `[process.repo.tag_protection]` passes config validation but provides no meaningful protection.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true

   [process.repo.tag_protection]
   patterns = []
   prevent_deletion = true
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail or warn: "tag_protection patterns cannot be empty"

**Actual Result:**
```
✓ Valid: check.toml
```

**Impact:** Users may think they have tag protection configured when they actually don't.

---

### Bug #23: sync-diff command inherits parent git context (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
When running `cm process diff` in a directory that is not a git repo but is nested under a git repo, the command uses the parent repo's git context instead of failing gracefully.

**Steps to Reproduce:**
1. Create a subdirectory in a git repo without initializing git
2. Create a check.toml in that directory
3. Run `cm process diff`

**Expected Result:**
- Command should fail with "Not a git repository" error

**Actual Result:**
- Command uses the parent directory's git remote and attempts to diff against that repo

---

### Bug #24: CODEOWNERS check skipped when no GitHub remote (v1.6.0)

**Severity:** Medium

**Version Affected:** 1.6.0

**Description:**
When `require_codeowners = true` is set but the repository has no GitHub remote configured, the entire repo check is skipped instead of checking for the local CODEOWNERS file.

**Steps to Reproduce:**
1. Create a local git repo without a GitHub remote
2. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_codeowners = true
   ```
3. Do NOT create a CODEOWNERS file
4. Run `cm process check`

**Expected Result:**
- Check should fail: "CODEOWNERS file required but not found"

**Actual Result:**
```
✓ Repository: skipped - Could not determine GitHub repository from git remote
✓ All checks passed
```

**Impact:** Teams working in repos without remotes (or with non-GitHub remotes) cannot use the CODEOWNERS check.

---

### Bug #25: Empty CODEOWNERS file not validated (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
When `require_codeowners = true` is set and a CODEOWNERS file exists but is empty, the check passes without warning.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_codeowners = true
   ```
2. Create an empty `.github/CODEOWNERS` file
3. Run `cm process check`

**Expected Result:**
- Check should fail or warn: "CODEOWNERS file is empty"

**Actual Result:**
- Check passes silently

**Impact:** Users may think they have code review coverage when they don't.

---

### Bug #26: Newlines in status check names not validated (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
Status check names containing newlines or other control characters pass config validation, but would likely cause issues with the GitHub API.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_branch_protection = true

   [process.repo.branch_protection]
   branch = "main"
   require_status_checks = ["ci/test\ninjection", "build"]
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail: "status check names cannot contain newlines"

**Actual Result:**
```
✓ Valid: check.toml
```

---

### Bug #27: Invalid CODEOWNERS syntax not validated (v1.6.0)

**Severity:** Low

**Version Affected:** 1.6.0

**Description:**
CODEOWNERS files with invalid syntax (e.g., missing @ prefix on usernames) are accepted without warning.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.repo]
   enabled = true
   require_codeowners = true
   ```
2. Create a CODEOWNERS file with invalid syntax:
   ```
   * team/reviewers
   ```
   (Should be `* @team/reviewers`)
3. Run `cm process check`

**Expected Result:**
- Check should warn: "CODEOWNERS contains invalid syntax on line 1"

**Actual Result:**
- Check passes silently (when repo has GitHub remote) or skipped (when no remote)

**Impact:** Users may have incorrectly formatted CODEOWNERS that GitHub ignores.

---

## Summary

### All Bugs by Status

| Bug # | Severity | Status | Feature | Description |
|-------|----------|--------|---------|-------------|
| 1 | Critical | FIXED (v1.5.4) | forbidden_files | Config not merged |
| 2 | Medium | Open | validate tier | Case-sensitive tier values |
| 3 | Medium | Open | validate tier | Whitespace not trimmed |
| 4 | Medium | FIXED (v1.5.5) | validate tier | Custom config path issue |
| 5 | Medium | Open | validate tier | Case-sensitive ruleset matching |
| 6 | Low | FIXED (v1.5.5) | validate tier | Invalid YAML silently defaults |
| 7 | Low | FIXED (v1.5.5) | validate tier | Empty vs missing not distinguished |
| 8 | Low | FIXED (v1.5.5) | validate tier | Empty rulesets not warned |
| 9 | Low | FIXED (v1.5.5) | validate tier | No valid values shown |
| 10 | Low | Open | forbidden_files | No audit for pattern validation |
| 11 | Low | Open | forbidden_files | Special glob chars may fail |
| 12 | Low | Open | validate tier | JSON output missing diagnostics |
| 13 | Low | Open | validate tier | Invalid tier passes without extends |
| 14 | Medium | Open | forbidden_files | Custom ignore dirs not working |
| 15 | Low | Open | forbidden_files | Empty ignore doesn't override defaults |
| 16 | Low | Open | forbidden_files | Invalid glob patterns not validated |
| 17 | Medium | Open | process.tickets | Ticket in commit body not detected |
| 18 | High | Open | process.coverage | min_threshold from check.toml ignored |
| 19 | Low | Open | process.pr | exclude option not supported |
| 20 | Medium | NEW | branch_protection | required_reviews > 6 not validated |
| 21 | Medium | NEW | branch_protection | Empty branch name not validated |
| 22 | Low | NEW | tag_protection | Empty patterns array not validated |
| 23 | Low | NEW | sync/diff | Inherits parent git context |
| 24 | Medium | NEW | repo check | CODEOWNERS skipped when no remote |
| 25 | Low | NEW | CODEOWNERS | Empty file not validated |
| 26 | Low | NEW | branch_protection | Newlines in status checks allowed |
| 27 | Low | NEW | CODEOWNERS | Invalid syntax not validated |

### Totals

**Total Bugs:** 27
- Fixed: 6
- Open: 21

**By Severity:**
- Critical: 0 open (1 fixed)
- High: 1 open (0 fixed)
- Medium: 9 open (1 fixed)
- Low: 11 open (4 fixed)
