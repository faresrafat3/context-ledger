# CONTEXT REGISTRY — generated, not law

> generated: 2026-09-21 07:38 · declaration: `local/context/ceilings.tsv` · tool: `local/scripts/context-audit.sh`
> declaration digest: sha256=9e885282fef15077c228f01f3bf478291530dea87e32e9721ca75c3fce2edaac · bytes=3136
> ledger: 5cdaeeb2 · 1 of 3 file(s) not committed
> Counts are computed at emit time (R14). Re-run this file; never edit it.
> words/lines/bytes are exact; tokens are an ESTIMATE (bytes/4).
> The law is §3 of `CONSTITUTION.md`: reduce lines, never reduce meaning.
> Burden of proof per line, from He et al. 2026 (arXiv:2607.17598: one disclosure
> level is enough), Gloaguen et al. 2026 (arXiv:2602.11988: context files lower
> success and raise cost >20%), and Liu et al. 2024 (use is U-shaped in position).

## 1. Surface — declared documents, measured

| document | status | lines | bytes | words | ~tok | ceiling | zone | bind |
|---|---|---|---|---|---|---|---|---|
| `CONSTITUTION.md` | law | 106 | 8810 | 1297 | 2203 | - | law | no-repo |
| `Projects/notrick/AGENTS.md` | protected | 74 | 5018 | 806 | 1255 | - | protected | NO-COMMIT |
| `Projects/notrick/RULES.md` | protected | 82 | 5255 | 838 | 1314 | - | protected | ok |
| `Projects/notrick/INTEGRITY.md` | protected | 107 | 8903 | 773 | 2226 | - | protected | ok |
| `Projects/notrick/ONBOARDING.md` | protected | 55 | 3787 | 602 | 947 | - | protected | ok |
| `Projects/notrick/FOUNDATIONAL-BRIEF.md` | protected | 54 | 3884 | 581 | 971 | - | protected | ok |
| `Projects/notrick/CONTEXT.md` | protected | 706 | 78814 | 10512 | 19704 | - | protected | ok |
| `Projects/notrick/README.md` | cite-sensitive | 64 | 5683 | 861 | 1421 | - | cite-sensitive | NO-COMMIT |
| `Projects/colony-kernel/AGENTS.md` | ok | 77 | 4494 | 635 | 1124 | 810 | edit | NO-COMMIT |
| `Projects/colony-kernel/README.md` | ok | 79 | 4922 | 558 | 1231 | 630 | edit | NO-COMMIT |
| `Projects/colony-kernel/GOVERNANCE.md` | law | 62 | 2363 | 363 | 591 | - | law | ok |
| `Projects/deepseek-harness/AGENTS.md` | project-gated | 155 | 16565 | 1949 | 4142 | - | project-gated | ok |
| `Projects/deepseek-harness/README.md` | project-gated | 63 | 2201 | 238 | 551 | - | project-gated | ok |
| `Projects/deepseek-harness/docs/AGENTS.md` | project-gated | 75 | 10535 | 1317 | 2634 | - | project-gated | ok |
| `Projects/deepseek-harness/packages/AGENTS.md` | project-gated | 28 | 6166 | 717 | 1542 | - | project-gated | ok |
| `Projects/deepseek-harness/packages/README.md` | project-gated | 114 | 7926 | 911 | 1982 | - | project-gated | ok |
| `Projects/dyno-pony/AGENT-ERGONOMICS.md` | ok | 91 | 8235 | 1277 | 2059 | 1580 | edit | ok |
| `Projects/dyno-pony/README.md` | ok | 114 | 6343 | 794 | 1586 | 970 | edit | NO-COMMIT |
| `Projects/dyno-pony/PROTECTED.md` | declaration | 53 | 4136 | 586 | 1034 | - | declaration | NO-COMMIT |
| `Projects/knowledge-factory/README.md` | ok | 16 | 1324 | 160 | 331 | 170 | edit | NO-COMMIT |
| `Projects/knowledge-factory/design.md` | OVER | 442 | 47181 | 6369 | 11796 | 5080 | edit | ok |
| `Projects/knowledge-factory/PROTECTED.md` | declaration | 20 | 1596 | 228 | 399 | - | declaration | NO-COMMIT |
| `crew-research-council/README.md` | ok | 32 | 2230 | 344 | 558 | 370 | edit | NO-COMMIT |
| `crew-research-council/PROTECTED.md` | declaration | 43 | 2545 | 423 | 637 | - | declaration | NO-COMMIT |
| `anatomy-lab/README.md` | ok | 24 | 2041 | 180 | 511 | 210 | edit | no-repo |
| `anatomy-lab/PROTECTED.md` | declaration | 33 | 2176 | 322 | 544 | - | declaration | no-repo |

## 2. Counts (generated at emit time)

```
declared=26  surface_total_words=33641  surface_total_bytes=253133
over_ceiling=1  missing=0  conflicts=0  slop_findings=65
digest_failures=19  unbound=3  (DRIFT / NEW / GONE / BIND-FAIL; run --digests for the table,
  --record to pin intent; a recording is bound to the commit that holds its bytes)
ledger_failures=1  (the declaration, the recording and this tool must each be committed:
  an uncommitted ledger is an edit with no trace)
walls=6  dup_headings=5  dup_invariants=0  history=15  status=10  preamble=3  emphasis=0  caps=26
```

## 3. Findings — filed, not fixed

```
CAPS       anatomy-lab/PROTECTED.md:0  1 all-caps token(s) in prose
CAPS       anatomy-lab/README.md:0  50 all-caps token(s) in prose
CAPS       CONSTITUTION.md:0  5 all-caps token(s) in prose
CAPS       crew-research-council/PROTECTED.md:0  1 all-caps token(s) in prose
CAPS       crew-research-council/README.md:0  34 all-caps token(s) in prose
CAPS       Projects/colony-kernel/AGENTS.md:0  18 all-caps token(s) in prose
CAPS       Projects/colony-kernel/GOVERNANCE.md:0  2 all-caps token(s) in prose
CAPS       Projects/colony-kernel/README.md:0  6 all-caps token(s) in prose
CAPS       Projects/deepseek-harness/AGENTS.md:0  17 all-caps token(s) in prose
CAPS       Projects/deepseek-harness/docs/AGENTS.md:0  13 all-caps token(s) in prose
CAPS       Projects/deepseek-harness/packages/AGENTS.md:0  3 all-caps token(s) in prose
CAPS       Projects/deepseek-harness/packages/README.md:0  13 all-caps token(s) in prose
CAPS       Projects/deepseek-harness/README.md:0  5 all-caps token(s) in prose
CAPS       Projects/dyno-pony/AGENT-ERGONOMICS.md:0  27 all-caps token(s) in prose
CAPS       Projects/dyno-pony/PROTECTED.md:0  14 all-caps token(s) in prose
CAPS       Projects/dyno-pony/README.md:0  6 all-caps token(s) in prose
CAPS       Projects/knowledge-factory/design.md:0  37 all-caps token(s) in prose
CAPS       Projects/knowledge-factory/PROTECTED.md:0  1 all-caps token(s) in prose
CAPS       Projects/knowledge-factory/README.md:0  1 all-caps token(s) in prose
CAPS       Projects/notrick/AGENTS.md:0  22 all-caps token(s) in prose
CAPS       Projects/notrick/CONTEXT.md:0  1362 all-caps token(s) in prose
CAPS       Projects/notrick/FOUNDATIONAL-BRIEF.md:0  31 all-caps token(s) in prose
CAPS       Projects/notrick/INTEGRITY.md:0  10 all-caps token(s) in prose
CAPS       Projects/notrick/ONBOARDING.md:0  23 all-caps token(s) in prose
CAPS       Projects/notrick/README.md:0  32 all-caps token(s) in prose
CAPS       Projects/notrick/RULES.md:0  19 all-caps token(s) in prose
DUP-HEADING Projects/dyno-pony/PROTECTED.md:29 Projects/knowledge-factory/PROTECTED.md:13 crew-research-council/PROTECTED.md:30 anatomy-lab/PROTECTED.md:21:0  duplicate home: "safe write path"
DUP-HEADING Projects/dyno-pony/PROTECTED.md:33 crew-research-council/PROTECTED.md:34 anatomy-lab/PROTECTED.md:25:0  duplicate home: "local laws that bind any edit here"
DUP-HEADING Projects/dyno-pony/PROTECTED.md:51 Projects/knowledge-factory/PROTECTED.md:19 crew-research-council/PROTECTED.md:41 anatomy-lab/PROTECTED.md:31:0  duplicate home: "if you believe a protected file must change"
DUP-HEADING Projects/dyno-pony/PROTECTED.md:5 Projects/knowledge-factory/PROTECTED.md:4 crew-research-council/PROTECTED.md:16 anatomy-lab/PROTECTED.md:5:0  duplicate home: "protected do not edit in place"
DUP-HEADING Projects/notrick/FOUNDATIONAL-BRIEF.md:12 Projects/knowledge-factory/README.md:4:0  duplicate home: "what this is"
HISTORY    Projects/deepseek-harness/docs/AGENTS.md:38  - **Document current state, not change history.** Avoid "previously/now/no longer", PRs, commits, and stack po
HISTORY    Projects/deepseek-harness/docs/AGENTS.md:64  - Narrated history or war stories: "previously", "now", "no longer", "used to", "renamed", "was moved", PRs, o
HISTORY    Projects/deepseek-harness/docs/AGENTS.md:67  - Reasoning transcripts: step-by-step implementation narration, proof of obvious branches, test walkthroughs, 
HISTORY    Projects/knowledge-factory/design.md:117  The "hierarchical memory" the home `AGENTS.md` describes (per-agent / per-group / per-company / global) is not
HISTORY    Projects/knowledge-factory/design.md:254  - **Default team tooling is one-shot fork/spawn** — `agent-team-profile` sets fresh and fork to `one-shot`, so
HISTORY    Projects/knowledge-factory/design.md:440  DSH already covers the substrate the founder needs to build a multi-agent research pipeline, with three honest
HISTORY    Projects/notrick/CONTEXT.md:100  - 2026-09-06 — RETRO-LOGGED approved-docs moment #2 (same 20:0x parallel session, continuing live; P15 Branch 
HISTORY    Projects/notrick/CONTEXT.md:194    Part 6 NOT YET (restates the indefinite-hold pace ruling; the personal written GO stays
HISTORY    Projects/notrick/CONTEXT.md:200    1, 3, 4 remain open (signature, smoke, threshold) · box 7 open by design (NOT YET).
HISTORY    Projects/notrick/CONTEXT.md:209    charters remain budget-gated by the zero-day pre-flight; hold unchanged (Part 6 NOT YET
HISTORY    Projects/notrick/CONTEXT.md:262    P6 NOT YET. Pre-flight: boxes 1,2,5,6 ✅ · box 3 (smoke) ❌ confirmed by HOLD · box 4
HISTORY    Projects/notrick/CONTEXT.md:528    (previously left untouched only because the tree was hot): both verdict-master.md:29
HISTORY    Projects/notrick/CONTEXT.md:704  - 2026-09-11 · ERGONOMICS-DEEP PASS (Owner live directive in-session, verbatim: "OK, now I want you to think d
HISTORY    Projects/notrick/CONTEXT.md:705  - 2026-09-19 · OWNER-RULING-SESSION PREP (Owner click-delegation standing order: rule the pending stack today,
HISTORY    Projects/notrick/README.md:10  - Zero day opens with Owner-only acts **P3 threshold · P5 fuel · P6 written GO** (RATIFICATION-BATCH-001.md 3/
PREAMBLE   CONSTITUTION.md:3  8-line preamble (the doctrine allows two)
PREAMBLE   crew-research-council/PROTECTED.md:3  12-line preamble (the doctrine allows two)
PREAMBLE   Projects/notrick/CONTEXT.md:6  13-line preamble (the doctrine allows two)
STATUS     Projects/deepseek-harness/AGENTS.md:134  - TODO markers: `FIXME`/`TODO`/`XXX` by urgency ([semantics](docs/development.md)).
STATUS     Projects/deepseek-harness/AGENTS.md:34    todo/        todo_write tool
STATUS     Projects/deepseek-harness/packages/AGENTS.md:28  - Package READMEs put durable consumer gaps and non-obvious maintainer constraints under `## Known Limitations
STATUS     Projects/deepseek-harness/packages/README.md:58  | [`todo/`](todo/README.md) | The model-facing `todo_write` tool |
STATUS     Projects/knowledge-factory/design.md:121  - `dsh-tool-todo` (`packages/todo/tool-todo/README.md`) — `todo_write` tool. Whole-list replacement; `allowPar
STATUS     Projects/knowledge-factory/design.md:14  - `packages/todo/tool-todo/` — `todo_write` tool
STATUS     Projects/knowledge-factory/design.md:172  - **Two planes are visible in the file**: persona + agent-instructions (prompt-plane), `tool-bash`/`tool-fs`/`
STATUS     Projects/knowledge-factory/design.md:375  - id: tool-todo
STATUS     Projects/knowledge-factory/design.md:376    name: '@deepseek-ai/dsh-tool-todo'
STATUS     Projects/knowledge-factory/design.md:81  | `standard` | Full coding agent with persona shadowing the deployment default | All tools: `tool-bash`, `tool
WALL       Projects/deepseek-harness/AGENTS.md:145  139 words on one physical line
WALL       Projects/notrick/CONTEXT.md:659  218 words on one physical line
WALL       Projects/notrick/CONTEXT.md:704  870 words on one physical line
WALL       Projects/notrick/CONTEXT.md:705  325 words on one physical line
WALL       Projects/notrick/CONTEXT.md:706  436 words on one physical line
WALL       Projects/notrick/CONTEXT.md:99  159 words on one physical line
WARN  [bind] CONSTITUTION.md: outside any git repository — bytes pinned, but no commit holds them
FAIL  [bind] Projects/notrick/AGENTS.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] Projects/notrick/README.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] Projects/notrick/README.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] Projects/colony-kernel/AGENTS.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] Projects/colony-kernel/AGENTS.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] Projects/colony-kernel/README.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] Projects/colony-kernel/README.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] Projects/dyno-pony/AGENT-ERGONOMICS.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [digest] Projects/dyno-pony/README.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] Projects/dyno-pony/README.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] Projects/dyno-pony/PROTECTED.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] Projects/dyno-pony/PROTECTED.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [bind] Projects/knowledge-factory/README.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [bind] Projects/knowledge-factory/PROTECTED.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] crew-research-council/README.md: bytes changed since the last recording — re-record if intended, and record why
FAIL  [bind] crew-research-council/README.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [bind] crew-research-council/PROTECTED.md: sits in a git repository but its recording carries no commit — re-record after committing
FAIL  [digest] anatomy-lab/README.md: bytes changed since the last recording — re-record if intended, and record why
WARN  [bind] anatomy-lab/README.md: outside any git repository — bytes pinned, but no commit holds them
FAIL  [digest] anatomy-lab/PROTECTED.md: bytes changed since the last recording — re-record if intended, and record why
WARN  [bind] anatomy-lab/PROTECTED.md: outside any git repository — bytes pinned, but no commit holds them
FAIL  [ledger] local/scripts/context-audit.sh: uncommitted changes — commit it, so any edit leaves a trace
```
