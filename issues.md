# check-my-toolkit Issues and Bugs

Discovered through E2E testing and source code review of [chrismlittle123/check-my-toolkit](https://github.com/chrismlittle123/check-my-toolkit) v1.3.0.

---

## Critical Issues

### 1. Empty Pattern Allows All Branch Names
**Severity:** Critical
**Component:** `process.branches`
**File:** `src/process/tools/branches.ts`

**Description:** When `pattern = ""` (empty string) is configured, all branch names are accepted as valid. An empty string creates a regex that matches everything.

**Reproduction:**
```toml
[process.branches]
enabled = true
pattern = ""
```
```bash
git checkout -b any-random-branch
cm process check-branch  # Returns "✓ Branch name is valid"
```

**Expected:** Should fail validation or warn about empty pattern configuration.

---

### 2. Empty Types Array Accepts All Commit Messages
**Severity:** Critical
**Component:** `process.commits`
**File:** `src/process/tools/commits.ts`

**Description:** When `types = []` (empty array) is configured, all commit messages are accepted as valid, even non-conventional ones.

**Reproduction:**
```toml
[process.commits]
enabled = true
types = []
```
```bash
echo "bad commit message" > /tmp/msg
cm process check-commit /tmp/msg  # Returns "✓ Commit message is valid"
```

**Expected:** Should fail validation or warn about empty types configuration.

---

### 3. Empty Ticket Pattern Accepts All Commits
**Severity:** Critical
**Component:** `process.tickets`
**File:** `src/process/tools/tickets.ts`

**Description:** When `pattern = ""` is configured with `require_in_commits = true`, all commits are accepted regardless of whether they contain a ticket reference.

**Reproduction:**
```toml
[process.tickets]
enabled = true
pattern = ""
require_in_commits = true
```
```bash
echo "commit without ticket" > /tmp/msg
cm process check-commit /tmp/msg  # Returns "✓ Commit message is valid"
```

**Expected:** Should reject commits without ticket reference or warn about empty pattern.

---

### 4. Invalid YAML Workflow Files Silently Pass CI Checks
**Severity:** Critical
**Component:** `process.ci`
**File:** `src/process/tools/ci.ts`

**Description:** Workflow files with invalid YAML syntax pass CI checks without any error or warning. The tool silently skips unparseable files.

**Reproduction:**
```yaml
# .github/workflows/ci.yml (invalid YAML)
name: Invalid YAML
jobs:
  test
    steps:
```
```toml
[process.ci]
enabled = true
require_workflows = ["ci.yml"]
```
```bash
cm process check  # Returns "✓ CI: passed"
```

**Expected:** Should report YAML parsing error and fail the check.

---

### 5. Changesets Uses `process.cwd()` Instead of `projectRoot`
**Severity:** Critical
**Component:** `process.changesets`
**File:** `src/process/tools/changesets.ts` (lines 177, 188)

**Description:** The `checkDirectoryExists()` and `checkChangesRequireChangeset()` methods use hardcoded `process.cwd()` instead of the `projectRoot` parameter. This causes incorrect behavior when running from a different directory.

**Expected:** Should use `projectRoot` parameter consistently throughout the tool.

---

## High Severity Issues

### 6. PR Data Missing Additions/Deletions Defaults to 0
**Severity:** High
**Component:** `process.pr`
**File:** `src/process/tools/pr.ts` (lines 126-143)

**Description:** If GitHub doesn't return `additions` or `deletions` fields in the PR event, they default to 0. This could incorrectly pass PRs that should fail or mask missing data.

```typescript
const additions = pr.additions ?? 0;
const deletions = pr.deletions ?? 0;
```

**Expected:** Should distinguish between "0 lines changed" and "data not available."

---

### 7. CODEOWNERS Owner Order is Not Validated
**Severity:** High
**Component:** `process.codeowners`
**File:** `src/process/tools/codeowners.ts` (lines 178-184)

**Description:** Owner matching is order-independent, but GitHub CODEOWNERS processes owners in order. `@user1 @user2` in the file matches config with `@owner2 @owner1`.

**Reproduction:**
```
# CODEOWNERS
* @owner1 @owner2
```
```toml
[[process.codeowners.rules]]
pattern = "*"
owners = ["@owner2", "@owner1"]  # Different order - still passes
```

**Expected:** Should either enforce order matching or document this behavior clearly.

---

### 8. CODEOWNERS Malformed Lines Silently Ignored
**Severity:** High
**Component:** `process.codeowners`
**File:** `src/process/tools/codeowners.ts` (lines 97-126)

**Description:** Lines with patterns but no owners (malformed) are silently ignored instead of reporting violations.

**Reproduction:**
```
# CODEOWNERS
*
/docs @owner
```
The line `*` (pattern without owner) is silently skipped.

**Expected:** Should report malformed CODEOWNERS entries.

---

### 9. Issue Reference Regex Can Cause False Positives
**Severity:** High
**Component:** `process.pr`
**File:** `src/process/tools/pr.ts` (lines 93-99)

**Description:** The regex for finding issue references doesn't use word boundaries, so strings like "someCloses #123" would incorrectly match.

```typescript
const regex = new RegExp(`(?:${keywordPattern})\\s+#(\\d+)`, "i");
```

**Expected:** Should use word boundaries: `\\b(?:${keywordPattern})\\s+#(\\d+)`

---

## Medium Severity Issues

### 10. Commits Scope Pattern Greedy Matching
**Severity:** Medium
**Component:** `process.commits`
**File:** `src/process/tools/commits.ts` (line 71)

**Description:** The optional scope pattern `(.+)` is greedy and could match too much text (e.g., `feat(api, docs): fix` would match `api, docs` instead of stopping at closing paren).

```typescript
const scopePattern = this.config.require_scope ? "\\(.+\\)" : "(\\(.+\\))?";
```

**Expected:** Should use non-greedy matching: `([^)]+)` or `(.+?)`

---

### 11. CI Action Extraction Doesn't Handle Docker Actions
**Severity:** Medium
**Component:** `process.ci`
**File:** `src/process/tools/ci.ts` (lines 114-120)

**Description:** Action extraction splits on `@` which breaks for Docker actions like `docker://image:tag`.

```typescript
usedActions.push(step.uses.split("@")[0]);
```

**Expected:** Should handle Docker action references specially.

---

### 12. Config Merge Silently Overwrites Rules
**Severity:** Medium
**Component:** `config`
**File:** `src/config/loader.ts` (lines 305-320)

**Description:** When merging CODEOWNERS rules from registry and project, conflicting rules are silently overwritten without warning.

**Expected:** Should warn when project rules override registry rules.

---

### 13. Changesets Frontmatter Requires Quoted Package Names
**Severity:** Medium
**Component:** `process.changesets`
**File:** `src/process/tools/changesets.ts` (lines 37-48)

**Description:** The regex requires quotes around package names, but standard YAML allows unquoted strings.

```typescript
const match = /^["']([^"']+)["']:\s*(patch|minor|major)\s*$/.exec(line);
```

**Expected:** Should accept unquoted package names per YAML spec.

---

### 14. Changesets Single Frontmatter Delimiter Not Detected
**Severity:** Medium
**Component:** `process.changesets`
**File:** `src/process/tools/changesets.ts`

**Description:** If a changeset file has only one `---` delimiter (start but no end), parsing may produce unexpected results.

**Expected:** Should validate proper frontmatter structure with two delimiters.

---

### 15. Branch Exclusion List is Case-Sensitive
**Severity:** Medium
**Component:** `process.branches`
**File:** `src/process/tools/branches.ts` (lines 44-47)

**Description:** The exclude list uses exact case-sensitive matching. `exclude = ["main"]` won't exclude "Main" or "MAIN".

```typescript
return excludeList.includes(branch);
```

**Expected:** Should document this behavior or make it configurable.

---

### 16. Config Symlink Race Condition
**Severity:** Medium
**Component:** `config`
**File:** `src/config/loader.ts` (lines 50-61)

**Description:** There's a TOCTOU (time-of-check-time-of-use) race condition between checking if a config file exists and reading it, especially with symlinks.

**Expected:** Handle file read errors gracefully instead of relying on existence check.

---

## Low Severity Issues

### 17. Error Message Uses Original Path Instead of Absolute
**Severity:** Low
**Component:** `config`
**File:** `src/config/loader.ts`

**Description:** When a config file isn't found, the error message shows the original relative path instead of the resolved absolute path.

```typescript
throw new ConfigError(`Config file not found: ${resolved}`);  // Should use absolutePath
```

---

### 18. Issue Keywords with Special Regex Characters
**Severity:** Low
**Component:** `process.pr`
**File:** `src/process/tools/pr.ts`

**Description:** Custom issue keywords containing special regex characters are escaped, which could cause unexpected behavior with case-insensitive matching.

---

### 19. Broken Symlink Detection Edge Cases
**Severity:** Low
**Component:** `config`
**File:** `src/config/loader.ts` (lines 24-40)

**Description:** The `isBrokenSymlink()` function returns `false` for non-existent paths, which may mask permission issues.

---

### 20. Help Examples Show Hardcoded Patterns
**Severity:** Low
**Component:** `process.branches`

**Description:** When branch validation fails, help examples show hardcoded patterns (`feature/v1.0.0/add-login`) regardless of actual configured pattern.

---

## Potential Improvements

### 21. Add `--strict` Mode
Consider adding a strict mode that fails on:
- Empty patterns/arrays in config
- Missing data in PR context
- Any silent skips

### 22. Add Config Linting
Add a `cm lint config` command that warns about:
- Empty patterns
- Empty arrays
- Potentially problematic regex patterns
- Unused configuration options

### 23. Better Error Messages for Tool Skips
When tools skip (e.g., "Not in PR context"), provide more actionable guidance.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 5 |
| High | 4 |
| Medium | 7 |
| Low | 4 |
| **Total** | **20** |

---

*Last updated: 2026-01-19*
*Tested against: check-my-toolkit v1.3.0*
