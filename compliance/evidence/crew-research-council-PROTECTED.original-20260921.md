# PROTECTED — crew-research-council

> **What this file is:** the local declaration of what may never be edited in place here. It is the
> authoritative detail for this project; `~/CONSTITUTION.md` §2 is the umbrella index.
> **Owner:** Fares. **Language:** artifacts English, chat Arabic.

## Protected (do not edit in place)

| Path | Why |
|---|---|
| `RESEARCH-COUNCIL/**` (briefs, prompts, methodology, guardrails, `OUTPUT/**`) | The **ingested research corpus**. `CONTEXT.md` is the system brief the council was given; `OUTPUT/**` is the delivered evidence. Changing the briefs after ingestion corrupts the study — a superseding brief is a new file, not an edit. |
| `RESEARCH-COUNCIL/STATUS.md` | The **canonical** status surface for the council (per the 2026-09-19 commit). Maintained by append/update with a record, never silently rewritten. |
| `tests/**`, `crew/**`, `harness/**`, `repro/**` | Currently untracked working copies (only `__pycache__` on disk). Do not treat the empty trees as an implemented test/harness layer. |

## The gate

There is no build gate in this project. The binding discipline is the project's own law:

- `TEST-POLICY.md` §3 — **the Iron Law:** no production code without a witnessed failing test first;
  no "done" claim without a RED reference + GREEN log + clean full suite.
- `README.md` — the board is the ONLY shared state; no decision lives in chat.

Run the board protocol (APPEND / FLAG / SNAPSHOT / RESTORE) rather than editing shared state directly.

## Safe write-path

`README.md` · `BLACKBOARD.md` · `GOAL.md` · `PROJECT.md` · `ENTITY.md` · `GENESIS.md` · `VOICES.md` ·
`THROUGHPUT.md` · `ARENA.md` · `bets-ledger.md` · `leaderboard.md` · `REVIEW-01.md` · `REVIEW-02.md` ·
`v2-ARCHITECTURE.md` · `TESTING-COUNCIL.md` · `TEST-POLICY.md`.

## Local laws that bind any edit here

- The board is the only shared state; chat threads are Q&A only.
- @razor holds hard VETO at both cut gates — must cite the deletion rule AND propose the smaller
  surviving subset. No subset, no veto.
- Compression is not a veto reason: cutting words is not cutting scope.

## If you believe a protected file must change

Add a **new dated** document beside it and record the supersession. For a research input, that means
a new brief the council is re-run against — never a rewrite of the brief already ingested.
