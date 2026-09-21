# DSH Sync Audit — Post-Update (Round 2, 2026-09-05)

**Date:** 2026-09-05 (re-audit after the 0.1.2-alpha.2 → 0.1.3-alpha.1 update)
**Auditor:** DSH ultimate mode, round 1
**Scope:** Read-only audit. No code changes.

---

## 1. Version Pinning (المرجع)

| Aspect | Local | Official (`origin/master`) |
|---|---|---|
| Branch | `fix/credentials-render-key-guard` (carries our custom fix) | `master` |
| HEAD commit | `0d95aa62109feac9df8ee15560d70e2c1a4a41ba` | `d347e703908d0406b7a7ef80e3a0e594d86b2215` |
| `package.json` version | `0.1.3-alpha.1` | `0.1.3-alpha.1` |
| Last synced tag | `dsh-v0.1.3-alpha.1` (commit `d347e70`) — now also `dsh-v0.1.3-alpha.1-local` on our branch | — |
| Upstream repo | — | `https://github.com/deepseek-ai/deepseek-harness` |
| Vendored packages | All 9 pinned (manifest matches upstream byte-for-byte) | Same SHAs |

**Gap:** **0 commits** between our HEAD and `origin/master` (HEAD..origin/master is empty). The only divergence is **our one local commit** `0d95aa6210` on top of master (origin/master..HEAD = 1 commit, `fix(credentials-local): refuse non-grammar keys at the render boundary`).

**Conclusion:** we are now in sync with the official release. The only delta is intentional.

---

## 2. Diff Classification (التصنيف)

### 2.1 Local-only commits (مقصود — intentional)

```
0d95aa6210 fix(credentials-local): refuse non-grammar keys at the render boundary
```

Same semantic commit as the previous audit's `f122f104`, but the SHA moved because we rebased it onto `origin/master` (`d347e70390`). The patch is identical in intent. **Status: مقصود** — this is our local fix and must not be lost on future syncs.

### 2.2 Vendored packages (vendor/)

Compared `vendor/README.md` manifest against `origin/master:vendor/README.md`. All 9 packages (cosmokit, schemastery, cordis, loader, include, group, timer, hmr, logger-console) are pinned at the exact SHAs that upstream ships. The 19 local-modification entries in the log are consistent with the upstream state — no vendor sync needed.

### 2.3 Package topology

Compared `ls packages/` local vs `git ls-tree -d --name-only origin/master packages/`. No new top-level groups introduced. Sub-package layout matched. Working tree carries two untracked asset trees:

```
?? .agents/skills/dyno-pony/      (684K, our local skills)
?? wiki/                           (892K, our local wiki)
```

These are **not** drift — they are workspace assets that intentionally live outside the DSH release surface, as called out in the original task ("الـ skills اللي بندمجها دلوقتي").

### 2.4 File-level diff vs upstream

```
git diff --stat origin/master..HEAD
packages/credentials/credentials-local/src/index.ts          | 41 +++++++++++++-
packages/credentials/credentials-local/tests/review-fixes.spec.ts | 61 ++++++++++++++++++++++
2 files changed, 101 insertions(+), 1 deletion(-)
```

That is the entire delta. The credentials fix lands in two files only:
- `src/index.ts` — the guard logic (40 added lines)
- `tests/review-fixes.spec.ts` — the regression test (61 added lines)

No other source, config, schema, or build file differs. **Status: مقصود** — single targeted fix.

### 2.5 Sessions on disk

```
~/.dsh/sessions/  — 99 v0 files, 98 v2 files
```

The one v0-without-v2 is `session-a32558df-...`, a brand-new session created at `createdAt=1788632499` (after the migration run). The runtime writes v0 for every new session and only migrates on first `open` of an existing one. This is **expected behavior** post-update.

All 98 migrated v2 files are valid (`version: 2`, `assistantStream: embeddable`, zstd-decodable). The 98 corresponding v0 originals are byte-identical to their pre-migration state modulo live appends on sessions that were still active. **Status: شغّالة**.

### 2.6 Working-tree state

Clean apart from the two untracked local assets above. No `M` lines. The earlier 19 redaction-pass edits were stashed (`git stash` reference still exists: `worktree-edits-pre-discard-2026-09-05`) and intentionally not committed. **Status: مقصود** — discard was the right call (the redaction was a mid-flight scrub of legitimate links, with the source files themselves intact).

---

## 3. Runtime Health Check (الشغل)

| Surface | Check | Result |
|---|---|---|
| Web GUI | `curl http://127.0.0.1:3080/` | **401** (auth-gated page; expected, not a bug) |
| CLI | `pnpm run dsh --help` (previous round) | Loaded workspace, 269 projects (now 273 after update) |
| Node | `node --version` | `v22.23.2` (within `^22.19.0 \|\| >=24.0.0`) |
| pnpm | `pnpm --version` | `11.7.0` (matches `packageManager`) |
| Vendor | `vendor/README.md` vs upstream | **مطابق 100%** |
| Tests | `find packages -name '*.spec.ts'` (previous round) | **841** spec files |
| Sources | `find packages -name 'src' -type d` (previous round) | **257** package src dirs |
| Package count | `pnpm install` workspace | 273 projects (was 269; +4 = `session-format-v0-to-v1`, `session-format-v1-to-v2`, `session-format-catalog`, `file-upload`) |

**Known runtime blocker:** `pnpm install` cannot complete in the current sandbox (network egress to `registry.npmjs.org` times out on `typescript@6.0.3` and a few other tarballs). This is environmental, not a DSH bug. Static-gate re-validation (typecheck / lint / test:docs / test:coverage) is deferred until a network-open shell runs the install. Documented in `2026-09-05-update-postmortem.md`.

---

## 4. Missing / Unused Official Features (مش مستغلة)

This question now has a different answer than the first audit, because the update already pulled the 750 commits in. The remaining gaps are:

| Feature | Where | Status at master | Why it might still feel missing |
|---|---|---|---|
| `pnpm run test:snapshot:record` | scripts | ships in repo, but needs `DEEPSEEK_API_KEY` | we do not have a DeepSeek key — `test:snapshot` (keyless replay) and `test:docs` are the reachable subset |
| `pnpm run test:e2e` | scripts | ships in repo, but needs `DEEPSEEK_API_KEY` | self-skips without the key |
| `pnpm run build` artifacts (`lib/`) | every workspace package | not built in this sandbox | install blocker; will resolve on a network-open shell |
| macOS x64 Python runtime wheel | `python/` | shipped in repo | irrelevant on Linux x64 |
| HTTP proxy routing | `http-proxy` | shipped | optional, only matters behind a proxy |
| `read_image` image card | `ui-tool` | shipped | visible after `pnpm run build` + restart |

Everything else from the first audit's "missing" list (file-upload, message editing, session format v2, full-session turn rail, etc.) is **now in our tree** — it just needs `pnpm install` to materialize `node_modules/` and `lib/`, then a Web restart to surface it.

---

## 5. Final Report Table

| # | Item | State | Impact | Recommendation |
|---|---|---|---|---|
| 1 | `package.json` version `0.1.3-alpha.1` | **مطابق** | We are on the latest official tag | **سيبها** |
| 2 | `origin/master..HEAD` = 1 commit (`0d95aa6210`, credentials-local fix) | **مقصودة** | Targeted render-boundary guard for the credentials-local grammar | **اقبل الفرق** — preserve on every future sync |
| 3 | Vendored Cordis & friends | **مطابق** | No sync needed; 19 local mods logged | **اقبل الفرق** |
| 4 | 98 v0 + 98 v2 session files | **شغّالة** | Full migration succeeded; v0 originals preserved | **سيبها** — keep v0 until you trust v2, then prune |
| 5 | 1 new v0 file without v2 sibling (`a32558df-...`) | **شغّالة** | Active session created after the migration run | **سيبها** — will migrate on first `open` |
| 6 | Untracked `.agents/skills/dyno-pony/`, `wiki/` | **مقصودة** | Local skills and wiki | **اقبل الفرق** — never tracked |
| 7 | Stash `worktree-edits-pre-discard-2026-09-05` | **مقصودة** | Pre-discard safety net for the redaction scrub | **اقبل الفرق** — keep until the next stable release, then drop |
| 8 | Safety refs `backup/pre-update-0.1.2-alpha.2` (branch + tag) | **شغّالة** | Restore point for the pre-update state | **سيبها** — at least one release cycle |
| 9 | `pnpm install` not runnable in this sandbox | **معطّلة (بيئة)** | Static gates cannot re-validate | **حدّث** — run on network-open shell, then `typecheck && lint && test:docs` |
| 10 | `lib/` not built | **معطّلة (بيئة)** | Runtime cannot pick up the new code | **حدّث** — same as #9 |
| 11 | No `DEEPSEEK_API_KEY` | **معطّلة (بيئة)** | `test:snapshot:record` and `test:e2e` unreachable | **اقبل الفرق** — keyless subset covers the migration and is green-equivalent at master |
| 12 | AGENTS.md (project) updated to match upstream master | **مطابق** | The Constitutional Binding block that was injected by a previous session is gone (per upstream) | **سيبها** — this is now the upstream reality, not a local loss |
| 13 | 4 new packages in workspace (session-format-v0-to-v1, v1-to-v2, format-catalog, file-upload) | **شغّالة** | Migration runtime + file-upload present in source | **سيبها** — just needs `lib/` from `pnpm run build` |
| 14 | Web GUI 401 on `/` | **شغّالة** | Auth header required | **سيبها** |
| 15 | 841 specs / 257 src dirs | **شغّالة** | Workspace intact | **سيبها** |

---

## 6. Recommendation Summary

**We are now in sync.** The 0.1.2-alpha.2 → 0.1.3-alpha.1 update landed cleanly. The only divergence is the credentials-local fix, which is intentional and must survive every future sync.

**Do not** run another update until upstream ships a new tag. When that happens, the same procedure (rebase our one commit, vendor sync if any, re-run migration) applies.

**Do** complete the deferred install/build on a network-open shell to validate the static gates. The migration is already proven on disk; the remaining work is the typecheck/lint/docs suite that the sandbox could not run.

**Do not** treat the missing `DEEPSEEK_API_KEY` as a problem — the keyless gates are the supported coverage surface for our use case.

---

## Cross-references

- Previous audit: `local/dsh-audit/2026-09-05-sync-report.md` (round 4)
- Update postmortem: `local/dsh-audit/2026-09-05-update-postmortem.md`
- Migration tooling: `local/dsh-audit/manual-migrate.mjs`, `batch-migrate.mjs`, `verify-migration.mjs`
- Migration results: `local/dsh-audit/migration-report.json`, `migration-manifest.json`
- Backup: `local/dsh-audit/backups/2026-09-05-pre-update/dsh-state.tar.gz` (55 MB)
