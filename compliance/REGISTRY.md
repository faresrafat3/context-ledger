# COMPLIANCE REGISTRY — generated, not law

> generated: 2026-09-20 21:13 · source: `CONSTITUTION.md` · tool: `local/scripts/constitution-sweep.sh`
> source digest: sha256=efc0ac1106fb49fdc177ff244b893f737dc24d4774600d3b191d85003987e4cb · bytes=8810 · mtime=2026-09-20 11:22:44
> A registry whose digest differs from the file on disk was graded against a different revision. Re-run before quoting.
> Counts are computed at emit time (R14). Re-run it; never edit it.
> A gate is GREEN only if `--run-gates` executed it in this run; otherwise it is UNRUN, not passed.
> Referent classes: LOCAL-PATH (exists) · MISSING (local-looking, unresolved = failure) · NOT-A-LOCAL-PATH (printed, not counted as missing).

## 1. Rows — CONSTITUTION.md §2 read from disk

| line | project | path | exists | gate kind | gate command | tier | refs ok | refs missing | non-local | shorthand |
|---|---|---|---|---|---|---|---|---|---|---|
| 51 | NOTRICK | `~/Projects/notrick` | yes | COMMAND | `sha256sum -c <(grep -E "^[0-9a-f]{64}" INTEGRITY.md)` | 1 | 15 | 0 | - | - |
| 52 | Colony Kernel | `~/Projects/colony-kernel` | yes | COMMAND | `npm run verify` | 1 | 3 | 0 | - | - |
| 53 | DSH | `~/Projects/deepseek-harness` | yes | COMMAND | `pnpm run doc-sync` | 2 | 4 | 0 | - | - |
| 54 | Hermes Agent | `~/.hermes/hermes-agent` | yes | EXTERNAL | `-` | - | 0 | 0 | NousResearch/hermes-agent | - |
| 55 | crew-research-council | `~/crew-research-council` | yes | NONE | `-` | - | 1 | 0 | - | - |
| 56 | Anatomy Lab | `~/anatomy-lab` | yes | PROSE | `-` | - | 5 | 0 | - | - |
| 57 | dyno-pony | `~/Projects/dyno-pony` | yes | COMMAND | `node --test tests/*.test.cjs` | 1 | 1 | 0 | - | collect.sh[->scripts/collect.sh] |
| 58 | knowledge-factory | `~/Projects/knowledge-factory` | yes | NONE | `-` | - | 1 | 0 | - | - |
| 59 | `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime | `.dsh/` | yes | NONE | `-` | - | 0 | 0 | - | - |
| 59 | `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime | `.openclaw/` | yes | NONE | `-` | - | 0 | 0 | - | - |
| 59 | `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime | `~/.claude` | NO | NONE | `-` | - | 0 | 0 | - | - |
| 59 | `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime | `~/.agents` | yes | NONE | `-` | - | 0 | 0 | - | - |

## 2. Counts (generated at emit time)

```
rows_total=9  paths_total=12
gate_command=4 (tier1=3 tier2=1 not-runnable=0)
gate_none=3  gate_prose=1  gate_external=1  paths_missing=1
referents_ok=30  referents_missing=0  shorthand=1  non_local_tokens=1
```

## 3. Gate observations

run_gates=OFF — no gate was executed in this run. Every COMMAND row is UNRUN.
Quote a receipt on disk, or re-run with `--run-gates`, before calling any gate green.

## 4. Coverage — depth-1 trees on disk vs §2

```
candidates=28 covered=7 containers=1 uncovered=20
containers (children already covered): Projects
uncovered: 2026-research-council[looks-like-a-project],Applications[looks-like-a-project],Archive[looks-like-a-project],Camera[-],cleanup[looks-like-a-project],Cline[-],crew[-],Downloads[looks-like-a-project],hermes[-],local[looks-like-a-project],openresearch[-],Research[looks-like-a-project],research agents[looks-like-a-project],Screenshots[-],sidon-exp[looks-like-a-project],skills[-],snap[-],truth[-],VPNs[looks-like-a-project],Webcam[-]
note: the "looks-like-a-project" flag is a declared heuristic (git repo or doc/config file at depth<=2), not a verdict.
```

## 5. Runtime-tree doctrine scan (§2 last row claims "executable state only")

| path | *.md files (depth<=3) | doctrine-keyword files (first 5) |
|---|---|---|
| `.dsh/` | 105 | 3 |
| `.openclaw/` | 2 | 0 |
| `~/.claude` | (absent) | - |
| `~/.agents` | 17 | 0 |

```
doctrine-keyword files under .dsh/: .dsh/attachments/v1/files/8a/8a265c5b3d4755aa711fbd033c696499b991e9460a02a1fbc6278579d55fd61a/NOTRICK_SERIES2_01_ROUNDS_8-14_AND_GOAL.md,.dsh/attachments/v1/files/c2/c2364054da8e2c50e7940f11a5f78c46e41649231fb6a558f8fe08310b661b99/NOTRICK_SERIES2_00_BOILERPLATE_AND_ROUNDS_0-7.md,.dsh/memory/per-agent/2026-09-18-colony-kernel-published-and-session-coordination.md
```

## 6. Local declarations — §2 "One home per fact" (CONSTITUTION.md:41-47)

PROTECTED.md present at every directory the law names, with that file's own referents resolved:

| project | PROTECTED.md | referents ok | referents missing |
|---|---|---|---|
| `anatomy-lab` | present | 11 | 0 |
| `crew-research-council` | present | 6 | 0 |
| `Projects/dyno-pony` | present | 8 | 0 |
| `Projects/knowledge-factory` | present | 3 | 0 |

Projects the law keeps in their own doctrine (a PROTECTED.md here would be two homes): NOTRICK, Colony Kernel, DSH, upstream Hermes — checked under §7.

## 7. Findings — filed, not fixed

```
NOTE  [L54 Hermes Agent] tokens not resolvable locally (not counted missing): NousResearch/hermes-agent
GAP   [L55 crew-research-council] no gate declared in §2 (gate column: em dash)
GAP   [L56 Anatomy Lab] gate is prose, no executable command in §2
NOTE  [L57 dyno-pony] shorthand referent(s) resolved deeper in the tree: collect.sh[->scripts/collect.sh]
GAP   [L58 knowledge-factory] no gate declared in §2 (gate column: em dash)
GAP   [L59 `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime] no gate declared in §2 (gate column: em dash)
FAIL  [L59 `.dsh/`, `.openclaw/`, `~/.claude`, `~/.agents` runtime] path does not exist: ~/.claude
failures=5
```
