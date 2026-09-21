#!/usr/bin/env bash
#
# Regenerate the .hermes working mirror from the canonical RESEARCH-COUNCIL tree.
#
# WHY THIS EXISTS
#   .hermes/crew/RESEARCH-COUNCIL/ is a second copy of the council's research
#   output. It drifted silently once: STATUS.md sat on the pre-a22aa40 revision
#   while the canonical copy advanced in 72e3132, and it held only 2 of 35 files
#   for a while. It is ignored by git, so nothing ever reported the divergence.
#   This script makes regeneration a one-liner and makes drift detectable.
#
# USAGE
#   sync-hermes-mirror.sh              sync canonical -> mirror (default)
#   sync-hermes-mirror.sh --check      report drift only; exit 1 if drifted
#   sync-hermes-mirror.sh --dry-run    show what a sync would change
#   sync-hermes-mirror.sh --help       this text
#
#   REPO=/path/to/repo sync-hermes-mirror.sh     override the repo location
#
# EXIT CODES
#   0  in sync, or sync completed and verified
#   1  --check found drift, or post-sync verification failed
#   2  bad usage / failed guard
#
set -euo pipefail

REPO="${REPO:-$HOME/crew-research-council}"
SRC="$REPO/RESEARCH-COUNCIL"
DEST="$REPO/.hermes/crew/RESEARCH-COUNCIL"

mode=sync
case "${1:-}" in
  ""|--sync)    mode=sync ;;
  --check|-c)   mode=check ;;
  --dry-run|-n) mode=dry ;;
  -h|--help)    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)            printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

die() { printf 'error: %s\n' "$*" >&2; exit 2; }

# ── Guards ────────────────────────────────────────────────────────────
# This script runs `rsync --delete`. An empty or wrong path would delete the
# wrong tree, so every path is validated before rsync is reached.
[ -n "${REPO:-}" ]        || die "REPO is empty"
[ -d "$REPO/.git" ]       || die "not a git repository: $REPO"
[ -d "$SRC" ]             || die "canonical tree missing: $SRC"
[ -d "$DEST" ]            || die "mirror dir missing: $DEST (create it explicitly; this script will not guess)"
[ -r "$SRC" ] && [ -x "$SRC" ] || die "canonical tree not readable: $SRC"
case "$SRC"  in /*) ;; *) die "SRC is not an absolute path: $SRC" ;;  esac
case "$DEST" in /*) ;; *) die "DEST is not an absolute path: $DEST" ;; esac
[ "$SRC" != "$DEST" ]     || die "SRC and DEST are the same path"
case "$SRC" in "$DEST"/*) die "SRC is nested inside DEST: $SRC" ;; esac
case "$DEST" in "$SRC"/*) die "DEST is nested inside SRC: $DEST" ;; esac
[ -n "$(find "$SRC" -type f -print -quit)" ] || die "canonical tree is empty: $SRC"

# The mirror is meant to be ignored by git. If it is not, syncing it would
# create tracked changes — warn loudly rather than doing that quietly.
if ! git -C "$REPO" check-ignore -q ".hermes/" 2>/dev/null; then
  printf 'warning: .hermes/ is not git-ignored in %s — mirroring may create tracked changes\n' "$REPO" >&2
fi

src_n=$(find "$SRC" -type f | wc -l | tr -d ' ')
dest_n=$(find "$DEST" -type f | wc -l | tr -d ' ')

# ── Drift detection ───────────────────────────────────────────────────
drift_args=(-rq --exclude=.git)
if diff "${drift_args[@]}" "$SRC" "$DEST" >/dev/null 2>&1; then
  drifted=0
else
  drifted=1
fi

case "$mode" in
  check)
    if [ "$drifted" -eq 0 ]; then
      printf 'in sync — %s files\n' "$src_n"
      exit 0
    fi
    printf 'DRIFT: canonical has %s files, mirror has %s\n' "$src_n" "$dest_n" >&2
    printf 'differing paths (first 20):\n' >&2
    diff "${drift_args[@]}" "$SRC" "$DEST" 2>&1 | sed 's/^/  /' | head -20 >&2 || true
    exit 1
    ;;

  dry)
    printf 'dry run: canonical %s files, mirror %s files\n' "$src_n" "$dest_n"
    rsync -a --delete --dry-run --itemize-changes "$SRC/" "$DEST/"
    exit 0
    ;;
esac

# ── Sync ──────────────────────────────────────────────────────────────
rsync -a --delete "$SRC/" "$DEST/"

# ── Verify ────────────────────────────────────────────────────────────
if diff "${drift_args[@]}" "$SRC" "$DEST" >/dev/null 2>&1; then
  printf 'mirror refreshed — %s files, verified identical to canonical\n' \
    "$(find "$DEST" -type f | wc -l | tr -d ' ')"
  exit 0
fi
printf 'error: mirror still differs from canonical after sync\n' >&2
exit 1
