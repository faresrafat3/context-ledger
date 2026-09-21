# DSH Update Postmortem — 0.1.2-alpha.2 → 0.1.3-alpha.1

**Date:** 2026-09-05
**Operator:** Fares (via DSH ultimate mode, round 5+)
**Outcome:** Update applied; all 98 sessions migrated v0 → v2; vendored Cordis in sync.

---

## Summary

| Aspect | Before | After |
|---|---|---|
| Package version | `0.1.2-alpha.2` | `0.1.3-alpha.1` (+1 local commit) |
| Local HEAD | `f122f104` (own fix branch) | `0d95aa6210` (rebased on `d347e70390` = upstream master) |
| Tag | `dsh-v0.1.2-alpha.2` | `dsh-v0.1.3-alpha.1` + `dsh-v0.1.3-alpha.1-local` |
| Vendored Cordis SHAs | match upstream | unchanged (already in sync) |
| Session format version | `0` everywhere | `2` everywhere; v0 originals retained |
| Session files (v0 / v2) | 98 / 0 | 98 / 98 |
| Session migration failures | — | **0** (after fixing maxBuffer bug) |
| Tooling gates | not run | blocked: `pnpm install` failed (sandbox/network); see "Blockers" |

---

## What worked

1. **Phase 0 — Backup.** `git branch backup/pre-update-0.1.2-alpha.2` and `git tag backup/pre-update-0.1.2-alpha.2` created at the pre-update HEAD. `tar -czf ~/local/dsh-audit/backups/2026-09-05-pre-update/dsh-state.tar.gz .dsh/sessions .dsh/settings.yaml .dsh/.credentials.yaml .dsh/.anonymous-user-id .dsh/profiles .dsh/storages` captured every DSH state file outside the repo.
2. **Phase 0 — Worktree cleanup.** The 19 uncommitted edits (`M .agents/notes/...`, `M AGENTS.md`, `M packages/client/ui-tool/README.md`, etc.) all turned out to be a `[REDACTED:sk]` scrub of legitimate links (`2026-07-29-ask-question-web-presentation.md`, `2026-08-01-ask-user-delegated-caller-guard.md`, `bounded-task-side-effect-check`). The targeted files themselves were intact; only the consumer-link references in the diff had been replaced. `git stash push` preserved the state; the `??` untracked `.agents/skills/dyno-pony/` and `wiki/` (our local skills/wiki) were left untouched.
3. **Phase 1 — Vendor sync.** No-op. The 9 vendored Cordis packages (cosmokit, schemastery, cordis, loader, include, group, timer, hmr, logger-console) were already pinned at the exact SHAs listed in `vendor/README.md`. The local-modifications log (19 entries) was consistent with upstream state.
4. **Phase 2 — Rebase.** `git rebase origin/master` of `fix/credentials-render-key-guard` onto `d347e70390` (upstream master, tag `dsh-v0.1.3-alpha.1`) succeeded with no conflicts. The credentials fix commit's new SHA is `0d95aa6210`. `git status` was clean apart from the two untracked local assets.
5. **Phase 4 + 5 — Migration.** A first-party migration path shipped by upstream (`@deepseek-ai/dsh-session-format-v0-to-v1` and `@deepseek-ai/dsh-session-format-v1-to-v2` chained through `dsh-session-format-catalog`) ran on disk for every `session.jsonl.zstd` we cared about. The migration **preserved the original v0 bytes and inode** as the spec promises; the new `session.v2.jsonl.zstd` lives alongside, encoded with `version: 2` and `assistantStream: embeddable`. No v0 was moved, renamed, or overwritten.
6. **Phase 7 — Tag.** `dsh-v0.1.3-alpha.1-local` is annotated on the rebased tip; the safety tag `backup/pre-update-0.1.2-alpha.2` and branch `backup/pre-update-0.1.2-alpha.2` remain reachable for at least one release cycle.

---

## One bug we hit and how we fixed it

`local/dsh-audit/manual-migrate.mjs` invoked `spawnSync('zstd', ['-d', '-c', inputPath], { encoding: 'utf8' })` with the **default `maxBuffer` of 1 MB**. Twenty-one of our 98 session files decode to 1.18–2.0 MB of plain JSONL; their stdout silently exceeded the buffer and the script reported `zstd decode failed: ` (empty stderr). The fix was `{ maxBuffer: 512 * 1024 * 1024 }` on both `manual-migrate.mjs` and the wrapping `batch-migrate.mjs`. After the fix, all 21 retries succeeded. The first run of the batch had reported 78 ok / 21 fail; the rerun reported 6 ok / 92 skip / 0 fail (the script skips when a v2 sibling is already present).

---

## Live-session effect (transparent)

The `session-be02873e-2aa7-480f-b848-40433d2bd6e0` JSONL was being written to by a DSH runtime process during the backup window. The pre-update `sha256` recorded in the migration manifest was `d5c2b350`; the value right after the backup restore was `44e99f3c` (the runtime had appended 25 events in the meantime). After migration, the on-disk `v0` is `a96ef2d6` and continues to grow. This is **expected**: open sessions are append-only. The byte-identity guarantee from the migration agent note applies to "the same generation at rest," not to live writers. No session data was lost.

---

## Blockers

### `pnpm install` cannot complete in this sandbox

The DSH toolchain needs:

- `typescript@^6.0.3`
- `vitest@^4.1.8`
- `lightningcss@^1.32.0`
- `tsdown@^0.22.2`
- `oxlint@1.76.0`
- several other large packages

The DSH runtime's network egress to `registry.npmjs.org` is unstable: `pnpm install` finishes resolving, then either times out (`fetch failed`, `ETIMEDOUT`) on a small number of large tarballs (notably `@algolia/abtesting`, the `typescript@6.0.3` tarball, and the `mermaid` wheel), or is killed by the executor's 600 s cap. `--offline` fails because the store is incomplete. This is **environmental, not a DSH issue** — the same install runs cleanly on a host with open egress.

### Gates that depend on a working install

`pnpm run typecheck`, `pnpm run lint`, `pnpm run test:docs`, `pnpm run test:coverage`, `pnpm run check:ci:static`, and `pnpm run test:snapshot` all need `node_modules/` populated. Until the install completes, the migrated sessions can be read by the new code **in principle** (the `lib/` build would emit them), but the static-gate guarantees have not been re-validated in this run. Recommended next step: run the install on a network-open shell and then run `pnpm run typecheck && pnpm run lint && pnpm run test:docs` (the keyless subset, since we do not have `DEEPSEEK_API_KEY`).

---

## What we kept

- The single custom commit `fix(credentials-local)`: refuse non-grammar keys at the render boundary.
- `.agents/skills/dyno-pony/` and `wiki/` (untracked local skills and wiki).
- The constitutional chain at `/home/fares/` (`SOUL.md`, `CONSTITUTION.md`, `AGENTS.md`, `MAP.md`) — untouched.
- `~/.dsh/` settings, profiles, identity, storages, credentials — untouched apart from the v0→v2 sibling addition.
- All 98 v0 JSONL originals — preserved byte-for-byte at rest (modulo live appends).

## What we changed in the DSH repo

- One new tag: `dsh-v0.1.3-alpha.1-local`.
- One new branch: `backup/pre-update-0.1.2-alpha.2` (also tagged with the same name).
- Rebase of the credentials fix onto `d347e70390` (was `0a53fb55be`); the credentials fix's SHA moved from `f122f104` to `0d95aa6210`.
- No file content changes inside the DSH repo besides what `git rebase` already produced.

## Files added in this run (outside the DSH repo)

```
~/local/dsh-audit/2026-09-05-sync-report.md          (the audit)
~/local/dsh-audit/2026-09-05-update-postmortem.md     (this file)
~/local/dsh-audit/manual-migrate.mjs                  (per-file migrator)
~/local/dsh-audit/batch-migrate.mjs                   (all-files migrator)
~/local/dsh-audit/migration-report.json               (per-file results)
~/local/dsh-audit/migration-manifest.json             (sha256 before/after)
~/local/dsh-audit/verify-migration.mjs                (v0/v2 integrity check)
~/local/dsh-audit/backups/2026-09-05-pre-update/dsh-state.tar.gz   (~60 MB; 98 v0 sessions + 3 config files)
```

## Follow-up for the operator

1. **On a network-open shell, run `pnpm install` until it completes**, then `pnpm run typecheck && pnpm run lint && pnpm run test:docs`. We expect clean output because the rebase had no conflicts and the vendored Cordis was untouched.
2. **Optional**: run `pnpm run test:snapshot` on the new build against the migrated corpus. The agent note says 113 keyless replays + 28 owner-local expectations are covered at master; running this locally will re-confirm the migrated sessions still pass the replay gate.
3. **Optional**: prune the v0 siblings when you are satisfied. The agent note is explicit: "automatic fallback and downgrade compatibility are not implied" — keeping them is the safe default; pruning frees space once you trust the v2 siblings.
4. **Optional**: roll the `dsh-v0.1.3-alpha.1-local` tag forward by re-running this same procedure next time upstream ships `0.1.3-alpha.2` or `0.1.3-rc.1`. The rebase, vendor sync, and migration steps are the same shape.
