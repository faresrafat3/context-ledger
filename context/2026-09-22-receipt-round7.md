# RECEIPT — round 7 (2026-09-22): the live-home guard learns identity, and the ledger gets a public address

**What this round is:** the guard added in round 6 decided by comparing path *spellings*, and three shapes
defeated that: a **symlinked copy** of the tool audited the live home, while an **aliased path to the live
home's own copy** and a **symlinked `$HOME`** each false-refused it. All three were the same defect — string
comparison standing in for identity — so the fix is one comparison, and the battery now asserts all five
shapes. Then the ledger was published, so its history can finally be reviewed as a pull request.
Authored, not law. Owner ruling line empty-by-right (§7).

## 1. Commands + exits

| command | exit | what it established |
|---|---|---|
| `bash -n context-audit.sh` | 0 | syntax clean at every intermediate step |
| `context-audit.sh --self-test` | 0 | the standing battery passes **plus five guard assertions** (was three, one of which restated another) |
| `git` commit `d161a51` | 0 | the fix lands: +25/−15 in `scripts/context-audit.sh`, staged by explicit path (never `add -A`) |
| `context-audit.sh --record` | 0 | 26 docs, 26 unchanged, 0 changed / added / carried / unbound |
| `git` commit `e689822` | 0 | re-recorded ledger committed by explicit path (1 line) |
| `context-audit.sh --check` | **0** | `over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0 hard_slop=0` |
| `gh repo create … --source … --push` | 0 | the ledger publishes as `context-ledger` (public), `main` tracking `origin/main` |
| `git clone` of the published repo + `--self-test` | 0 | the published bytes are functional: PASS, and the cloned script's sha256 is identical to the audited one |

## 2. Three defects, one cause

The round-6 guard resolved the copy's root with `dirname "$0"` and compared it to `HOME_DIR` as strings.
Probed through its real entry points, that produced three failures — each one exercised, then fixed:

| shape | before | after |
|---|---|---|
| symlink → a foreign copy (`~/bin/context-audit`), `HOME_DIR` unnamed | **audited the live home, exit 0** | refuses, exit 2 |
| aliased path to the live home's own copy (`/tmp/alias → $HOME`) | **false refusal, exit 2** | runs |
| symlinked `$HOME`, script at its canonical path | **false refusal, exit 2** | runs |

The fix is two resolutions and one comparison: `self=$(readlink -f "$0")` (a copy invoked through a
symlink is still that copy), `cd -P` on the copy's root **and** on `$HOME` (a home reached through an alias
is still that home), then `[ "$root" = "$home" ]`. One trap is recorded because it cost a pass: applying
`cd -P` to the *dirname* alone does **not** close the symlink case — the symlink is `$0`, not a path
component — and the naive fix still audited the live home. Only resolving `$0` first works.

## 3. What the guard refuses, and what it deliberately allows

Refuses (exit 2, before the first read, for all eleven entry points — `report`, `--list`, `--slop`,
`--write`, `--check`, `--strict`, `--discover`, `--density`, `--digests`, `--record`, `--recover … --yes`):
a home-shaped copy whose resolved root is not the home being audited, while `HOME_DIR` is unnamed. An empty
`HOME_DIR=` reads as unnamed, and the refusal precedes the load path (proved by making the law path bogus:
the guard's message still comes first) and every write (proved with `--write`: exit 2, the live
`REGISTRY.md` / `registry.tsv` / `slop.tsv` byte-identical after).

Allows, on purpose: the copy that lives inside the audited home; the same home reached through an alias; a
symlinked `$HOME`; a **bare copy that is not home-shaped**, which is treated as an installed command and may
audit the default home (verified exit 0 — the shape test is what keeps a global install usable); `--help`
and `--self-test` from any copy; and any run with an explicitly named `HOME_DIR`, which is the statement of
intent and is never second-guessed (cross-checked green against a fresh whole-home replica).

Degrades rather than breaks: where `readlink -f` is unavailable, the guard falls back to `$0` and behaves
like the round-6 version — verified with a stubbed `readlink`, which still refused a foreign copy instead of
crashing.

## 4. The delivery: a public address for the ledger

The repo carrying all of this had **no remote at all**, so no pull request could exist for it. It now
publishes as **https://github.com/faresrafat3/context-ledger** — public, default branch `main`, 27 files,
23 commits, `main` == `origin/main` == `e689822`. Before publishing, the tracked set was scanned for
secret-shaped content: no keys, tokens or credentials (the only `token` hits are the word in doc prose), the
only email is the self-test fixture's `fixture@invalid`, and `/home/fares` appears in six files, which is
username-level disclosure already implied by the account name.

Two decisions recorded because they are reversible and were mine: the repo is named `context-ledger` rather
than `local` (the directory name, meaningless in public), and the full history was pushed to `main` as the
import rather than rewritten into a synthetic branch. The consequence is stated plainly: **`main` is the
base**, so the guard work is published but not *reviewable as a diff* — this receipt, on branch
`receipt/round-7`, is the first pull request against it, and is where that review happens.

Disclosure, kept explicit: everything under `compliance/` and `context/` is now world-readable, including
`2026-09-21-context-slim-incident.md` and every round receipt. Publication was chosen with that on the table;
it is not undoable in the ways that matter (caches, forks, archives).

## 5. Commits this round

| commit | what |
|---|---|
| `d161a51` | Live-home guard: compare canonical identity, not path spelling — resolves `$0` and `$HOME`, fixes the symlink bypass and both false refusals (+25/−15) |
| `e689822` | Re-record: digest rows bind to the guard commit |
| *(on `receipt/round-7`)* | This receipt — committed but **not declared**, matching the round-4/5/6 precedent; `ceilings.tsv` is unchanged this round |

## 6. Honest limits

- **Staleness is the remaining exposure.** A clone made before `d161a51` still carries the old guard, and
  nothing tells its operator; the guard protects the copy that is running, not the copies that exist.
- **`readlink -f` is GNU.** Elsewhere the guard is symlink-blind rather than absent — a degraded guard is
  still a guard, but it is not the one asserted above.
- **"Where does this copy live" still has two owners:** `tool_abs()` (for the ledger layer) and the guard.
  Unifying them means changing the ledger layer's semantics for one saved line, so it was left as known
  duplication rather than touched.
- **`tool_abs`, `repo_of` and the bind layer compare paths lexically too.** They were not changed this
  round; the guard is the only place identity was made explicit.
- **The bare-copy boundary is a decision, not a law:** a copy that is not home-shaped may audit the default
  home silently. The alternative refuses legitimate installs.
- **The replica recipe** (round-6 receipt §8) remains the only honest way to exercise a change against
  realistic state; probing against the live home measures the wrong thing.

## 7. Owner ruling

__________ (empty-by-right)
