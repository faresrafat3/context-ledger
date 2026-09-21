# CONTEXT-SLIM INCIDENT — 2026-09-21 (lossless condensation pass across projects)

**What this file is:** the record of a cross-project condensation pass (agent: Cline), the three
pinned/protected-zone breaches it caused, their reverts, and one recovery — the *original* bytes
of `crew-research-council/PROTECTED.md`, believed lost. Authored, not law. Owner ruling line is
empty-by-right (§6).

## 1. What ran (Owner chat directive: reduce lines/chars, zero meaning loss)

| pass | scope | method |
|---|---|---|
| mechanical | ~69 live context files (README/AGENTS/PROTECTED/SKILL/PROJECT) | join soft-wrapped prose lines; tables/code/frontmatter untouched |
| semantic | same set | filler-phrase removal only; every fact, number, path, ID, command kept |
| frontmatter | dyno-pony `skills/*` | trim `whenToUse` restating `description` (procedure kept) |

Never touched: append-only logs (`Projects/notrick/CONTEXT.md`, crew `GOAL.md` log), frozen
`souls/**`, dossiers/wiki evidence, `.env`/secrets, any runtime tree.

## 2. Breaches found by audit, and the reverts (nothing silently fixed)

| # | file | breach | evidence (command) | action |
|---|---|---|---|---|
| 1 | `Projects/notrick/AGENTS.md` | unlogged edit of one of `INTEGRITY.md`'s 44 pinned files; moved line ranges → broke 38 citations into it from pinned `research/*` | `sha256sum -c <(grep -E "^[0-9a-f]{64}" INTEGRITY.md)` → `./AGENTS.md: FAILED`; `tools/citecheck.sh` → 38 `out of 1..49` refs | `git checkout -- AGENTS.md`; re-check **44 OK / 0 FAILED**; citecheck back to **drifts=14** (pre-existing); file = 74 lines / 5018 B |
| 2 | `crew-research-council/RESEARCH-COUNCIL/README.md` + `RESEARCH-COUNCIL/OUTPUT/README.md` | in-place edits inside the protected `RESEARCH-COUNCIL/**` glob (CONSTITUTION §2 + project PROTECTED.md) | `git status` showed ` M` on both (clean at session start) | `git checkout --`; `diff -q` vs pre-session backup = byte-identical |
| 3 | `crew-research-council/PROTECTED.md` | soft-wrap reflow touched the filed declaration *after* its commit | working blob `c15c6185…` ≠ HEAD blob `f17a238d…` | `git checkout -- PROTECTED.md` → back to committed reconstruction `f17a238d…` |

**Ruling this validates** (CONSTITUTION §2, verbatim): "Editing one in place is not a
compression trade-off; it is tampering." Condensing a line-cited pinned file is a
*citation-breaking act* — 38 refs proved it here.

## 3. Recovery — the lost crew PROTECTED.md ORIGINAL

A pre-edit backup (taken 2026-09-21 ~07:12, before any edit of this pass) holds the original
bytes the reconstruction note (`PROTECTED.md:7-14`) describes as unrecoverable:

| property | value |
|---|---|
| bytes | **2375** · lines **41** — matches the reconstruction note's own description exactly |
| sha256 | `a12092df17090b6660206caf31e72d61b7e7d3e28663eb85bd5925cc743d1bf3` (closes the "hash is unknown" gap) |
| copy | `local/compliance/evidence/crew-research-council-PROTECTED.original-20260921.md` (kept verbatim) |

Not adopted silently: whether the reconstruction floor is replaced by the original is the
Owner's ruling; the committed reconstruction stays in place until then.

## 4. What remains condensed (all inside declared safe write-paths)

**Same 70-file set (apples-to-apples vs pre-edit backup):** 5077 → **4740** lines (−337) ·
333,779 → **324,689** chars (−9,090). Reverted out of that count: notrick `AGENTS.md`, crew
`RESEARCH-COUNCIL/README.md` + `OUTPUT/README.md`, crew `PROTECTED.md` (§2).

**Beyond that set** (all in declared safe write-paths):

| file(s) | before → after |
|---|---|
| crew `TEST-POLICY.md` | 211 → 160 lines (+ Iron Law §3 and all 14 section numbers intact) |
| crew `TESTING-COUNCIL.md` | 137 → 104 |
| crew `VOICES.md` | 115 → 55 (16 entities, 16 Forms, catalog all present) |
| crew `v2-ARCHITECTURE.md` | 99 → 64 |
| dyno-pony `AGENT-ERGONOMICS.md` | 145 → 91 |

Kept: notrick README/research-README/tools-dsh-README (citation-checked, zero new drift) ·
dsh-plugins READMEs + PROTECTED (**now committed by the concurrent lane as `f8253d6`,
message: "rewrap the README/PROTECTED paragraphs (no semantic change)"**) · dyno-pony
README/PROTECTED/AGENT-ERGONOMICS/12 SKILLs · knowledge-factory README/PROTECTED · crew
README/PROJECT + the 4 files above · anatomy-lab README/PROTECTED + its colony-kernel copy ·
testing-council README.

Deliberately **not** touched: anatomy-lab `docs/colony-kernel-v0.1.1.md` (pinned by
`independent-review-input/MANIFEST.json`, sha256 `d3c8e715…`), knowledge-factory `design.md` +
`wiki/`, dyno-pony `docs/ANALYSIS.md` + `docs/ARCHITECTURE.md` (fact-bearing historical
records — see §7), all append-only logs, all frozen SOULs.

## 5. Gates re-run after the reverts

| gate | result |
|---|---|
| NOTRICK pins | 44 OK / 0 FAILED |
| NOTRICK citecheck | files=158 · refs=1134 · drifts=14 (pre-existing only; the 38 my edit created are gone) |
| Colony Kernel `npm run verify` | ALL GATES GREEN |
| dsh-plugins `scripts/gate.sh` | GREEN — fail 0 · warn 0 |
| dsh-plugins `--snapshot` | GREEN (an interim RED was the concurrent lane's dspy-lab edits, re-frozen by them, not this pass) |
| dyno-pony oracle | preflight 15/0 · full suite 183/0 |

## 6. Owner ruling

__________ (empty-by-right)

## 7. Follow-ups observed (filed, not fixed)

1. **[RESOLVED — see §8 D9]** Stale facts in dyno-pony `docs/` (`ARCHITECTURE.md` claimed "10
   dynamic Cordis plugins + 10 DSH skills + 4 agent presets"; `ANALYSIS.md` marked `codex`/
   `workflow`/`memory` "proposal — not yet built" though all shipped). Resolved by **annotation,
   not rewrite**: both docs now open with a dated **Historical snapshot** banner pointing at the
   live truth (README · `counts.cjs` · `AGENT-ERGONOMICS.md`); the period text stands unchanged.
2. **[RESOLVED — see §8 D1–D6]** Three git stashes held pre-session WIP (created before this pass
   to protect uncommitted work): `colony-kernel`, `dyno-pony`, `crew-research-council` — all named
   `WIP-before-context-slim-20260921`. Every byte was restored or superseded and committed; the
   stashes were then dropped with their identities recorded (§8).
3. **Concurrent writer** (same workspace) committed this pass's dsh-plugins condensation under
   `f8253d6` and re-froze the dspy-lab snapshot; its description matched what the bytes show.

## 8. Decisions taken under delegation (Owner: "القرارات عندك"; revocable in one line — R8 pattern)

| # | decision | evidence / landed as |
|---|---|---|
| D1 | crew: **adopt the original `PROTECTED.md`** (41 L / 2375 B, sha256 `a12092df…`) as operative; the interim reconstruction (`f17a238d`, commit `9304650`) stays in git history; the supersession is filed as a dated document beside it (their own rule) | commit `726049b` + `PROTECTED-RECOVERY-20260921.md` |
| D2 | crew: restore `missions/CREW-EVIDENCE/{BOARD.md, 2026-09-20-EVIDENCE-RECOVERY.md}` (swept out by the pre-edit `stash -u`) **and track them** — the one-copy failure mode already bit once | commit `726049b` |
| D3 | crew: restore the 2026-09-20 BLACKBOARD mission append (HEAD held the 2026-09-13 empty board; the stash was the only carrier) | commit `726049b` |
| D4 | dyno-pony: **restore, don't discard** the stashed seam-check work — preflight gains 2 tests (dynamic `actions:` must resolve in the bundle, both ways for homonym tools; every "N tools" claim held to disk) and the merger now mounts what it wrote (`38 registered / 38 declared`, exit 1 on mismatch) | commit `0d26a9f`; suite 185/0 |
| D5 | colony-kernel: keep this pass's condensation and adopt the stash's condensed "What this project is" paragraph + `README#why` link; `npm run verify` green before commit (R3) | commit `142fec0` |
| D6 | Drop all three stashes after full restore/supersession; identities recorded for traceability: colony `24f1eb29` (base `7b49a64`) · dyno `6e9beec7` (base `e48e908`) · crew `f3f84966` (base `221713d`) | this file; `stash list` = empty ×3 |
| D7 | Everything above is **committed, not left in working trees** — uncommitted work is what made this incident possible; same principle applied to crew `missions/` (now tracked) | `726049b` · `0d26a9f` · `142fec0` |
| D8 | notrick: commit the three unpinned condensation edits; **correct the commit message's line-counts to the measured values** (80→64 / 51→41 — the first message said 74/43) before any push; an inaccurate record is worse than a late one | commit `168052e` (amended from `47dd685`) |
| D9 | dyno-pony: annotate — never rewrite — the two stale docs with dated **historical-snapshot** banners pointing at the live truth | commit `b5c52b6` |
| D10 | notrick: **file V-004** in `violations.md` for the unlogged pinned-`AGENTS.md` edit — "a violation corrected without a record did not happen"; the entry itself breaks `violations.md`'s frozen hash (append-only-under-pinning = pr-013's exact tension) and is left **visible, unrefreshed** | commit `194c32a`; pin check then 43 OK / 1 FAILED |
| D11 | notrick: **resolve D10 by applying pr-013 option A** — exempt `violations.md` from the pin set by rule (the CONTEXT.md precedent: a mandated-append ledger cannot hold a stable hash). Header 44→43; hash line removed; Exemptions section + moment block in `INTEGRITY.md`; counts fixed in notrick README + `CONSTITUTION.md` §2; citecheck run with the moment (drifts unchanged at 14). Delegated decision (Owner line, verbatim: "القرارات عندك continue"), revocable in one line; pr-013's Owner ruling line stays empty-by-right | commit `b60ae35`; pins **43 OK / 0 FAILED**; audit card confirms |

**Nothing open.** The one deliberate red pin (D10) is resolved by D11; every pin re-verifies
43 OK / 0 FAILED and `tools/audit.sh` renders it. pr-013 now has its requested option applied —
its formal Owner ruling line remains empty-by-right — and every decision D1–D11 is revocable in
one line. §6 ruling line stays empty-by-right.




