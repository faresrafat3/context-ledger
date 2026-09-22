#!/usr/bin/env bash
# Build a replica of the home the ledger audits — at the revisions the ledger binds — and check it.
#
# A clone of the ledger is not the workspace: `--check` measures documents that live in sibling
# repositories, so the gate needs a replica of the whole home. Building it here, in one place, means
# the same code runs in CI and on a workstation.
#
# Two modes, chosen by whether LEDGER_PAT is set:
#   * set   — all nine repositories are cloned, and the run passes only on a real PASS with every
#             counter zero.
#   * unset — the public repositories are cloned, the private ones are named as unchecked, and the
#             gate must still refuse to pass.
#
# Each repository is checked out at the commit its rows are bound to, so the replica is the audited
# revision and not whatever the default branch happens to hold now. Where the published default
# branch has moved past the audited revision, that is reported, never failed: a recording binds
# bytes to a commit, not to a branch tip.
#
# usage: ci-replica.sh [ledger-dir]      (default `ledger`; env: LEDGER_PAT, RUNNER_TEMP,
#                                        GITHUB_STEP_SUMMARY — the last two as CI provides them)

set -euo pipefail

LEDGER=${1:-ledger}
H=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/home
DIGESTS=$LEDGER/context/digests.tsv
DRIFT=""

summary(){ [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"; return 0; }
fail(){ printf '::error::%s\n' "$1"; exit 1; }

[ -f "$DIGESTS" ] || fail "nothing to verify against: $DIGESTS is absent"

CRED=()
if [ -n "${LEDGER_PAT:-}" ]; then
  export LEDGER_PAT
  # the token reaches git per clone — never a URL, a log line, or the workstation's own config
  CRED=(-c 'credential.helper=!f() { test "$1" = get && { echo username=x-access-token; echo "password=$LEDGER_PAT"; }; }; f')
  echo "LEDGER_PAT present — checking all nine repositories"
else
  echo "LEDGER_PAT absent — checking the public repositories and naming the gap"
fi

rm -rf "$H"; mkdir -p "$H"
clone(){ git clone -q --no-tags ${CRED[@]+"${CRED[@]}"} "https://github.com/faresrafat3/$1.git" "$2"; }

# the commit the rows under one path prefix are bound to ("" is the root repository, whose rows have
# no prefix); more than one answer means the ledger itself is inconsistent, and that is fatal
bound(){ awk -F'\t' -v p="$1" '
  $1 !~ /^#/ && NF >= 6 {
    if (p == "") { if (index($1, "/") == 0) print $5 }
    else if (index($1, p "/") == 1) print $5
  }' "$DIGESTS" | sort -u; }

materialise(){   # $1 = repository name on the remote, $2 = its path inside the replica
  local name=$1 rel=$2 commits commit head
  commits=$(bound "$rel")
  [ -n "$commits" ] || return 0
  [ "$(printf '%s\n' "$commits" | wc -l)" = 1 ] \
    || fail "$name: the ledger binds more than one commit for its documents: $(printf '%s ' $commits)"
  commit=$commits
  clone "$name" "$H/$rel"
  git -C "$H/$rel" checkout -q --detach "$commit" 2>/dev/null \
    || fail "$name: the recorded commit ${commit:0:12} is not fetchable from the remote — the audited bytes are not published"
  head=$(git -C "$H/$rel" rev-parse --short=12 refs/remotes/origin/HEAD 2>/dev/null || true)
  [ -z "$head" ] || [ "$head" = "${commit:0:12}" ] || DRIFT="$DRIFT$name(default=${head:0:7}) "
}

if [ -n "${LEDGER_PAT:-}" ]; then materialise home-root ""; else : > "$H/CONSTITUTION.md"; fi
mkdir -p "$H/local" && cp -a "$LEDGER/." "$H/local/"
for r in crew-research-council colony-kernel dyno-pony notrick deepseek-harness; do
  case $r in crew-research-council) rel=$r ;; *) rel=Projects/$r ;; esac
  materialise "$r" "$rel"
done
if [ -n "${LEDGER_PAT:-}" ]; then
  materialise anatomy-lab anatomy-lab
  materialise knowledge-factory Projects/knowledge-factory
fi

TOOL=$H/local/scripts/context-audit.sh
out=$(HOME_DIR="$H" "$TOOL" --check 2>&1) && rc=0 || rc=$?
printf '%s\n' "$out" | tail -20
line=$(printf '%s\n' "$out" | grep -m1 '^check: over_ceiling=' || true)
case "$line" in
  *ledger_failures=0*) ;;
  *) fail "the ledger's own binding is not clean in the replica: ${line:-no summary line}" ;;
esac

# Every flagged row must be one that no repository in the replica holds. A row flagged inside a
# repository the replica holds means the published bytes are not the audited bytes — the failure
# mode a bare missing/unbound count cannot see.
table=$(HOME_DIR="$H" "$TOOL" --digests 2>&1 || true)
offenders=0; unchecked=""
while read -r path digest bind rest; do
  case "$path" in DOCUMENT|'') continue ;; esac
  if [ "$bind" = no-repo ]; then unchecked="$unchecked$path "; continue; fi
  case "$digest/$bind" in ok/ok) continue ;; esac
  printf '::error::%s is flagged (%s/%s) in a repository the replica holds\n' "$path" "$digest" "$bind"
  offenders=$((offenders + 1))
done <<< "$table"
[ "$offenders" = 0 ] || fail "$offenders declared document(s) do not match the ledger"

if [ -n "${LEDGER_PAT:-}" ]; then
  [ "$rc" -eq 0 ] || fail "the full check did not pass with every repository reachable: ${line:-no summary line}"
  printf '%s\n' "$out" | grep -q 'check: PASS' || fail "exit 0 without a PASS line"
  case "$line" in *missing=0*'digest_failures=0'*) ;; *) fail "a PASS with non-zero counters is not a pass: ${line:-no summary line}" ;; esac
  [ -z "$unchecked" ] || fail "a repository the replica holds went unchecked: $unchecked"
  summary "FULL CHECK PASSED — every declared document present, every counter zero: $line"
else
  if [ "$rc" -eq 0 ] || printf '%s\n' "$out" | grep -q 'check: PASS'; then
    fail "a public-only replica claimed a pass: ${line:-no summary line}"
  fi
  summary "public-only replica: the gate refused to pass; unchecked here — ${unchecked:-none}"
  summary "Add a fine-grained read-only PAT as the repository secret LEDGER_PAT to check all nine repositories."
fi
[ -z "$DRIFT" ] || summary "published default branch differs from the audited revision (reported, not failed): $DRIFT"
