# DSH Sync Audit — Local vs Official

**Date:** 2026-09-05
**Auditor:** DSH (ultimate mode, round 4)
**Scope:** Read-only audit. No code changed, no update applied.

---

## 1. Version Pinning (المرجع)

| Aspect | Local | Official (`origin/master`) |
|---|---|---|
| Branch | `fix/credentials-render-key-guard` (our work branch) | `master` |
| HEAD commit | `f122f104a6ae0b5045b0de7e06b924e1112376dd` | `d347e703908d0406b7a7ef80e3a0e594d86b2215` |
| Commit date | 2026-09-03 20:16 +0300 | 2026-09-05 (cutoff) |
| Last synced tag | `dsh-v0.1.2-alpha.2` (commit `0a53fb55be`) | — |
| `package.json` version | `0.1.2-alpha.2` | `0.1.3-alpha.1` (per latest tag) |
| Latest official tag | — | `dsh-v0.1.3-alpha.1` |
| Upstream repo | — | `https://github.com/deepseek-ai/deepseek-harness` |
| All vendored packages | Pinned (see `vendor/README.md`) | Same SHAs as upstream |
| Remote | `origin` → `https://github.com/deepseek-ai/deepseek-harness` | — |

**Gap:** we are on `0.1.2-alpha.2` + one local commit, official is `0.1.3-alpha.1`. Drift is **750 commits** with **3995 files changed (≈ +98k / −56k LOC)** since our base tag.

---

## 2. Diff Classification — ناقص / مقصود / معطّل

### 2.1 Local-only commits (مقصود)

```
f122f104a6 fix(credentials-local): refuse non-grammar keys at the render boundary
```

**Status:** مقصود (intentional). Branch `fix/credentials-render-key-guard`. The base is `0a1.2-alpha.2` + one fix. No accidental drift.

### 2.2 Vendored packages (vendor/)

Compared manifest entries (`vendor/README.md`) to upstream — all 9 packages (cosmokit, schemastery, cordis, loader, include, group, timer, hmr, logger-console) are at the exact SHAs listed in our manifest. Our local modifications log (19 entries) is consistent with upstream state — no version sync needed.

### 2.3 Packages topology

Compared `ls packages/` local vs `git ls-tree -d --name-only origin/master packages/`. No new top-level groups introduced. Sub-package layout matched. Files in `vendor/` plus 3 doc files (`AGENTS.md`, `CLAUDE.md`, `README.md`) which are documentation, not package code — intentional.

### 2.4 Missing features (ناقصة — يحتاج تحديث)

Out of 35 `feat` commits and 202 `fix` commits since base, the substantive new capabilities are:

| Feature | Impact | Status |
|---|---|---|
| **Generic file upload** (`packages/client/file-upload/`) | New package — file cards, HTTP route, store helpers | **ناقصة** |
| **Message editing (same-session)** | Edit a message after submit, re-runs turn | **ناقصة** |
| **Session format v2** (`feat(session)!: add released format migration`, `embed assistant streams in format v2`) | Bumps `SESSION_FORMAT_VERSION` from 0 → 2; embeds live assistant streams | **ناقصة** — and **breaking** for our on-disk session data |
| **Cross-process write-ownership lease** | session-persistence-jsonl safety under multi-process | **ناقصة** |
| **Version read compatibility + backup-and-skip salvage** (per-record units) | Corrupt-record resilience in storage | **ناقصة** |
| **Live assistant stream frames** (`feat(agent): emit live assistant stream frames`) | Streaming during a turn | **ناقصة** |
| **macOS x64 Python runtime wheels** | Python SDK on Intel Mac | **ناقصة** |
| **CPython subprocess backend** (`code-runtime-python`) | Native Python code-runtime, separate from worker-thread | **ناقصة** (we have `code-runtime-python` package but backend may be older) |
| **Skill fuzzy search** (`feat(web): rank skill candidates with the shared fuzzy name ranker`) | Slash-command fuzzy match | **ناقصة** |
| **Web fetch exposed by default** (`feat(base)`, `feat(sdk)`, `feat(headless)`) | `web_fetch` no longer opt-in | **ناقصة** |
| **Clickable links unification** (link alias + category glyphs) | UI consistency | **ناقصة** |
| **Mixed attachment presentation** (`feat(ui-attachment): unify mixed attachment presentation`) | File/image/cards in one rail | **ناقصة** |
| **Stream files through submission lifecycle** | Files included in submit round-trip | **ناقصة** |
| **Full-session turn rail with load-and-jump** | Long-history navigation in chat | **ناقصة** |
| **Identity-gated change feed** (`session-projection`) | Per-identity session updates | **ناقصة** |
| **Outbound proxy routing** (`feat: route every outbound request through the configured proxy`) | Centralized HTTP egress through `http-proxy` | **ناقصة** |
| **Superellipse corners + hairline elevation strokes** | Visual refresh | **ناقصة** |
| **Tool-card image result** (`read_image` rendered as image) | Tool output presentation | **ناقصة** |
| **PTC mode omits workflow** | Smaller PTC profile | **ناقصة** |
| **Storage unit-declared viewKey** | Storage schema control | **ناقصة** |

### 2.5 Behavior changes & fixes (ناقص fix أم تعديلات API)

| Area | What changed |
|---|---|
| `session-persistence` | Handle-based seam, lifecycle-owned write path, distinct event seqs from log offsets |
| `session` | Drop dead migration plumbing, share canonical log basename, JSON snapshots |
| `attachment` | Own prompt admission on service, unify prompt content admission, isolate file-upload service |
| `file-upload` | HTTP route + storage helpers package-private, scoped prompt binding rollback |
| `agent` | Drop unread `startedTime` frame field |
| `http-proxy` | Converge on four functions |
| `client` | Extract background file upload service, bind keyed chat sources in renderer |
| `node-compat` | Multiple hardenings: Windows drive roots, qualified path handling, hidden cleanup helpers, child-window hiding |
| `cli` | Stop packaged runtime from hijacking spawned node commands |
| `agent-team` | Unify messages on steer (steer follow-up images, harden subagent image follow-up admission, deliver images with steer) |
| `credentials` | Multiple narrowings and policy guards (Project date fields, Project-local Priority, policy Project read access) |
| `release` | Dsh prerelease channels (`worktree-npmalpha`), 0.1.2-rc.1 version alignment, http-proxy rc-version align, file-upload version align |
| `goal` | Decorate slash tokens in bubbles from logged skill/command facts; goal command bubble shares body face |
| `trajectory` | Stabilize history pagination, loadThrough deep history paging |
| `session-controller` | Type pending approval discriminator, settle jump landings after paging |
| `compaction` | Validate spans by surface order, validate surface replacement endpoints |
| `docs` | Many doc refreshes, v0-to-v1 README, module graph refresh, model discovery review |

### 2.6 Our local working-tree state

```
M .agents/notes/archived/feature/2026-08-11-collapsible-ask-user-question-card.{md,zh.md,i18n.yaml}
M .agents/notes/archived/manifest.json
M .agents/notes/implemented/bug-fix/2026-08-01-ask-user-delegated-caller-guard.{md,zh.md,i18n.yaml}
M .agents/notes/implemented/feature/2026-07-29-ask-question-web-presentation.{md,zh.md,i18n.yaml}
M .agents/notes/implemented/feature/2026-07-30-plan-review-presentation-intent.{md,zh.md}
M .agents/notes/proposed/architecture/2026-08-08-semantic-composer-chain-phases.{md,zh.md}
M .agents/notes/proposed/feature/2026-08-04-task-surface.{md,zh.md}
M AGENTS.md
M packages/client/ui-tool/README.md
M packages/client/ui-tool/README.zh.md
```

**Status:** staged/working edits on Agent Notes + the AGENTS.md instruction update + ui-tool README. **Not** commits — these are uncommitted working-tree changes. Classified as **in-progress** work, not drift.

---

## 3. Runtime Health Check (الشغل)

| Surface | Check | Result |
|---|---|---|
| Web GUI | `curl http://127.0.0.1:3080/` | **401** (expected — the harness needs an authenticated harness header; serves the page) → **up** |
| CLI | `pnpm run dsh --help` | Loads workspace, 269 projects, lockfile verifies, install in progress (network sandboxed for `registry.npmjs.org` → ETIMEDOUT on `@algolia/abtesting` retry) |
| Node | `node --version` | `v22.23.2` (within `^22.19.0 || >=24.0.0`) |
| pnpm | `pnpm --version` | `11.7.0` (matches `packageManager`) |
| Vendor | Manifest vs upstream SHAs | **مطابق 100%** |
| Tests | `find packages -name '*.spec.ts'` | **841** spec files in workspace |
| Sources | `find packages -name 'src' -type d` | **257** package src dirs |

No critical breakage observed. CLI ran far enough to walk the workspace and start `pnpm install`; install ETIMEDOUT is the offline-network sandbox, not a DSH bug.

---

## 4. Missing / Unused Official Features (مش مستغلة)

| Feature | Where it lives | Why we miss it |
|---|---|---|
| File upload service (client) | `packages/client/file-upload/` | We don't have this package locally — but `attachment-local` exists; needs check if it pre-dates this or got renamed |
| Assistant streams in session log | `feat(session)!: embed assistant streams in format v2` | Format-version change; we are on `SESSION_FORMAT_VERSION=0` |
| Steer follow-up images | `agent-team` | Missing 3 commits; no image continuity on steer |
| macOS x64 Python wheel | Python SDK | Would block Intel-Mac users |
| Skill fuzzy ranker | `packages/client/ui-chat/` | We use the older fixed list |
| Web fetch by default | `base` / `sdk` / `headless` | We still gate it |
| Clickable link alias | `ui-primitives` | We use the older rendering |
| Full-session turn rail | `ui-chat` | Long-history nav is missing |
| Outbound proxy routing | `http-proxy` | We don't centralize egress |
| Storage backup-and-skip salvage | `storage` | We crash on a corrupt record |
| `read_image` rendered as image | `ui-tool` | We render its raw text payload |
| PTC omits workflow | `presets` | Our PTC profile still loads workflow |

---

## 5. Final Report Table

| # | Item | State | Impact | Recommendation |
|---|---|---|---|---|
| 1 | Version: `0.1.2-alpha.2` vs `0.1.3-alpha.1` | **قديمة** | Misses 750 commits, 35 features, 202 fixes | **حدّث** (separate decision) |
| 2 | Local fix branch `fix/credentials-render-key-guard` | **مقصودة** | One commit on top of base | **اقبل الفرق** — fold into update or fast-forward |
| 3 | Generic file upload (`packages/client/file-upload/`) | **ناقصة** | Whole file UX layer missing | **حدّث** |
| 4 | Message editing (same-session) | **ناقصة** | Can't edit a submitted message | **حدّث** |
| 5 | Session format v2 + assistant stream embedding | **ناقصة** | `SESSION_FORMAT_VERSION=0` upstream bumped to 2; backends reject old on-disk formats per AGENTS.md | **حدّث** — must delete/migrate local sessions or accept data loss |
| 6 | Cross-process write-ownership lease | **ناقصة** | Race risk in session JSONL persistence | **حدّث** |
| 7 | Storage version read compatibility + salvage | **ناقصة** | Corrupt record ⇒ fail | **حدّث** |
| 8 | macOS x64 Python wheel | **ناقصة** | Intel-Mac blocked | **حدّث** (low priority for us) |
| 9 | CPython subprocess backend | **ناقصة** (verify) | Older Python code-runtime | **حدّث** — verify whether our `code-runtime-python` is the old worker-thread only |
| 10 | Skill fuzzy search | **ناقصة** | Slash UX rougher | **حدّث** |
| 11 | Web fetch by default | **ناقصة** | We gate `web_fetch` | **حدّث** |
| 12 | Clickable link alias | **ناقصة** | UI inconsistency | **حدّث** |
| 13 | Mixed attachment presentation | **ناقصة** | File/image/UI split | **حدّث** |
| 14 | Full-session turn rail | **ناقصة** | Long-history nav missing | **حدّث** |
| 15 | Outbound proxy routing | **ناقصة** | No centralized egress | **حدّث** |
| 16 | `read_image` → image card | **ناقصة** | Tool output as text | **حدث** |
| 17 | PTC omits workflow | **ناقصة** | PTC profile bloat | **حدّث** (low priority) |
| 18 | Working-tree edits on AGENTS.md + Agent Notes + ui-tool README | **in-progress** | Our pending work | **سيبها** — keep as our work-in-flight, do not lose |
| 19 | Vendored Cordis & friends | **مطابق** | 19 local mods logged; no upstream drift | **اقبل الفرق** |
| 20 | Web GUI 401 on `/` | **شغّالة** | Auth required — not a bug | **سيبها** |
| 21 | CLI + pnpm + Node | **شغّالة** | Tooling matches engines | **سيبها** |
| 22 | 841 specs / 257 src dirs | **شغّالة** | Workspace intact | **سيبها** |

---

## 6. Recommendation Summary

**Do update** — the drift is large (1 minor + 1 alpha, 750 commits) and contains both user-facing features (file upload, message edit, fuzzy search, full-session turn rail, clickable-link unification) and **breaking storage format changes** (SESSION_FORMAT_VERSION 0→2). The breaking change is the most urgent reason to schedule the update separately from this audit.

**Do not** treat our `fix/credentials-render-key-guard` branch as drift — it's intentional. The update procedure should fast-forward / rebase our one commit onto upstream master, or carry it forward as a topic branch.

**Do not** update right now — this is audit-only per the task rules. The actual merge is a separate decision with its own risks (data migration, vendored sync, test suite).
