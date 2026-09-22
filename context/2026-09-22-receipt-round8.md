# Round 8 — the gate proves itself: `LEDGER_PAT`, a real 26/26, and what a wrong token does

Date: 2026-09-22. Ledger at `c522b13` when this round began; the commits it records are in §6.
This round changes no declared document. It adds one repository secret and records what four
deliberate reruns against four secret states actually did.

## 1. What was added

`LEDGER_PAT` — a repository secret for Actions, set 2026-09-22T04:39:41Z. It reaches the workflow at
exactly one place: `.github/workflows/gate.yml`, the `full-check` step's `env:`. No other job reads
it, nothing prints it, and the script hands it to git through a credential helper
(`username=x-access-token`), never through a URL or a log line.

The credential is this machine's account OAuth token (`gho_…`, scopes `gist`, `read:org`, `repo`,
`workflow` — from `gh auth status`). A fine-grained read-only PAT is the right shape for this use and
cannot be created through the API; §7 says how to replace it and why you may want to.

## 2. The proof: one run, four secret states

Run `35687118720` (push to `main`, `c522b13`) — every state below is the same run and the same
commit, rerun deliberately. The replica job is the only one that sees the secret.

| attempt | secret state | job | what the runner said |
|---|---|---|---|
| 1 | absent (as landed) | success | `LEDGER_PAT absent — checking the public repositories and naming the gap`; `check: over_ceiling=0 missing=5 conflicts=0 digest_failures=6 unbound=6 ledger_failures=0 hard_slop=0`; the gate refused to pass |
| 2 | real token | success | `LEDGER_PAT present — checking all nine repositories`; `check: over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0 hard_slop=0`; `check: PASS — every declared document exists, is within ceiling, matches its recording,` |
| 3 | **wrong token** | **failure** | `LEDGER_PAT present — checking all nine repositories`; `remote: Invalid username or token. Password authentication is not supported for Git operations.`; `fatal: Authentication failed for 'https://github.com/faresrafat3/home-root.git/'` |
| 4 | real token restored | success | `check: over_ceiling=0 missing=0 conflicts=0 digest_failures=0 unbound=0 ledger_failures=0 hard_slop=0`; `check: PASS — …` |

Attempt 2 is the first time this ledger's 26 documents were checked end to end on a machine that only
had the published repositories: all nine cloned, every row bound to its recorded commit, every counter
zero. In attempt 3 the two other jobs — `battery (hermetic)` and `gate fails closed without the
workspace` — stayed green and never saw the secret; only `full-check` failed, at step 3, *build the
replica at the audited revisions and check it*. The run's own conclusion went `failure` at attempt 3
and back to `success` at attempt 4. The secret was wrong for 57 seconds; its final state is the real
token again.

## 3. What a wrong or expired token does

Two observations, one in CI and one local, agree:

```
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/faresrafat3/home-root.git/'
```

Locally, `LEDGER_PAT=definitely-not-a-valid-token bash scripts/ci-replica.sh` exits **128** (git's
code, propagated by `set -e`) after the same two lines. `home-root` is the first clone attempted, so
the failure lands in about a second — no partial replica is built, nothing is measured, nothing is
asserted, and the job is red. Nothing is written to the step summary, so a red replica job with an
empty summary is the signature of a credential problem.

**Expiry is the same code path.** GitHub answers a revoked or expired token with the same
authentication failure, and the helper has no way to tell "wrong" from "expired"; the diagnosis is
the message plus `gh secret list`'s timestamp. There is deliberately no friendly auth-error line: the
job fails with git's own message and a non-zero exit, which names the cause without a second owner
for the wording. A friendlier hint is a judgement call for the next round, not a defect.

## 4. What this changes about the gate

- **mode A** (no secret: forks, or a repository that has not been given one) is unchanged — the honest
  measurement, with the documents it could not check named one by one, and no pass claimed.
- **mode B** (secret present) is now a real gate rather than an aspiration: all nine repositories,
  every row verified against the revision the ledger binds (`scripts/ci-replica.sh`, `c522b13`), a
  `PASS` required with every counter zero, and every flagged row inside a held repository is fatal.
- **Fork pull requests never receive the secret** (GitHub's default), so an outside contribution
  cannot read it and still runs mode A. Same-repository branches and pushes get mode B.
- The replica still reports `deepseek-harness`'s published default branch (`master` = `ddefc45`) as
  differing from the audited revision (`e32dad2447`). That is reported, never failed, because a
  recording binds bytes to a commit, not to a branch tip.

## 5. Operational note: reruns mint new job ids

To re-prove mode B after a rotation, rerun the replica job rather than pushing a commit:

```
J=$(gh api repos/faresrafat3/context-ledger/actions/runs/<run>/jobs \
     --jq '.jobs[]|select(.name|startswith("full check"))|.id')
gh api -X POST repos/faresrafat3/context-ledger/actions/jobs/$J/rerun
```

A rerun creates a **new** job id, so a cached one silently does nothing (`gh run rerun --job` with a
stale id is a no-op that reports no error). Fetch the id immediately before each rerun; the attempt
number increments, and `--attempt N` reads the log of the attempt you mean.

## 6. Commits and runs

- `c522b13` — CI replica: audit the revision the ledger binds, and assert every reachable row
  (PR #3, squash of `fbe3d98`; YAML 219 → 140 lines, `scripts/ci-replica.sh` new). Not receipted at
  the time; recorded here.
- Run `35687118720` — attempts 1–4 as tabulated in §2; final state `attempt=4`, `success`.
- Secret `LEDGER_PAT` — set, wrong for 57s during the experiment, restored.

## 7. Honest limits and Owner ruling

- **The credential is broader than the design intends.** `repo` and `workflow` scopes are write
  access across every repository of the account, carried by a job in a public repository. The blast
  radius is bounded by GitHub's rules — only workflows in this repository can read the secret, and
  only for pushes and same-repository pull requests — but the right credential is a fine-grained PAT
  with `Contents: read` on `home-root`, `anatomy-lab` and `knowledge-factory` and nothing else:

  `gh secret set LEDGER_PAT --repo faresrafat3/context-ledger --body "<fine-grained token>"`

  Rotating the account token without updating this secret turns the gate red (attempt 3's shape),
  which is the intended failure: closed, not silently degraded.
- **Mode B has exactly one observation.** Attempt 2 and attempt 4 both passed, which is two runs of
  the same code path on the same day; nothing here has seen a repository grow a new bound commit, a
  force-push that orphans a recorded commit (that path was exercised locally, not in CI), or a
  private repository renamed.
- **The step summary is not retrievable from the logs.** The proof above is quoted from job logs; the
  `FULL CHECK PASSED …` line the script writes to the step summary is asserted by code, not fetched.
- **Owner ruling:** replace this secret with a least-privilege PAT, and rotate it whenever the account
  token is replaced. Until then, CI holds a credential that can write to every repository of the
  account, and that is a cost the Owner chose knowingly when asking for a real mode B.
