# RECEIPT — round 6 (2026-09-21): the audit's remedy becomes executable, then is cut in half

**What this round is:** `--recover <path>` — the GONE finding's remedy made executable — followed by a
scope-cut pass that removed half of what the first working version accumulated, with the design argument
recorded so it survives the code. Authored, not law. Owner ruling line empty-by-right (§7).

## 1. Commands + exits

| command | exit | what it established |
|---|---|---|
| `bash -n context-audit.sh` | 0 | syntax clean at every intermediate step |
| `context-audit.sh --self-test` | 0 | the standing battery passes **plus thirteen new --recover assertions** |
| `git` commit `25a49a4` | 0 | the mode lands: +120/−2 in `scripts/context-audit.sh`, staged by explicit path, diff skimmed for strays first |
| `context-audit.sh --record` | 0 | 26 docs, 0 changed — rows rebound to the --recover commit |
| `git` commit `9bc48f9` | 0 | re-recorded ledger committed |
| `context-audit.sh --check` | **0** | `over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0` |

## 2. The recover mode — what changed and why

The round-5 probe only *named* remedies; this round executes one. Default is a plan:
`--recover <path>` prints the probe leg whose bytes survive, the remedy, the recorded sha256 and
blob id — and touches nothing (asserted by the self-test). `--recover <path> --yes` restores from
the recorded blob and **keeps the result only if it hashes back to the recorded digest**; a
mismatch is removed from disk and fails. A recovery the ledger cannot verify is not a recovery.

Refusals, each with its own message and exit 2: no digest row (nothing was ever recorded); the
path exists (ok/DRIFT belongs to the digest layer — `--recover` never clobbers); a protected
zone (deletions there are an Owner ruling, checked via the standing `is_protected`); no git blob
recorded (legacy 3-column row — refused, not guessed at); no trace anywhere (the probe's
`no-trace` verdict, stated plainly).

The one design decision worth keeping: **the plan executes only through the recorded blob.** The
probe's six legs name six places (commit, index, stash, reflog, history, unreachable), but every
leg matches *content* — bound rows by blob id, legacy rows by hashing candidates against the
recorded sha256 — so the bytes any leg found ARE the recorded blob. One restore mechanism instead
of six, and the final sha-verify is the same theorem stated as a check.

## 3. The scope-cut pass — half the mechanism, all of the guarantees

The first working version carried per-leg plumbing: `RLEG`/`RLOC` state, `sed`-parsing of the
probe's remedy prose to extract stash and reflog handles, and five fallback checkout arms
(`checkout --`, `checkout <commit> --` per leg). The content-addressing argument deleted all of
it: any leg that matched by content matched exactly the recorded blob, so the checkout arms could
only re-derive the same bytes — or produce bytes the verify step would remove anyway. Removed:
the handle parsing, the fallback arms, the leg-state globals, an 18-line fourth fixture whose
refusals the existing unreachable-fixture already reaches (its row degrades to legacy form right
where it reports no-trace), and a fixture-builder function called exactly once (inlined).
`recover_do` is now eight lines; the failure messages still name the leg-specific truth (e.g. the
recorded blob no longer existing).

The tests forced one tool truth into the open: **`protected_tokens` extracts zones only from a
`## …Protected…` heading followed by table rows** — a `PROTECTED.md` without the heading protects
nothing. The first protected fixture lacked the heading, the refusal never fired, and the restore
*executed* before the assertion caught it. The fixture now carries the heading; §6 records the
standing limit this exposes.

## 4. Provenance, disclosed

The first attempt at this feature ran in an earlier session that failed mid-turn. Its persisted
draft contained fabricated patch content — an unfinished patcher with literal placeholder strings
where code should be. Nothing from it was executed: the exact-match, abort-on-mismatch patcher
pattern (every anchor must occur exactly once or the whole patch is discarded) refused the draft
and everything in this round was built from code re-verified in-session. Recorded because the
receipt exists to make the ledger honest about what produced the bytes.

## 5. Commits this round

| commit | what |
|---|---|
| `25a49a4` | --recover: execute the remedy a GONE finding states — plan by default, --yes restores the recorded blob and verifies the sha256 (+120/−2) |
| `9bc48f9` | Re-record: digest rows bind to the --recover commit |

This receipt is committed but not declared — same standing as the round-4 and round-5 receipts;
`ceilings.tsv` is unchanged this round.

## 6. Honest limits

- **`--recover` restores only what verifies.** If the recorded blob is gone while a leg still
  holds the bytes (an index or stash after a prune), the tool refuses rather than restore
  unverified bytes. Making that case work means per-leg restore — deliberately cut this round;
  an Owner call if a real ledger ever hits it.
- **Verify-or-remove is strict.** A restore that does not hash back is deleted, not kept with a
  warning; a partial or corrupted restore never survives on disk.
- **`is_protected` depends on the `PROTECTED.md` format** (heading, then table rows). A malformed
  `PROTECTED.md` protects nothing — §3's fixture incident, left standing as a format contract.
- `recover_plan` displays the probe's evidence but does not re-derive it; only `recover_do`
  writes, and only after the blob's existence is checked.

## 7. Owner ruling

__________ (empty-by-right)
