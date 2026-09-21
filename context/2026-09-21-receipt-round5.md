# RECEIPT — round 5 (2026-09-21): the audit learns to probe before pronouncing GONE

**What this round is:** a recovery probe inside `context-audit.sh`'s digest layer — a document is
reported GONE only after six places where its bytes may survive are checked, and the finding names
the remedy either way — plus the round's own incident, which is exactly the loss class the probe
exists to catch. Authored, not law. Owner ruling line empty-by-right (§7).

## 1. Commands + exits

| command | exit | what it established |
|---|---|---|
| `bash -n context-audit.sh` | 0 | syntax clean at every intermediate step |
| `context-audit.sh --self-test` | 0 | the standing battery passes **plus nine new recovery assertions** |
| `git` commit `0025dd1` | 0 | the probe lands: +235/−67 in `scripts/context-audit.sh`, staged by explicit path |
| `context-audit.sh --record` | 0 | 26 docs, 0 changed — the script's binding follows the probe commit |
| `git` commit `80b2a08` | 0 | re-recorded ledger committed (4 rows rebound to the new HEAD) |
| `context-audit.sh --check` | **0** | `over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0` |

## 2. The recovery probe — what changed and why

`GONE` was a claim about one snapshot (the working tree). `digest_status` still says it from disk
absence alone, but the finding is filed only after `recovery_probe` — read-only, memoized per
(path, recorded digest) — has asked where else the bytes live, in order:

| # | leg | command | stable against |
|---|---|---|---|
| 1 | recorded commit | `git rev-parse <commit>:<path>` | one `git checkout` away |
| 2 | the index | `git ls-files -s` | an unstaged deletion |
| 3 | any stash | `git stash list` + `cat-file -e <stash>:<path>` (stash, then its base) | `git stash -u` damage |
| 4 | the HEAD reflog | blob-id walk over `git reflog --format=%H HEAD` | a reset, pre-gc |
| 5 | reachable history | `git log --all -- <path>` | any commit that ever held the bytes, incl. restores and ancestors — gc can never erase these |
| 6 | unreachable objects | `git fsck --unreachable` | a dangling blob, gone at the next gc |

Matching is by **content, not guesswork**: a bound row carries the git blob id of the recorded
bytes; a legacy (pre-binding) 3-column row has none, so candidates are matched by hashing their
content against the recorded sha256 — the recorded digest IS the handle. Verdicts: a trace found
files `…RECOVERABLE: git checkout <c> -- <path> restores them (blob <sha>)`; no trace files
`no recovery probe found the bytes (recorded commit, index, stash, reflog, unreachable objects)`.
`--check` exits 1 either way — the verdict never softens, only the remedy text changes.
`--digests` names the leg in the ON-DISK column: `gone·commit/index/stash/reflog/history/
unreachable/no-trace`; status labels there are no longer truncated to 8 chars like digests.

## 3. Self-test choreography — nine assertions, three of which reshaped the code

| fixture choreography | expected verdict |
|---|---|
| committed deletion (row bound to the commit) | `gone·commit` + RECOVERABLE in `--check` |
| unstaged deletion over a legacy row | `gone·index` |
| stashed deletion over a legacy row (stash parked first, see below) | `gone·stash` |
| stash cleared, index emptied, reflogs intact | `gone·reflog` |
| reflogs expired, bytes still held by a reachable ancestor | `gone·history` — and **unchanged by `gc --prune=now`** |
| path added, removed, branch reset below both commits, reflogs expired | `gone·unreachable` |
| same fixture after `gc --prune=now` | `gone·no-trace` |

The fixtures forced three corrections that were tool truths, not test noise:

1. **`git stash` resets tracked files to HEAD.** Parking a stash while `digests.tsv` carries a
   working-tree change reverted the ledger itself to the committed (bound) version — the test now
   parks the stash *before* degrading the row to legacy form. Same hazard class as incident 9b
   below, found independently in miniature.
2. **The probe missed reachable history.** A restore commit holds the bytes in an *earlier*
   commit that the row does not name; reflog tips and fsck never see it. The self-test caught it
   (`gone·no-trace` where the bytes sat in an ancestor) and leg 5 exists because of it.
3. **`pipefail` + `grep -q` races a report writer** (SIGPIPE kills the writer mid-report): the
   RECOVERABLE assertion captures output, then greps.

Also recorded for the next hand here: bash `"\t"` inside double quotes is a literal backslash-t —
the first evidence lines never contained a TAB, found by `bash -x`; and `str_replace` was unusable
against this path all round (a stale "file does not exist" error, in both relative and absolute
form), so every edit landed as exact-match, count-asserted replacements that abort the whole patch
on any mismatch.

## 4. The incident, from both sides (9b's counterpart)

Incident 9b filed what it saw: an 11-byte `PLACEHOLDER` (mtime 08:25:37) replaced the working
tree's `scripts/context-audit.sh`, and ledger commit `a87f2f1` swept it in via `git add -A`.
This receipt files what stood behind it: the write was **this lane's** — a `write_file` probe
against a suspected editing-tool fault, made without a backup, against a file that was
**untracked**, so no git history held the original. What made recovery possible was the ledger's
own binding, added hours earlier in `6a595b1`: `digests.tsv` pinned the script's sha256
`9bc8b414…`, the restore in `57343bd` came from that pin (`a87f2f1^`), and byte-identity was
verified against the pin before any further work. The audit's subject survived its own audit
because the ledger remembered bytes nothing else did.

Rules taken: (1) **no full-file writes over an existing file in this workspace** — edits only,
via exact-match asserted replacements; (2) 9b's rule stands — read `git diff` before any
`git add -A`; (3) the general form is now enforced by the tool this round built: a GONE verdict
names its recovery path or states that none exists.

## 5. Commits this round

| commit | what |
|---|---|
| `0025dd1` | Recovery probe: GONE is reported only after the recorded commit, index, stash, reflog, reachable history and unreachable objects are checked (+235/−67) |
| `80b2a08` | Re-record: context-audit.sh binds to the recovery-probe commit |

This receipt is committed but not declared — same standing as the round-4 receipt; `ceilings.tsv`
is unchanged this round.

## 6. Honest limits

- Probe legs 4–6 stop at the gc horizon, stated in the tool's header: once gc has pruned, a loss
  with no commit, index, or reachable history behind it IS unrecoverable, and the probe says
  `no-trace` rather than guessing.
- The probe reads only — it never writes an object, creates a ref, or touches a stash; recovery
  itself remains a human act, and `--record`'s carry-forward semantics are unchanged.
- `git log --all` (leg 5) walks every ref; on a repo with many branches this leg is the slow one.
  The other legs and fsck are unchanged from before this round.

## 7. Owner ruling

__________ (empty-by-right)
