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

## 8. Addendum (same day, after §1-§7 were written): nine repositories, not one — the replica recipe

The `--recover` walk that closed this round was run against a scratch replica of `$HOME`, never
against the workspace. It proved the plan → `--yes` → verify flow on realistic state (a committed
deletion of a declared document, restored and hash-verified), and it falsified the naive reading
that `local/` *is* the workspace: the declared surface spans **nine repositories**, and the tool
resolves every one of them from `$HOME_DIR`, never from its own location.

### 8.1 Topology

| repository | declared rows it holds |
|---|---|
| `$HOME` — the root repo, tracks exactly `.gitignore` and `CONSTITUTION.md` | 1 |
| `local/` — the ledger repo (ceilings, digests, receipts, this tool) | 0 — audited by the ledger layer, not by a digest row |
| `anatomy-lab/` | 2 |
| `crew-research-council/` | 2 |
| `Projects/notrick/` | 7 |
| `Projects/deepseek-harness/` | 5 |
| `Projects/colony-kernel/`, `Projects/dyno-pony/`, `Projects/knowledge-factory/` | 3 each |

26 digest rows in all, every one `bind=committed`. Three further repos under `$HOME` —
`.nvm/`, `.hermes/hermes-agent/`, `Projects/dsh-plugins/` — hold no declared row and are not part
of the audited surface (`discover()` excludes `.hermes` by path filter regardless).

### 8.2 The trap the recipe exists to avoid

`HOME_DIR="${HOME_DIR:-${HOME}}"` (line 88). `CONSTITUTION`, `CEILINGS`, `OUT`, `abs_of`, the
`discover()` scan and every probe/ledger-layer `git -C` hang off it. So a clone of `local/` run
without an env override does not audit the clone — it audits the **real home**. The walk's first
two attempts did exactly that and reported on live state; the tell was `--digests` saying `ok` for
a document the clone did not contain, next to a green baseline. A scratch test that measures the
live workspace is worse than no test: it looks like evidence.

**Closed in code the same day:** `live_home_guard` refuses (exit 2) when `HOME_DIR` is unnamed and
the running copy's own root — home-shaped, ledger and all — is not the home being audited. The
recipe below works because it names `HOME_DIR`; the guard carries its own two assertions in
`--self-test`, and `--help` / `--self-test` stay usable from any copy since they never audit.

### 8.3 The recipe (re-run and verified 2026-09-21)

```bash
R=$(mktemp -d /tmp/rec-repl.XXXXXX)/home && mkdir -p "$R"
git clone -q /home/fares "$R"      # outer repo FIRST — CONSTITUTION.md must land at the replica root
for d in local anatomy-lab crew-research-council \
         Projects/colony-kernel Projects/deepseek-harness \
         Projects/dyno-pony Projects/knowledge-factory Projects/notrick; do
  git clone -q "/home/fares/$d" "$R/$d"
done
cd "$R/local" && HOME_DIR="$R" bash "$R/local/scripts/context-audit.sh" --check   # baseline
```

Baseline at the commit set cloned (root `acabaad`, `local` `f72045b`, `anatomy-lab` `e20b65f`,
`crew-research-council` `726049b`, `colony-kernel` `142fec0`, `deepseek-harness` `e32dad2447`,
`dyno-pony` `441ee0c`, `knowledge-factory` `86d0557`, `notrick` `b60ae35`): **exit 0**,
`over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0`. Plant
losses, observe findings and run `--recover` only inside `$R`; the real workspace is read once per
clone and never written.

Two constraints the recipe carries: clone exactly the repos that hold declared rows and the ledger
repo (the ledger layer checks the declaration, the recording and the tool are each committed —
so a replica with local scratch edits in `local/` is red for that reason, as designed), and clone
them at their relative paths, since resolution walks *upward* from each document's directory
(`repo_of`), so a repo cloned to the wrong depth resolves to an ancestor repo instead — and the
ledger layer reports that as `untracked` / `no-repo`, a failure rather than a quiet green.

This addendum postdates §1-§7 and is committed on its own; like the receipts themselves it is a
governance record, not declared in `ceilings.tsv` (round-4/5 precedent), so its bytes are proven by
this repository's history rather than by a digest row.
