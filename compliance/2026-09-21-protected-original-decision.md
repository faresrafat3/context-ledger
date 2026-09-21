# PROTECTED original vs the committed reconstruction — the decision, 2026-09-21

**What this file is:** the independent verification behind adopting the recovered original
`crew-research-council/PROTECTED.md` over the interim reconstruction, and the diff between them.
Authored, not law. It carries evidence, not narrative.

## The question

The original declaration (created 2026-09-20) vanished before it was ever committed. An interim
reconstruction was committed in its place (`9304650`) as a marked floor. The original bytes were then
recovered. The decision put to this audit was: **replace the reconstruction, or keep both with the diff
recorded?**

## Ruling

**Replace, with the supersession recorded** — and *not* two live declarations side by side. Two files
both claiming to be the declaration is a second home for one fact, which `CONSTITUTION.md` §2 forbids;
the declaration's own rule already names the correct mechanism: *"Add a new dated document beside it and
record the supersession."* That is what the repository now holds, and the audit's verdict is that the
executed shape is the right one:

| artifact | status | where |
|---|---|---|
| original bytes — **adopted** | live declaration | `crew-research-council/PROTECTED.md` (blob `5b8cc782…`, sha256 `a12092df…`, 41 L / 2375 B) |
| supersession record — dated sibling | live record | `crew-research-council/PROTECTED-RECOVERY-20260921.md` |
| interim reconstruction — **superseded** | history only | `9304650:PROTECTED.md` (sha256 `f17a238d…`). No file on disk *presents itself as* the declaration; the text survives only as quoted evidence, in this record and in `local/context/2026-09-21-receipt.md` |
| evidence copy | byte-identical to the adopted file | `local/compliance/evidence/crew-research-council-PROTECTED.original-20260921.md` |

So both halves of the question are satisfied, in the order that matters: the *declaration* is the
original, and the *reconstruction* survives as history rather than as a rival.

## Measured consequences of the swap

| axis | reconstruction | original | reading |
|---|---|---|---|
| protected zone **paths** | 3 rows | the **same 3 rows** | protection not narrowed |
| "Why" column | shorter | fuller, with the `OUTPUT/**` scope named | information recovered |
| safe write-path | 2 documents | **16 documents, 16/16 present on disk** | edit rights **widened** — the material change |
| the gate section | `**None** — there is no build gate in this project` | `TEST-POLICY.md` §3 Iron Law + board protocol + `README.md` board rule | a real discipline restored |
| incident preamble in the file | present | absent | see below |

Two of those deserve to be said plainly:

* **The replacement is not protection-neutral on every axis.** Zone paths are identical, but the safe
  write-path grows from 2 documents to 16, and all 16 resolve on disk (verified below). Fourteen
  documents that were not previously declared editable now are. That is the ruling a reader should
  check, not the hash.
* **Dropping the preamble was correct.** It was narrated history inside a current-state declaration —
  the exact slop class this audit files as `HISTORY` — and its content now lives in the record that
  exists for it. It also contained a claim that turned out to be false: *"the original's complete
  referent list is not fully recoverable."* The zone paths match exactly, so the list was complete.

## The diff, verbatim

`diff -u <(git show 9304650:PROTECTED.md) crew-research-council/PROTECTED.md` — 40 lines differ
(21 removed, 19 added).

```diff
@@ -3,41 +3,39 @@
 > **What this file is:** the local declaration of what may never be edited in place here. It is the
 > authoritative detail for this project; `~/CONSTITUTION.md` §2 is the umbrella index.
 > **Owner:** Fares. **Language:** artifacts English, chat Arabic.
->
-> **RECONSTRUCTION — 2026-09-21.** The original was created 2026-09-20, was never `git add`ed, and was
-> deleted by a concurrent writer. It is in no commit (`git log --all` → empty) and `git fsck` finds no
-> dangling blob, so **these are not the original bytes** (the original was 41 lines / 2375 bytes; its
-> hash is unknown because it was never staged). The zones below are the ones the audit trail documents
-> — `local/compliance/2026-09-20-gaps.md` §2b and the referent scan in `local/context/` that ran while
-> the file still existed — and every path is verified to resolve on disk. **The original's complete
-> referent list is not fully recoverable**, so treat this as a floor, not a restoration. It is tracked
-> in git from now on (`git ls-files PROTECTED.md`), which is the failure this file now exists to close.
 
 ## Protected (do not edit in place)
 
 | Path | Why |
 |---|---|
-| `RESEARCH-COUNCIL/**` | Research **input**, already ingested by the study — changing it corrupts the study (§2) |
-| `RESEARCH-COUNCIL/STATUS.md` | The canonical status record; the repo boundary commit names it as the one that survives |
-| `tests/**`, `crew/**`, `harness/**`, `repro/**` | Present on disk and **git-ignored** — one copy, no history, no backup. Deleting or overwriting any of them is unrecoverable. This is the exact failure mode that lost the file you are reading |
+| `RESEARCH-COUNCIL/**` (briefs, prompts, methodology, guardrails, `OUTPUT/**`) | The **ingested research corpus**. `CONTEXT.md` is the system brief the council was given; `OUTPUT/**` is the delivered evidence. Changing the briefs after ingestion corrupts the study — a superseding brief is a new file, not an edit. |
+| `RESEARCH-COUNCIL/STATUS.md` | The **canonical** status surface for the council (per the 2026-09-19 commit). Maintained by append/update with a record, never silently rewritten. |
+| `tests/**`, `crew/**`, `harness/**`, `repro/**` | Currently untracked working copies (only `__pycache__` on disk). Do not treat the empty trees as an implemented test/harness layer. |
 
 ## The gate
 
-**None** — there is no build gate in this project. The repository tracks documents: no runner, no
-executable surface, no `.json` / `.sh` / `.py` to execute. The written record is the verification, and
-`local/scripts/constitution-sweep.sh` files that as a gap rather than pretending prose is a command.
+There is no build gate in this project. The binding discipline is the project's own law:
+
+- `TEST-POLICY.md` §3 — **the Iron Law:** no production code without a witnessed failing test first;
+  no "done" claim without a RED reference + GREEN log + clean full suite.
+- `README.md` — the board is the ONLY shared state; no decision lives in chat.
+
+Run the board protocol (APPEND / FLAG / SNAPSHOT / RESTORE) rather than editing shared state directly.
 
 ## Safe write-path
 
-`README.md` and the non-council surfaces.
+`README.md` · `BLACKBOARD.md` · `GOAL.md` · `PROJECT.md` · `ENTITY.md` · `GENESIS.md` · `VOICES.md` ·
+`THROUGHPUT.md` · `ARENA.md` · `bets-ledger.md` · `leaderboard.md` · `REVIEW-01.md` · `REVIEW-02.md` ·
+`v2-ARCHITECTURE.md` · `TESTING-COUNCIL.md` · `TEST-POLICY.md`.
 
## Local laws that bind any edit here
 
+- The board is the only shared state; chat threads are Q&A only.
+- @razor holds hard VETO at both cut gates — must cite the deletion rule AND propose the smaller
+  surviving subset. No subset, no veto.
+- Compression is not a veto reason: cutting words is not cutting scope.
```

## Verified independently in this audit

* The adopted file's content sha256 is `a12092df17090b6660206caf31e72d61b7e7d3e28663eb85bd5925cc743d1bf3`
  (41 L / 2375 B) and is byte-identical to the evidence copy (`cmp`, not a size comparison).
* **The cause, and the recovery, both check out.** The dangling commit `f3f8496` has the three parents
  `git stash push -u` creates: `221713d` (the HEAD it was taken on), `abd024c` (`index on main`), and
  `5e30e75` (`untracked files on main`). That last tree holds `PROTECTED.md` as blob `5b8cc782…` —
  sha256 `a12092df…`, the adopted bytes — beside the two `missions/CREW-EVIDENCE/` files. So the
  original was carried by a stash, not deleted by a writer, and the object store held it the whole time.
* **16/16 safe write-path referents present on disk**, re-derived from the adopted file rather than
  taken from the recovery record.
* Substituting the original does not narrow the protected set this audit derives: the three zone paths
  are identical before and after. It adds one token, `OUTPUT/**`, taken from the new parenthetical,
  which reduces to `<repo>/OUTPUT` — a path that does not exist. Strictly a superset, so nothing lost;
  filed as a quirk of crude parent-reduction, not as a defect in the declaration.

## Corrections to this audit's own record

Three claims in the §11/§13 entries of `local/context/2026-09-21-receipt.md` are superseded here rather
than edited there:

1. **Cause.** §11 recorded the file as deleted by a *"concurrent writer"*. It was swept out of the
   worktree by `git stash push -u` run by a cross-project condensation pass. Not hostility — a tool
   operation with `-u`, which takes untracked files with it.
2. **Method, and this is the one worth keeping.** §11 argued from *"`git fsck` finds no dangling blob"*
   to *"never staged, so no blob exists to recover"*. The first observation was true and the inference
   was wrong: the blobs existed and were **reachable from `refs/stash`**, and `git fsck` — correctly —
   never reports a reachable object as dangling. The probe that would have found it is `git stash list`,
   which was never run. **A probe that returns "nothing" is only evidence if it was asking the right
   question.**
3. **Scope.** §11 called the original's hash unknowable and its referent list unrecoverable; both are
   now measured (§15 of the receipt records the first, this file records the second).
4. **This record's own first draft** said no file on disk carries the superseded reconstruction's
   text. Two do — this record and the receipt, as quoted evidence. Corrected here rather than left to
   read as verified, since the claim was about this record itself.

## Open items — filed, not closed

* `crew-research-council/PROTECTED.md` is `DRIFT` with `NO-COMMIT` in the audit ledger: recorded
  `f17a238d`, on disk `a12092df`. The change is committed (`726049b`), so `--record` would now accept
  and bind it. **It was not run**: recording is the *"I intend this state"* act, and the recovery
  record marks its own decision *"agent, revocable — R8 applies"*. Ratifying that is the Owner's line.
* The freshly committed condensation in other repositories (`Projects/notrick` `194c32a`,
  `Projects/colony-kernel` `142fec0`, `Projects/dyno-pony` `b5c52b6`) is in the same position: one
  `--record` binds them all, and it was not run for the same reason.
* Fourteen documents entered the crew safe write-path that were not there before. If any of them should
  not be editable, that is a declaration change — an Owner act, not an audit finding.

## What this file does not claim

That the replacement was the Owner's ruling. It was made by an agent, stated as such in
`PROTECTED-RECOVERY-20260921.md`, and it is revocable. This audit's contribution is narrower and
checkable: the adopted bytes are the recovered bytes, the mechanism that lost and returned them is
identified in the object store, protection was not narrowed while edit rights were widened, and the
superseded text is preserved where a superseded artifact belongs.
