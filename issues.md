# Bugs Found in check-my-toolkit v1.3.0 - v2.0.0

This document lists bugs discovered during E2E testing of the new features introduced in check-my-toolkit versions 1.3.0 through 2.0.0.

**Testing Environment:**
- check-my-toolkit version: 2.0.0
- Node.js version: 25.2.1
- Platform: macOS (Darwin 25.2.0)

---

## Bug Status Summary

### Fixed Bugs (verified in v1.5.x - v2.0.0)

| Bug # | Fixed In | Feature | Description |
|-------|----------|---------|-------------|
| 1 | v1.5.4 | forbidden_files | Config merge fix - feature now works |
| 4 | v1.5.5 | validate tier | Git root metadata lookup now correct |
| 6 | v1.5.5 | validate tier | YAML parse errors now show warning |
| 7 | v1.5.5 | validate tier | Empty vs missing metadata now distinguished |
| 8 | v1.5.5 | validate tier | Empty rulesets now show warning |
| 9 | v1.5.5 | validate tier | Invalid tier now shows valid values |
| 17 | v2.0.0 | process.tickets | Ticket reference in commit body now detected |
| 19 | v2.0.0 | process.pr | exclude option now supported |

### New Features Working Correctly (v1.5.0 - v2.0.0)

| Version | Feature | Status |
|---------|---------|--------|
| v2.0.0 | process.commits | Working - types, pattern, require_scope, max_subject_length |
| v2.0.0 | process.changesets | Working - validation for paths, bump types, descriptions |
| v2.0.0 | process.codeowners | Working - rules-based CODEOWNERS validation |
| v2.0.0 | process.docs | Working - path, enforcement, size limits, staleness, coverage |
| v2.0.0 | code.coverage_run | Working - min_threshold, runner, custom command |
| v2.0.0 | process.hooks.commands | Working - command validation per hook |
| v2.0.0 | process.hooks.protected_branches | Working |
| v2.0.0 | process.repo.ruleset | Working - name, enforcement, bypass_actors |
| v2.0.0 | process.scan | Working - new command for scanning repo settings |
| v2.0.0 | diff-tags/sync-tags | Working - tag protection management |
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

### Bug #2: [REMOVED] Tier validation case sensitivity

**Status:** REMOVED - Not a bug (expected behavior, warning message is sufficient)

---

### Bug #3: [REMOVED] Tier validation doesn't trim whitespace

**Status:** REMOVED - Not a bug (users should provide correct values)

---

### Bug #4: [FIXED in v1.5.5] Custom config path breaks tier metadata resolution

**Status:** FIXED

**Description:**
When using `--config` with a subdirectory path, tier validation looked for `repo-metadata.yaml` relative to config instead of git root.

**Fix:** v1.5.5 corrected repo-metadata.yaml lookup to use git root.

---

### Bug #5: [REMOVED] Ruleset matching is case-sensitive

**Status:** REMOVED - Not a bug (ruleset naming is user's choice)

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

### Bug #17: [FIXED in v2.0.0] Ticket reference in commit body not detected

**Status:** FIXED

**Description:**
When `require_in_commits = true` is set in `[process.tickets]`, the tool now searches the entire commit message (subject and body) for ticket references.

**Fix:** v2.0.0 now searches the full commit message for ticket patterns.

---

### Bug #18: Coverage min_threshold from check.toml ignored (v1.6.0 - v2.0.0)

**Severity:** High

**Version Affected:** 1.6.0 - 2.0.0

**Status:** Still present (partially addressed but still not working correctly)

**Description:**
The `min_threshold` setting in `[process.coverage]` is not enforced when `enforce_in = "config"`. v2.0.0 added an `enforce_in` option with values "ci", "config", or "both", but when set to "config", the coverage check passes regardless of actual coverage percentage.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.coverage]
   enabled = true
   min_threshold = 80
   enforce_in = "config"
   ```
2. Create a coverage/lcov.info file with 50% coverage:
   ```
   TN:
   SF:src/index.ts
   DA:1,10
   DA:2,10
   DA:3,0
   DA:4,0
   LF:4
   LH:2
   end_of_record
   ```
3. Run `cm process check`

**Expected Result:**
- Coverage (50%) should be compared against `min_threshold` (80%)
- Check should fail with "Coverage 50% is below threshold 80%"

**Actual Result:**
```
✓ PROCESS
  ✓ Coverage: passed
```

**Impact:** The `min_threshold` config option is still non-functional when `enforce_in = "config"`. Users cannot enforce coverage thresholds from check.toml.

---

### Bug #19: [FIXED in v2.0.0] PR exclude option not supported

**Status:** FIXED

**Description:**
The `exclude` option for `[process.pr]` now works correctly. Users can exclude files from PR size calculations using glob patterns.

**Fix:** v2.0.0 added the `exclude` option to `[process.pr]` configuration. Example:
```toml
[process.pr]
enabled = true
max_files = 10
max_lines = 200
exclude = ["*.lock", "*.generated.ts", "package-lock.json"]
```

---

## New Bugs Found in Branch Protection & Rulesets Testing (v1.6.0)

### Bug #20: [REMOVED] required_reviews > 6 not validated

**Status:** REMOVED - `[process.repo.branch_protection]` is deprecated in v1.7.0, replaced by `[process.repo.ruleset]`

---

### Bug #21: [REMOVED] Empty branch name not validated

**Status:** REMOVED - `[process.repo.branch_protection]` is deprecated in v1.7.0, replaced by `[process.repo.ruleset]`

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

### Bug #24: [REMOVED] CODEOWNERS check skipped when no GitHub remote

**Status:** REMOVED - Not a bug (repo checks require GitHub remote by design)

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

## New Bugs Found in v2.0.0 Testing

### Bug #28: process.branches require_issue pattern not matching correctly (v2.0.0)

**Severity:** Medium

**Version Affected:** 2.0.0

**Description:**
When `require_issue = true` is set in `[process.branches]` with an `issue_pattern`, the pattern matching doesn't work correctly. Even when the branch name contains a substring matching the pattern, the check fails.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.branches]
   enabled = true
   require_issue = true
   issue_pattern = "PROJ-[0-9]+"
   ```
2. Create a branch with an issue reference:
   ```bash
   git checkout -b "feature/PROJ-123-add-feature"
   ```
3. Run `cm process check-branch`

**Expected Result:**
- Branch name contains `PROJ-123` which matches the pattern
- Check should pass

**Actual Result:**
```
✗ Branch 'feature/PROJ-123-add-feature' does not contain issue number. Expected format matching: PROJ-[0-9]+ (e.g., feature/123/description)
```

**Impact:** Users cannot use `require_issue` with custom issue patterns like Jira ticket formats.

---

### Bug #29: require_issue error message shows hardcoded examples (v2.0.0)

**Severity:** Low

**Version Affected:** 2.0.0

**Description:**
When `require_issue` validation fails, the error message shows hardcoded numeric examples (100, 101, 102) instead of examples using the configured `issue_pattern`.

**Steps to Reproduce:**
1. Configure `issue_pattern = "PROJ-[0-9]+"` in `[process.branches]`
2. Run `cm process check-branch` on any branch

**Expected Result:**
- Error examples should show PROJ-100, PROJ-101, etc. based on the pattern

**Actual Result:**
```
Examples (with issue number):
  feature/100/add-feature
  fix/101/add-feature
  hotfix/102/add-feature
```

**Impact:** Error messages are confusing when using custom issue patterns.

---

### Bug #30: Empty codeowners rules array not validated (v2.0.0)

**Severity:** Low

**Version Affected:** 2.0.0

**Description:**
An empty `rules` array in `[process.codeowners]` passes config validation but provides no meaningful CODEOWNERS enforcement.

**Steps to Reproduce:**
1. Create a `check.toml`:
   ```toml
   [process.codeowners]
   enabled = true
   rules = []
   ```
2. Run `cm validate config`

**Expected Result:**
- Validation should fail or warn: "codeowners rules cannot be empty"

**Actual Result:**
```
✓ Valid: check.toml
```

**Impact:** Users may think they have CODEOWNERS validation configured when they don't.

**Note:** Similar to Bug #22 (empty tag patterns).

---

## Summary

### All Bugs by Status

| Bug # | Severity | Status | Feature | Description |
|-------|----------|--------|---------|-------------|
| 1 | Critical | FIXED (v1.5.4) | forbidden_files | Config not merged |
| 2 | - | REMOVED | validate tier | Not a bug (case sensitivity expected) |
| 3 | - | REMOVED | validate tier | Not a bug (whitespace is user error) |
| 4 | Medium | FIXED (v1.5.5) | validate tier | Custom config path issue |
| 5 | - | REMOVED | validate tier | Not a bug (ruleset naming is user's choice) |
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
| 17 | Medium | FIXED (v2.0.0) | process.tickets | Ticket in body now detected |
| 18 | High | Open | process.coverage | min_threshold from check.toml still ignored |
| 19 | Low | FIXED (v2.0.0) | process.pr | exclude option now supported |
| 20 | - | REMOVED | branch_protection | Deprecated in v1.7.0 |
| 21 | - | REMOVED | branch_protection | Deprecated in v1.7.0 |
| 22 | Low | Open | tag_protection | Empty patterns array not validated |
| 23 | Low | Open | sync/diff | Inherits parent git context |
| 24 | - | REMOVED | repo check | Not a bug (requires GitHub remote by design) |
| 25 | Low | Open | CODEOWNERS | Empty file not validated |
| 26 | Low | Open | branch_protection | Newlines in status checks allowed |
| 27 | Low | Open | CODEOWNERS | Invalid syntax not validated |
| 28 | Medium | Open | process.branches | require_issue pattern not matching |
| 29 | Low | Open | process.branches | Hardcoded examples in error message |
| 30 | Low | Open | process.codeowners | Empty rules array not validated |

### Totals

**Total Bugs:** 30 tracked (6 removed as not bugs/deprecated)
- Fixed: 8 (v1.5.4: 1, v1.5.5: 5, v2.0.0: 2)
- Open: 16
- Removed: 6

**By Severity (Open only):**
- High: 1 (#18)
- Medium: 2 (#14, #28)
- Low: 13
