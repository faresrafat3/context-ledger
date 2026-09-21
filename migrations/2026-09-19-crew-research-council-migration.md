# Crew Research Council — repository migration closeout

**Date:** 2026-09-19
**Repo:** `~/crew-research-council` (GitHub: `faresrafat3/crew-research-council`)
**Head:** `221713d`

---

## 1. What was wrong

The git repository was rooted at **`$HOME`** — the entire home directory. Consequences:

- Every application wrote into the working tree (Firefox alone accounted for 5,511 visible untracked files).
- `.git` was **4.7 GB**, of which only **1.13 MiB** was real history: 1.35 GiB of loose
  objects plus a single **3.33 GiB garbage object** left by an earlier `git filter-repo` run.
- 22 branches existed only locally — a fresh clone from GitHub would have destroyed them.
- Secrets sat inside the repo boundary (`.9router/`, `VPNs/vpn_creds.txt`,
  `.config/**/secure-token-storage.json`); only `.gitignore` kept them out of history.

## 2. Before / after

| | Before | After |
|---|---|---|
| Repo root | `$HOME` | `~/crew-research-council` |
| `.git` size | 4.7 GB | **1.6 MB** |
| Junk objects | 1.35 GiB loose + 3.33 GiB garbage | 0 |
| Commits | 2103 | 2105 |
| Tracked files | 54 | 52 |
| Branches | 23 (22 unpushed) | 23, all on GitHub |
| Linked worktrees | 2 (outside the repo) | 0 |
| `.gitignore` | 92 lines defending `$HOME` | 58 lines scoped to the repo |
| Files tracked inside `.hermes/` | 2 | 0 |
| Disk used | 124 G | 120 G (~4 GB reclaimed) |

## 3. Steps taken

1. **Backup** — `git bundle` of all 23 branches (1.1 MB) before touching anything.
2. **Freeze** — stopped `openresearch.service` + `openresearch-autopilot.timer`; removed the two
   linked worktrees (both verified clean, tips preserved).
3. **Clone** — `git clone --no-local` → reachable objects only, so the junk was left behind.
4. **Verify** — all 23 branch tips, tree hash `a4ddf3996b5bb97a5f096288b49ae297f3f3984b`,
   2103 commits, 54 tracked files, before deleting anything.
5. **Retire** — removed `$HOME/.git`, the 16 duplicate root `.md` files, and the duplicate
   `RESEARCH-COUNCIL/` trees (each proved byte-identical first).
6. **Re-point the agent** — `orx` project `repo_path` `/home/fares` → `/home/fares/crew-research-council`,
   then renamed the project `anatomy-lab` → `crew-research-council` (name + slug) and updated
   `autopilot/config.json` in the same step.
7. **Two follow-up commits** — `e3d8f8b` (`.gitignore` rescoped), `221713d` (`.hermes` untracked).
8. **Push** — all 23 branches; final `main` = `221713d`.
9. **Delete the bundle** — only after cloning fresh from GitHub and proving tree hash
   `f39bd6d3827dc86139995e376871a00a543c6444` and 52 files were identical.

## 4. Verification technique that mattered

Verification used **tree hashes**, not commit counts. A matching commit count can hide a
divergent tree; `git rev-parse HEAD^{tree}` comparing both sides proved byte-identity.
Each destructive step was guarded: the deletion script aborted unless every file was
provably replicated, and it reported `guard=0` / no `ABORT:` lines.

## 5. Corrections made during the session

Recorded because each was a wrong claim I had to retract after better evidence:

| Claim | Reality |
|---|---|
| "`openresearch-autopilot` caused the untracked count to rise" | Wrong. It writes to `.local/`, which is already ignored; it could not shift an `--exclude-standard` count. The rise came from Firefox and the Freebuff client. |
| "`run_command: bash run.sh` is dangling" | Wrong. I had checked only `main`. All 22 experiment branches carry `run.sh` **and** its dependencies (`crew/`, `tests/`, `tasks/`, `harness/`, `pyproject.toml`). Executed it: 10/10 tests pass, eval runs. |
| "`main` has no upstream configured" | Wrong. `main` tracks `origin/main`. The old repo's `main` had none; the clone set it. |
| "`STATUS.md` divergence needs a content decision" | Resolved by history: canonical is `RESEARCH-COUNCIL/STATUS.md` (advanced in `72e3132`); the `.hermes` copy was the pre-`a22aa40` revision. |

## 6. Aligned backlog

### Closed

| Item | Outcome |
|---|---|
| Repo boundary out of `$HOME` | ✅ `~/crew-research-council` |
| 4.7 GB junk | ✅ 1.6 MB `.git` |
| 22 unpushed branches | ✅ backed up, pushed, verified |
| `.gitignore` rescoped | ✅ `e3d8f8b` |
| `.hermes` duplicates untracked; canonical chosen | ✅ `221713d` |
| `.hermes` partial mirror (2/35) | ✅ full 35/35 mirror, `diff -r` identical |
| `orx` project re-point + rename | ✅ name/slug/config all `crew-research-council` |
| Services | ✅ active; dashboard HTTP 200 |
| `run.sh` contract | ✅ verified by execution — no change needed |
| Redundant bundle | ✅ deleted after independent GitHub clone verification |
| Secret exposures (`.9router`, `VPNs/`, `.config/`) | ✅ **structurally resolved** — all now outside any git repo |
| Defensive `.gitignore` at `$HOME` | ✅ default-deny tripwire added; sandbox-tested |
| `.hermes` mirror drift | ✅ `local/scripts/sync-hermes-mirror.sh`; drift detection + repair verified |

### Open

| # | Item | Severity | Recommendation |
|---|---|---|---|
| 1 | **Ambient `gh` credential.** `credential.https://github.com.helper = !/usr/bin/gh auth git-credential`, token scopes `repo`, `workflow`, `gist`, `read:org`. Any process on this machine can write to every repo as `faresrafat3`, without prompting and without leaving a trace in the pushing clone. | **High** | Give automated tools a fine-grained repo-scoped token instead; keep `gh` for interactive use. |
| 2 | **`orx` publishes branches on startup.** 22 branches appeared on GitHub 8 s after `orx up` started, bursting within 5 s. `orx`'s binary contains GitHub push/sync code. `github_sync_enabled=0` does not appear to gate it. | Medium | Find orx's config for startup publishing; disable if unintended. |
| 3 | **Harness not on `main`.** `main` is doctrine-only; `run.sh` + `crew/` + `harness/` + `tasks/` + `tests/` live per-branch. New experiments start without them. | Low | Design decision: merge the harness into `main`, or keep the agent-creates-it contract. |



## 7. Operational notes to carry forward

- **Any `orx` CLI command auto-starts its daemon.** This silently un-froze the service mid-migration
  (`NRestarts=0`, a fresh start at 10:57:16). Do DB work via direct `sqlite3`, not the CLI, and check
  `systemctl --user is-active` afterwards.
- **`orx project edit` only accepts `--name` and `--run-command`.** `repo_path` and `slug` require
  direct DB writes. Back up `orx.db` first (`backup/orx.db.pre-*`).
- **Worktrees pin branch tips.** Remove them before moving a repository, and check them for
  uncommitted work first.
- **`gh` credentials make machine-originated pushes look human.** `pusher_type: user` and
  `actor: faresrafat3` are not evidence a person pushed.

## 8. Recovery references

| Asset | Location |
|---|---|
| Pre-repoint `orx.db` | `.local/share/openresearch/backup/orx.db.pre-repoint-20260919-110152` |
| Pre-rename `orx.db` | `.local/share/openresearch/backup/orx.db.pre-rename-20260919-110943` |
| Pre-rename autopilot config | `.local/share/openresearch/backup/autopilot-config.pre-rename-20260919-110943.json` |
| Bundle | deleted — superseded by GitHub (verified byte-identical before removal) |
| `$HOME` tripwire | `/home/fares/.gitignore` (dormant, default-deny) |
| Mirror sync script | `/home/fares/local/scripts/sync-hermes-mirror.sh` |
| GitHub | `faresrafat3/crew-research-council`, 23 branches, `main` = `221713d` |
