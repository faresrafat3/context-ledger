# RECEIPT — round 4 (2026-09-21): the audit surface goes green

**What this round is:** the closure of the three items the round-3 receipt left open — the
`design.md` acceptance test executed, and the two remaining digest refusals (documents outside
version control) resolved by putting them under version control. `--check` now exits **0**.

## 1. Commands + exits

| command | exit | what it established |
|---|---|---|
| `context-audit.sh --record` (after committing knowledge-factory) | 1 | 26 docs: 23 unchanged, 3 changed, **0 unbound** — the refusals are gone once repos exist |
| `context-audit.sh --density` | 0 | `design.md` 5065 · NUM 78 · CITE 145 · FALSE 12 (density 4) — counters pinned |
| `context-audit.sh --check` | **0** | `over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0` |
| `git` commits | 0 | kf `86d0557` (design.md) · anatomy-lab `e20b65f` (init) · $HOME `acabaad` (init) · local `0241baa`, `28f3663`, `9ab6ac3` |

## 2. The design.md round — the acceptance test, executed

Test (round-3 receipt §8c): `CITE=145` and `FALSE=12` unchanged, `NUM ≥ 78`, `WORDS` falling.

| | before | after |
|---|---|---|
| words | 6369 | **5065** (−20.5%) |
| CITE / FALSE / NUM | 145 / 12 / 78 | **145 / 12 / 78** (unchanged) |
| lines / bytes | 442 / 47181 | 428 / 40156 |
| status | OVER 6369/5080 | **ok 5065/5080** |

Method: §3 compression only — connective prose, restatement, and ceremony removed; every
backticked path, every digit-bearing token, and every falsifier line preserved. Any drift in
the three counters would have been a lost fact, not a saving — none occurred.

**Identity break, recorded:** `design.md` was byte-identical to
`wiki/2026-09-05-design-dsh-substrate.md` and its archive copy (`sha256 86f00db1…`). It no
longer is: new `sha256 2131c13d308d3ad62b1005508e53e38d88f471457407e9d977b544d2ddf4527c`.
Both frozen copies remain untouched at the old hash. Commit `86d0557` carries the pair.

## 3. The two refusals — resolved by version control, not by hand-editing the ledger

The tool's rule: "put the document under version control, then re-record." Its own design
forbids hand-forging a first pin around a refusal (receipt §13), so both documents got repos:

- **`anatomy-lab/`** — `git init`, `.gitignore` with reasons in the file (`results/` 526M
  re-derivable, `node_modules/` 96M, `colony-kernel/dist/` generated); 522 files tracked —
  the 16 frozen SOULs, `docs/`, `briefs/`, review packets, declarations. Commit `e20b65f`.
  This closes the same loss class that cost crew-research-council its `PROTECTED.md` original:
  frozen evidence with no history behind it.
- **`$HOME`** — a one-file repository (`CONSTITUTION.md` + its `.gitignore`), created for
  exactly this row: the workspace law is the only declared document outside any project, and
  its digest cannot bind without a repository holding its bytes. Commit `acabaad`. The
  sweep's per-directory detection reads `.git` presence, so no other tool's behaviour changes.

## 4. Honest limits

- `design.md` is now a *living* document; the wiki/archive copies remain the frozen record of
  the 2026-09-05 state. Future edits to `design.md` need no new identity note.
- The `$HOME` repo tracks two files and ignores everything else; `git clean -fdx` there would
  still obey the ignore file only for tracked/untracked classification — the danger it removes
  is accidental *staging*, which is proven by the ignore rules.
- Rounds 1–3's ceilings for the five compressed documents were untouched; only `design.md`'s
  row changed status (OVER → ok) by compression alone, no ceiling was raised.
