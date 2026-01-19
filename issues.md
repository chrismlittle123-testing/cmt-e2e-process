# Bugs Found in check-my-toolkit v1.3.0 - v1.4.0

This document lists bugs discovered during E2E testing of the new features introduced in check-my-toolkit versions 1.3.0 through 1.4.0.

**Testing Environment:**
- check-my-toolkit version: 1.4.0
- Node.js version: 25.2.1
- Platform: macOS (Darwin 25.2.0)

---

## Critical Bugs

### Bug #1: [CRITICAL] forbidden_files configuration not merged - feature completely broken (v1.4.0)

**Severity:** Critical

**Version Affected:** 1.4.0

**Description:**
The `[process.forbidden_files]` feature introduced in v1.4.0 is completely non-functional. The configuration is parsed and validated but never passed to the runner because the `mergeProcess()` function in `config/loader.js` does not include `forbidden_files` in its merge logic.

**Root Cause:**
In `dist/config/loader.js` lines 278-292, the `mergeProcess()` function explicitly merges all process config sections (hooks, ci, branches, commits, changesets, pr, tickets, coverage, repo, backups, codeowners, docs) but omits `forbidden_files`. This causes the `forbidden_files` configuration to be dropped when merging with defaults.

**Steps to Reproduce:**
1. Create a `check.toml` with:
   ```toml
   [process.forbidden_files]
   enabled = true
   files = [".env"]
   ```
2. Create a `.env` file in the same directory
3. Run `cm process check --format json`

**Expected Result:**
- Check should detect the forbidden `.env` file
- Exit code should be 1
- Output should show violation for forbidden file

**Actual Result:**
- Process domain shows `"status": "skip"` and `"checks": []`
- Exit code is 0
- No violations reported
- `.env` file is not detected

**Evidence:**
```json
{
  "domains": {
    "process": {
      "domain": "process",
      "status": "skip",
      "checks": [],
      "violationCount": 0
    }
  }
}
```

**Impact:** The entire forbidden_files feature advertised in v1.4.0 does not work.

---

## Medium Severity Bugs

### Bug #2: Tier validation case sensitivity not documented (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0

**Description:**
Tier values in `repo-metadata.yaml` are case-sensitive but this is not documented or handled gracefully. Using "Production" instead of "production" silently falls back to "internal" tier.

**Steps to Reproduce:**
1. Create `repo-metadata.yaml`:
   ```yaml
   tier: Production
   ```
2. Create `check.toml` with production rulesets:
   ```toml
   [extends]
   registry = "github:example/standards"
   rulesets = ["base-production"]
   ```
3. Run `cm validate tier`

**Expected Result:**
- Either: Accept "Production" as equivalent to "production"
- Or: Clear error message about invalid tier value

**Actual Result:**
- Silently defaults to "internal" tier
- Validation fails because "base-production" doesn't match "*-internal"
- User gets confusing error message

**Evidence:**
```
✗ Tier validation failed
  Tier: internal (source: default)  <-- Should say "Production is not a valid tier"
  Expected pattern: *-internal
  Rulesets: [base-production]
```

---

### Bug #3: Tier validation doesn't trim whitespace (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0

**Description:**
Whitespace in tier values (e.g., from YAML multiline strings) is not trimmed, causing unexpected failures.

**Steps to Reproduce:**
1. Create `repo-metadata.yaml`:
   ```yaml
   tier: " production "
   ```
2. Create `check.toml` with production rulesets
3. Run `cm validate tier`

**Expected Result:**
- Tier value should be trimmed to "production"
- Validation should pass

**Actual Result:**
- Tier " production " is not in VALID_TIERS
- Silently defaults to "internal"
- Validation fails

---

### Bug #4: Custom config path breaks tier metadata resolution (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0

**Description:**
When using `--config` to specify a config file in a subdirectory, tier validation looks for `repo-metadata.yaml` relative to the config file location instead of the repository root.

**Steps to Reproduce:**
1. Create directory structure:
   ```
   project/
   ├── repo-metadata.yaml  (tier: production)
   └── config/
       └── check.toml  (with production rulesets)
   ```
2. Run `cm validate tier --config config/check.toml`

**Expected Result:**
- Should find `repo-metadata.yaml` in the project root
- Validation should pass

**Actual Result:**
- Looks for `repo-metadata.yaml` in `config/` directory
- Defaults to "internal" tier
- Validation fails

---

### Bug #5: Ruleset matching is case-sensitive without warning (v1.3.0)

**Severity:** Medium

**Version Affected:** 1.3.0

**Description:**
Ruleset suffix matching is case-sensitive. A ruleset named "base-Production" won't match tier "production".

**Steps to Reproduce:**
1. Create `check.toml`:
   ```toml
   [extends]
   registry = "github:example/standards"
   rulesets = ["base-Production"]  # Note capital P
   ```
2. Create `repo-metadata.yaml`:
   ```yaml
   tier: production
   ```
3. Run `cm validate tier`

**Expected Result:**
- Either: Case-insensitive matching
- Or: Warning about case mismatch

**Actual Result:**
- Validation fails without clear indication that case is the issue

---

## Low Severity Bugs

### Bug #6: Invalid YAML in repo-metadata.yaml silently defaults to internal (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
When `repo-metadata.yaml` contains invalid YAML, tier validation silently defaults to "internal" without warning.

**Steps to Reproduce:**
1. Create `repo-metadata.yaml` with invalid YAML:
   ```yaml
   tier: production
     bad: yaml: here
   ```
2. Run `cm validate tier`

**Expected Result:**
- Warning about YAML parse error
- Clear indication that default tier is being used due to error

**Actual Result:**
- Silently defaults to "internal"
- User may not realize their metadata file is broken

---

### Bug #7: Empty repo-metadata.yaml not distinguished from missing file (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
An empty `repo-metadata.yaml` file and a missing file both result in "default" tier source, making debugging difficult.

**Steps to Reproduce:**
1. Create empty `repo-metadata.yaml` file (0 bytes)
2. Run `cm validate tier`

**Expected Result:**
- Different tier source message (e.g., "empty" vs "missing")

**Actual Result:**
- Both show `(source: default)`

---

### Bug #8: No validation that rulesets array isn't empty when extends is configured (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
When `[extends]` is configured but `rulesets = []`, the tier validation passes but the extends feature serves no purpose.

**Steps to Reproduce:**
1. Create `check.toml`:
   ```toml
   [extends]
   registry = "github:example/standards"
   rulesets = []
   ```
2. Create `repo-metadata.yaml` with any tier
3. Run `cm validate tier`

**Expected Result:**
- Warning that empty rulesets means no standards are being applied

**Actual Result:**
- Passes silently

---

### Bug #9: tier validation error message doesn't suggest valid values (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
When an invalid tier value is used, the error message doesn't indicate what valid values are.

**Steps to Reproduce:**
1. Create `repo-metadata.yaml`:
   ```yaml
   tier: staging
   ```
2. Run `cm validate tier`

**Expected Result:**
- Error message: "Invalid tier 'staging'. Valid values are: production, internal, prototype"

**Actual Result:**
- Silently defaults to "internal" without any indication of valid values

---

### Bug #10: No audit command for forbidden_files (v1.4.0)

**Severity:** Low

**Version Affected:** 1.4.0

**Description:**
The `cm process audit` command doesn't verify that forbidden_files patterns are valid glob patterns before running checks.

**Impact:** Invalid patterns are only caught at check runtime, not during audit.

---

## Edge Case Issues

### Bug #11: forbidden_files patterns with special glob characters may not work as expected (v1.4.0)

**Severity:** Low (cannot fully test due to Bug #1)

**Version Affected:** 1.4.0

**Description:**
Patterns containing special characters like `[`, `]`, `{`, `}` may not match files correctly due to glob interpretation.

**Example:**
- Pattern: `"file[1].txt"`
- May match `file1.txt` instead of literal `file[1].txt`

**Note:** Cannot fully verify due to Bug #1 (forbidden_files not working).

---

### Bug #12: tier validation JSON output doesn't include all diagnostic information (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
The JSON output from `cm validate tier --format json` doesn't include the full diagnostic path for debugging (e.g., paths searched for config/metadata files).

---

### Bug #13: No way to validate tier without having extends configured (v1.3.0)

**Severity:** Low

**Version Affected:** 1.3.0

**Description:**
The `cm validate tier` command always passes if `[extends]` is not configured, even if `repo-metadata.yaml` has an invalid tier value.

**Steps to Reproduce:**
1. Create `check.toml` without extends:
   ```toml
   [code.linting.eslint]
   enabled = true
   ```
2. Create `repo-metadata.yaml`:
   ```yaml
   tier: invalid-value
   ```
3. Run `cm validate tier`

**Expected Result:**
- Warning about invalid tier in metadata

**Actual Result:**
- Passes because "No extends configured (no tier constraint)"

---

## Summary

| Bug # | Severity | Feature | Description |
|-------|----------|---------|-------------|
| 1 | Critical | forbidden_files | Feature completely broken - config not merged |
| 2 | Medium | validate tier | Case-sensitive tier values not documented |
| 3 | Medium | validate tier | Whitespace not trimmed from tier values |
| 4 | Medium | validate tier | Custom config path breaks metadata resolution |
| 5 | Medium | validate tier | Case-sensitive ruleset matching without warning |
| 6 | Low | validate tier | Invalid YAML silently defaults |
| 7 | Low | validate tier | Empty vs missing metadata not distinguished |
| 8 | Low | validate tier | Empty rulesets array not warned |
| 9 | Low | validate tier | Error messages don't suggest valid values |
| 10 | Low | forbidden_files | No audit command for pattern validation |
| 11 | Low | forbidden_files | Special glob characters may behave unexpectedly |
| 12 | Low | validate tier | JSON output missing diagnostic info |
| 13 | Low | validate tier | Invalid tier not validated without extends |

**Total Bugs Found:** 13
- Critical: 1
- Medium: 4
- Low: 8
