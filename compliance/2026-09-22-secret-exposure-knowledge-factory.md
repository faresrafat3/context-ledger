# SECRET EXPOSURE — 2026-09-22 (bearer tokens committed in the private knowledge-factory repo)

**What this file is:** the record of a credential exposure found in the course of making the workspace
CI-reachable, its measured blast radius, what was and was not done about it, and the action the Owner
still owes. **This file contains no key material, by design: the ledger that holds it is public.**
Authored, not law. Owner ruling line empty-by-right (§7).

## 1. How it was found

The pass proposed making `Projects/knowledge-factory` public so CI could clone it. The same pre-publish
secret scan that was run over the ledger was run over that repo first. It hit two
`Authorization: Bearer sk-…` values in a tracked file. The publication was **not** made; this record is
the cost of noticing.

## 2. The exposure

| what | where |
|---|---|
| file | `Projects/knowledge-factory/wiki/archive-2026-09-05-harness-divergent-copy/2026-09-04-dossier-overlap.md` |
| lines | 35 and 48 — literal `-H "Authorization: Bearer …"` curl headers |
| shape | two `sk-`-prefixed values, 60 and 56 characters, provider-key shaped (masked here on purpose) |
| introduced by | commit `55948a3` — "rescue: version the design corpus (wiki/) + import divergent harness copy" |
| history | yes: the values are in that commit, so deleting the file today does not remove them |

## 3. Blast radius (measured, not assumed)

| question | answer | how it was checked |
|---|---|---|
| is it in any published repo? | **no** | `git grep` for both values across all nine repos: only the one private file matched |
| is it in the public ledger? | **no** | `grep` over `local/` worktree and `git log --all -S` over its history |
| does it exist outside git? | **yes** | untracked copies in `~/.env`, `~/.openclaw/.env`, `~/.openclaw/state/openclaw.sqlite(-wal)`, `~/.local/share/opencode/auth.json`, `~/.local/state/opencode/prompt-history.jsonl`, `~/.config/freebuff-desktop/…/desktop-v2.db-wal` |
| never published from the root? | correct | the `$HOME` repo tracks only `.gitignore` and `CONSTITUTION.md`; `.env` was never tracked |

The untracked copies are the important half of that table: they are why these must be treated as **live**
credentials in use, not test fixtures.

## 4. What was done, and what was deliberately not

- **Done:** the CI-reachability pass gave `home-root` and `anatomy-lab` **private** remotes and kept
  `knowledge-factory` private (its remote received only the two pending documentation commits).
  Reachability was achieved **without** publishing this repo.
- **Not done:** no key value was copied, echoed, hashed into, or recorded anywhere in the ledger — not in
  this file, not in the receipts, not in a commit message.
- **Not done:** no rotation. Revoking a key is the Owner's act at the issuing provider; an agent that
  rotated it would be guessing at which of several credentials the two values are.

## 5. Required action (Owner)

1. **Revoke and re-issue both keys at the issuing provider.** Rotation is what makes the committed bytes
   worthless; nothing else does, because they are in `55948a3`'s history.
2. Optionally, after rotation, rewrite that repo's history (drop the file, force-push the private remote)
   and record the rewrite. Recommended only *after* step 1 — a rewrite before rotation buys nothing and
   breaks clones, and any existing clone, backup or archive still holds the old bytes.
3. Decide whether the untracked copies (`~/.env` and friends) should stop carrying the keys at all; they
   are outside every repo's tracked set, so no push has ever included them.

## 6. The ledger gap this exposes (not built)

`--check` cannot catch this class. It pins the **declared context surface** — 26 documents in
`ceilings.tsv` — and the file holding these tokens is not declared anywhere, so no digest, binding or
recovery probe ever looked at it. A future round could add a **report-only** secret-pattern layer over
declared repositories' tracked files, with the same discipline as the rest of the tool: measured, filed
with `file:line`, never repaired in place. It is named here as a gap rather than added as scope.

## 7. Owner ruling

__________ (empty-by-right)
