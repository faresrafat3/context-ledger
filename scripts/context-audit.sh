#!/usr/bin/env bash
#
# context-audit.sh — make CONSTITUTION.md §3 executable at workspace scale, and turn
# docs/AGENTS.md's slop checklist into a measured gate.
#
# WHY THIS EXISTS
#   §3 of CONSTITUTION.md is the compression law ("reduce lines, never reduce meaning"),
#   and docs/AGENTS.md carries a nine-item slop checklist. Both are prose. Nothing measured
#   the workspace's *context surface*, so "the context got lighter and stayed honest" was a
#   claim no verifier could quote from disk. This tool measures it, files slop with
#   file:line evidence, and ratchets word ceilings down.
#
# SCIENTIFIC BASIS — the burden of proof on every line
#   * He, Zhao, Wang, Chen 2026, "Is Progressive Disclosure All You Need for Long-Context
#     Agents?" (arXiv:2607.17598): one level of progressive disclosure is enough; a second
#     routing level never helps and sometimes collapses accuracy — "progressive disclosure
#     buys context, not intelligence". => a context doc links once to the owning home; it
#     never re-indexes its grandchildren.
#   * Gloaguen et al. 2026, "Evaluating AGENTS.md" (arXiv:2602.11988): repository context
#     files tend to lower task success and raise inference cost by over 20%; agents
#     faithfully obey even instructions they did not need. => each line must remove a fact
#     the agent cannot discover, or an ambiguity it would otherwise resolve wrongly. A line
#     that restates a fact owned elsewhere has negative value.
#   * Liu et al. 2024, "Lost in the Middle": attention over context is U-shaped in position.
#     => invariants belong near the top; prose padding in the middle costs signal.
#   Those three rules are the whole of this tool's judgement. Everything else is counted.
#
# HOW IT WORKS
#   `local/context/ceilings.tsv` declares the context surface, one row per document:
#   `path <TAB> ceiling_words <TAB> zone`. A ceiling of `-` means report-only.
#   Zones: edit (a compression pass may land here) · law (Owner act) · protected (evidence,
#   §2) · project-gated (the project's own doc gate owns it) · cite-sensitive (its line
#   numbers are cited elsewhere) · declaration (the authoritative PROTECTED.md itself).
#   Every declared row is measured (lines / bytes / words / est.tokens) and scanned by the
#   slop detectors. The cross-file detectors are what make "one home per fact" checkable.
#
# WHAT IT DOES NOT DO
#   It never edits a document, never raises a ceiling, never repairs a finding, and never
#   writes inside a protected zone. `--check` fails; it does not fix. Findings are filed.
#   It never commits. The commit that binds a recording is the Owner's act; `--record` only
#   refuses until that commit exists, so it cannot bless a change the repository does not hold.
#   It does hold its own ledger to the same rule: `ceilings.tsv`, `digests.tsv` and this script
#   must each match a commit, or `--check` fails (see "THE LEDGER'S OWN BINDING" below).
#   Tokens are an ESTIMATE (bytes/4, stated because no tokenizer is used); words, lines and
#   bytes are exact. `git` is required for the binding layer; if it is missing the binding
#   fails loudly rather than degrading to no protection at all.
#
# USAGE
#   context-audit.sh                 report to stdout
#   context-audit.sh --list          usage vs ceiling, one line per document
#   context-audit.sh --slop          only the slop findings, with file:line
#   context-audit.sh --write         write REGISTRY.md + registry.tsv + slop.tsv to $OUT
#   context-audit.sh --check         exit 1 on a missing declared file, an edit-zone document over
#                                    its ceiling, a digest failure (DRIFT / NEW / GONE — GONE is
#                                    probed for recoverable bytes first), a broken commit binding
#                                    (BIND-FAIL / NO-COMMIT), or an uncommitted ledger
#   context-audit.sh --strict        --check plus hard slop (walls, duplicate homes)
#   context-audit.sh --discover      context-looking docs on disk that no row declares
#   context-audit.sh --density       numbers / citations / falsifiers per 100 words, per doc
#                                    (the measurement behind an `evidence` vs `edit` zone)
#   context-audit.sh --record        pin every declared document into $DIGESTS — its sha256, its git
#                                    blob, and the commit that holds those bytes. REFUSES (exit 1) any
#                                    CHANGED document that no commit holds, whether the working tree is
#                                    uncommitted or the document sits outside version control: commit
#                                    the edit (or put it under version control) and then record it
#   context-audit.sh --digests       digest and binding per document (ok/DRIFT/NEW/GONE · ok/no-repo/NO-COMMIT/FAIL);
#                                    a GONE row's ON-DISK column names where the bytes survive
#                                    (commit/index/stash/reflog/history/unreachable/no-trace)
#   context-audit.sh --self-test     plant known lies in a fixture and prove they are caught
#   context-audit.sh --help
#
# EXIT CODES
#   0  report emitted / --check clean / --record pinned without refusing / self-test passed
#   1  --check found a failure, or --record refused a document that no commit holds
#   2  bad usage / missing declaration file / self-test failed
#
set -euo pipefail

HOME_DIR="${HOME_DIR:-${HOME}}"
CONSTITUTION="${CONSTITUTION:-$HOME_DIR/CONSTITUTION.md}"
CEILINGS="${CEILINGS:-$HOME_DIR/local/context/ceilings.tsv}"
OUT="${OUT:-$HOME_DIR/local/context}"
DIGESTS="${DIGESTS:-$OUT/digests.tsv}"
WALL_WORDS="${WALL_WORDS:-120}"
EMPHASIS_MARKS="${EMPHASIS_MARKS:-12}"

# ── helpers ────────────────────────────────────────────────────────────────────

usage(){ sed -n '/^# USAGE/,/^set -euo pipefail/p' "$0" | sed '$d; s/^# \{0,1\}//'; }
die(){ printf 'context-audit: %s\n' "$1" >&2; exit 2; }

abs_of(){ case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$HOME_DIR/$1" ;; esac; }
lines_of(){ wc -l < "$1" | tr -d ' '; }
bytes_of(){ wc -c < "$1" | tr -d ' '; }
words_of(){ wc -w < "$1" | tr -d ' '; }
est_tok(){ printf '%s' $(( ($(bytes_of "$1") + 3) / 4 )); }

# lowercase, drop every character that is not a letter/digit/space, squeeze spaces
norm(){ printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9 ]/ /g; s/  */ /g; s/^ //; s/ $//'; }

# ── the declaration: local/context/ceilings.tsv ─────────────────────────────────

declare -a SURF=()
declare -A CEIL=() ZONE=()

load_ceilings(){
  local p c z
  [ -f "$CEILINGS" ] || return 1
  while IFS=$'\t' read -r p c z || [ -n "${p:-}" ]; do
    p="${p%$'\r'}"; c="${c%$'\r'}"; z="${z%$'\r'}"
    [ -n "$p" ] || continue
    case "$p" in '#'*) continue ;; esac
    SURF+=("$p"); CEIL["$p"]="$c"; ZONE["$p"]="${z:-edit}"
  done < "$CEILINGS"
  [ "${#SURF[@]}" -gt 0 ]
}

# ── protected zones: read from the authoritative declarations (§2 "One home per fact")
#    A project carrying PROTECTED.md at its root declares its own zones there. Its
#    backticked referents, globs and ranges reduced to their parent, are the prefixes.

# Referents come from the project's own "Protected" section only, and from the first table
# column of it. A PROTECTED.md also lists a "Safe write-path" whose files are the exact
# opposite of protected: reading the whole file inverts the declaration and marks every
# editable document a conflict.
protected_tokens(){
  local f="$1" line
  sed -n '/^##.*[Pp]rotected/,/^## /p' "$f" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      '|'*) printf '%s\n' "$line" | sed 's/^[^|]*|//; s/|.*$//' \
              | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' || true ;;
      '-'*) printf '%s\n' "$line" | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' || true ;;
    esac
  done
}

declare -a PRE=()
load_protected(){
  local f d tok red
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d=$(dirname "$f")
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      case "$tok" in
        *.md|*.json|*.txt|*.ya?ml|*.sh|*.py|*.cjs|*.ts|*/|*'*'|*'..'*) : ;;
        *) continue ;;
      esac
      red=$(printf '%s' "$tok" | sed 's/\*.*$//; s/\.\..*$//; s#/*$##')
      [ -n "$red" ] || red='.'
      case "$red" in
        '~'*) red="$HOME_DIR${red#\~}" ;;
        /*)   : ;;
        *)    red="$d/$red" ;;
      esac
      PRE+=("${red%/}")
    done < <(protected_tokens "$f")
  done < <(find "$HOME_DIR" -maxdepth 3 -name 'PROTECTED.md' \
             -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | sort)
}

is_protected(){
  local p="$1" pre
  for pre in ${PRE[@]+"${PRE[@]}"}; do
    case "$p" in "$pre"|"$pre"/*) return 0 ;; esac
  done
  return 1
}

# ── slop detectors ─────────────────────────────────────────────────────────────
# One TSV record per finding: class <TAB> path <TAB> line <TAB> detail

SLOP=""
add_slop(){ SLOP="${SLOP}$1"$'\n'; }

# the line-level detectors, each reduced from docs/AGENTS.md's slop checklist
scan_slop_file(){
  local f="$1" abs="$2" cls pat n rest ln no w occ tmp caps=0 tok
  local -a L=()
  local total i blk j infence=0
  while IFS=$'\t' read -r cls pat; do
    [ -n "$cls" ] || continue
    while IFS=: read -r n rest; do
      [ -n "${n:-}" ] || continue
      add_slop "$cls	$f	$n	${rest:0:110}"
    done < <(grep -nEi -e "$pat" "$abs" 2>/dev/null || true)
  done <<'PATTERNS'
HISTORY	\b(previously|formerly|no longer|used to|renamed|was moved|has been moved|not yet|coming soon)\b
STATUS	\b(TODO|FIXME|WIP|implemented!|future:|unimplemented)\b
PATTERNS
  # The position-aware pass: walls and emphasis need a line's length, and a preamble is
  # only slop when its block runs past the two lines the doctrine allows — neither is
  # expressible as a line regex. Code fences, table rows and headings are structural, not
  # prose, so they are excluded from the emphasis density; otherwise a table of identifiers
  # reads as emphasis inflation.
  mapfile -t L < "$abs"
  total=${#L[@]}
  for ((i=0; i<total; i++)); do
    ln="${L[$i]}"
    no=$((i+1))
    case "$ln" in '```'*) infence=$((1-infence)); continue ;; esac
    if [ "$infence" = 1 ]; then continue; fi
    read -ra toks <<< "$ln"
    w=${#toks[@]}
    if [ "$w" -gt "$WALL_WORDS" ]; then
      add_slop "WALL	$f	$no	${w} words on one physical line"
    fi
    tmp=${ln//\*\*/}
    occ=$(( (${#ln} - ${#tmp}) / 2 ))
    if [ "$occ" -ge "$EMPHASIS_MARKS" ]; then
      add_slop "EMPHASIS	$f	$no	${occ} bold markers on one line"
    fi
    case "$ln" in
      *'What this file is'*|*'What this document is'*|'This file defines '*|'This file is '*|'This document defines '*|'This document is '*)
        blk=1; j=$((i+1))
        while [ "$j" -lt "$total" ] && [ -n "${L[$j]}" ]; do blk=$((blk+1)); j=$((j+1)); done
        if [ "$blk" -gt 2 ]; then
          add_slop "PREAMBLE	$f	$no	${blk}-line preamble (the doctrine allows two)"
        fi ;;
    esac
    case "$ln" in '|'*|'#'*|'>'*|'    '*) continue ;; esac
    for tok in ${toks[@]+"${toks[@]}"}; do
      case "$tok" in *[a-z]*) continue ;; esac
      if [ "${#tok}" -ge 4 ]; then caps=$((caps+1)); fi
    done
  done
  if [ "$caps" -gt 0 ]; then
    add_slop "CAPS	$f	0	${caps} all-caps token(s) in prose"
  fi
}

# cross-file duplicates — the executable form of "one home per fact"
DUP_H=""
DUP_N=""

collect_duplicates(){
  local f abs n rest k
  for f in ${SURF[@]+"${SURF[@]}"}; do
    abs=$(abs_of "$f")
    [ -f "$abs" ] || continue
    while IFS=: read -r n rest; do
      [ -n "${n:-}" ] || continue
      k=$(norm "$rest")
      [ "${#k}" -ge 12 ] || continue
      DUP_H="${DUP_H}${k}	${f}	${n}"$'\n'
    done < <(grep -nE '^#{1,6} ' "$abs" 2>/dev/null || true)
    while IFS=: read -r n rest; do
      [ -n "${n:-}" ] || continue
      case "$rest" in '#'*) continue ;; esac
      k=$(norm "$rest")
      [ "${#k}" -ge 24 ] || continue
      DUP_N="${DUP_N}${k}	${f}	${n}"$'\n'
    done < <(grep -nEi -e '\b(must|never|always|forbidden|required|shall)\b' "$abs" 2>/dev/null || true)
  done
}

# emit one row per normalized key that appears in two or more distinct files
dup_rows(){
  local tsv="$1" class="$2" k f n kf
  local -A seen=() nf=() where=()
  while IFS=$'\t' read -r k f n; do
    [ -n "$k" ] || continue
    kf="$k|$f"
    [ -n "${seen[$kf]:-}" ] && continue
    seen[$kf]=1
    nf["$k"]=$(( ${nf[$k]:-0} + 1 ))
    where["$k"]="${where[$k]:-}$f:$n "
  done <<< "$tsv"
  if [ "${#nf[@]}" -gt 0 ]; then
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      [ "${nf[$k]:-0}" -ge 2 ] || continue
      add_slop "$class	${where[$k]% }	0	duplicate home: \"$(printf '%.60s' "$k")\""
    done < <(printf '%s\n' "${!nf[@]}" | sort -u)
  fi
}

# ── measurement ────────────────────────────────────────────────────────────────

ROWS=""

sum_field(){   # N < tsv — integer sum of field N
  local n="$1" total=0 r v
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    v=$(printf '%s' "$r" | fld "$n")
    case "$v" in ''|*[!0-9]*) continue ;; esac
    total=$((total+v))
  done
  printf '%s' "$total"
}

measure(){
  local f abs w c st zone
  for f in ${SURF[@]+"${SURF[@]}"}; do
    abs=$(abs_of "$f")
    c="${CEIL[$f]:--}"
    zone="${ZONE[$f]:-edit}"
    if [ ! -f "$abs" ]; then
      ROWS="${ROWS}${f}	MISSING	0	0	0	0	${c}	${zone}"$'\n'
      continue
    fi
    w=$(words_of "$abs")
    if [ "$zone" != edit ] || [ "$c" = '-' ]; then
      st="$zone"
      [ "$zone" = edit ] && st='report-only'
    elif [ "$w" -gt "$c" ]; then
      st=OVER
    else
      st=ok
    fi
    # an edit-zone row that actually sits inside a declared protected zone is a conflict
    if [ "$zone" = edit ] && is_protected "$abs"; then st="CONFLICT"; fi
    ROWS="${ROWS}${f}	${st}	$(lines_of "$abs")	$(bytes_of "$abs")	${w}	$(est_tok "$abs")	${c}	${zone}"$'\n'
  done
}

# ── views ──────────────────────────────────────────────────────────────────────

fld(){ sed "s/^\([^\t]*\t\)\{$(($1-1))\}//; s/\t.*$//"; }

list_view(){
  local r
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    printf '%6s %-12s %7s/%-7s %5sL %6sB %s\n' \
      "$(printf '%s' "$r" | fld 5)" "$(printf '%s' "$r" | fld 2)" \
      "$(printf '%s' "$r" | fld 5)" "$(printf '%s' "$r" | fld 7)" \
      "$(printf '%s' "$r" | fld 3)" "$(printf '%s' "$r" | fld 4)" \
      "$(printf '%s' "$r" | fld 1)"
  done <<< "$ROWS"
}

slop_view(){ printf '%s' "$SLOP" | sed '/^$/d' | sort | while IFS=$'\t' read -r cls where n detail; do
    printf '%-10s %s:%s  %s\n' "$cls" "$where" "$n" "$detail"
  done; }

slop_count(){ local cls="$1"; printf '%s' "$SLOP" | sed '/^$/d' | grep -c "^${cls}	" || true; }

# Evidence density — the measurement behind a classification, not a taste call.
# §3.1 orders numbers, thresholds, citations and falsifiers to stay VERBATIM, so a document
# built out of them is not compressible prose: deleting one fails §3.4. This view makes that
# claim checkable per document instead of asserted. counts per 100 words:
#   NUM   tokens carrying a digit (versions, defaults, caps, byte counts, dates)
#   CITE  backticked references to files, packages or paths
#   FALSE falsifier lines ("did not confirm", "deferred", "not shipped", "no stability promise")
density_view(){
  local r f abs w nums cits fals dens
  printf '%-46s %6s %6s %6s %6s %6s %s\n' DOCUMENT WORDS NUM CITE FALSE DENS ZONE
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    f=$(printf '%s' "$r" | fld 1)
    abs=$(abs_of "$f")
    [ -f "$abs" ] || continue
    w=$(printf '%s' "$r" | fld 5)
    case "$w" in ''|*[!0-9]*) w=0 ;; esac
    nums=$(grep -oE '[A-Za-z0-9_./-]*[0-9][A-Za-z0-9_./-]*' "$abs" 2>/dev/null | grep -c . || true)
    cits=$(grep -oE '`[^`]+`' "$abs" 2>/dev/null | grep -cE '\.md|/|\.cjs|\.js|\.yml' || true)
    fals=$(grep -ciE 'did not confirm|not confirmed|not shipped|deferred|never reclaimed|not read in detail|no stability promise' "$abs" 2>/dev/null || true)
    if [ "$w" -gt 0 ]; then dens=$(( (nums + cits + fals) * 100 / w )); else dens=0; fi
    printf '%-46s %6s %6s %6s %6s %6s %s\n' "$f" "$w" "$nums" "$cits" "$fals" "$dens" "$(printf '%s' "$r" | fld 8)"
  done <<< "$ROWS"
}

discover(){
  local found p declared hit
  found=$(find "$HOME_DIR" -maxdepth 3 -type f \
      \( -name 'AGENTS.md' -o -name 'CLAUDE.md' -o -name 'README.md' -o -name 'PROTECTED.md' \
         -o -name 'GOVERNANCE.md' -o -name 'RULES.md' -o -name 'INTEGRITY.md' \
         -o -name 'AGENT-ERGONOMICS.md' -o -name 'design.md' -o -name 'CONTEXT.md' \
         -o -name 'ONBOARDING.md' -o -name 'FOUNDATIONAL-BRIEF.md' \) \
      -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*' \
      -not -path '*/Archive/*' -not -path '*/archive*' -not -path '*/.cache/*' \
      -not -path '*/.local/*' -not -path '*/.config/*' -not -path '*/Applications/*' \
      -not -path '*/Downloads/*' -not -path '*/snap/*' -not -path '*/.hermes/*' \
      -not -path '*/.dsh/*' -not -path '*/.openclaw/*' -not -path '*/.agents/*' \
      2>/dev/null | sed "s#^$HOME_DIR/##" | sort)
  printf '%s\n' "$found" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    hit=0
    for declared in ${SURF[@]+"${SURF[@]}"}; do
      [ "$declared" = "$p" ] && { hit=1; break; }
    done
    [ "$hit" = 0 ] && printf 'UNDECLARED\t%s\n' "$p"
  done
}

# ── content digests ────────────────────────────────────────────────────────────
# Size is not integrity. A document can lose half its bytes to a silent rewrite, or vanish, and
# still sit "within ceiling" — which is exactly how the crew-research-council declaration was lost
# on 2026-09-21: it was never committed, so nothing on disk remembered it was supposed to exist.
# The digest layer pins each declared document by content. Intentional change is a two-step act:
# edit, then `--record` (and say why in the receipt). Everything else is a failure:
#   ok     recorded == on disk
#   DRIFT  bytes changed since the last recording
#   NEW    declared but never recorded
#   GONE   recorded but absent from disk — a deletion, reported only after the recovery probe has
#          checked where the bytes still survive (see THE RECOVERY PROBE below)
# `--record` NEVER drops a digest for a file that is gone; it carries the old digest forward, so a
# deletion cannot be laundered by re-recording the surface without it.
#
# THE COMMIT BINDING (second layer, added 2026-09-21)
#   A recording that pins bytes no commit holds is a blessing with no history behind it: a revert,
#   a reset or a fresh clone loses the document, and nothing on disk says so. So a row carries the
#   commit it was accepted under:  path <TAB> sha256 <TAB> words <TAB> blob <TAB> commit <TAB> bind
#   `bind` is `committed` (the working tree equaled HEAD's blob for that path) or `no-repo` (the
#   document sits outside version control, so there is no commit to bind to — counted and named,
#   never silent). `--record` REFUSES a changed document that no commit holds, in either form: the
#   working tree differs from HEAD, or the document is outside version control altogether. A first
#   pin of an out-of-git document is allowed, because it overwrites no state — but once pinned, a
#   change to it is refused, since nothing can tell an intended edit from a silent rewrite there.
#   A refusal keeps the previous row and exits 1, so the gate cannot be turned green by re-recording
#   a change the repository does not hold. The remedy is the same in both cases: get it into a commit,
#   or into version control.
#   `--check` re-derives the whole chain and fails when any link breaks:
#     BIND-FAIL  the recorded commit is gone from the repository, or no longer holds the recorded
#                bytes for that path, or the working tree is not the bytes that commit holds
#     NO-COMMIT  the document sits in a repo with a committed version, but its row carries no
#                commit — recorded before this layer existed; re-record after committing
#   Threat model, stated exactly: a row cannot be forged, because `blob` must equal
#   `git rev-parse <commit>:<path>` for a commit that exists in that repository. Editing
#   digests.tsv by hand can therefore bless only bytes a real commit already holds — never
#   uncommitted bytes, and never bytes that were never committed at all.

DIG_LOADED=0
DIG_FAILS=0
DIG_UNBOUND=0
DIG_FINDINGS=""
declare -A REC=() RW=() RBLOB=() RCOMMIT=() RBIND=()

sha_of(){ sha256sum "$1" | sed 's/[[:space:]].*$//'; }

# ── the commit binding ─────────────────────────────────────────────────────────
# git is a hard dependency of this layer: without it nothing can be bound, and a silent
# degradation to "no protection" would be worse than a failure, so it fails instead.
GIT_OK=0
if command -v git >/dev/null 2>&1; then GIT_OK=1; fi

# The work tree containing a declared document, or empty. Memoized per directory: 26 documents
# usually live in a handful of repositories, and `rev-parse --show-toplevel` walks upward.
# `+set` distinguishes a cached empty answer (no repo) from a key that was never computed.
declare -A REPO_OF=()
repo_of_abs(){
  local abs="$1" d r
  d=$(dirname "$abs")
  if [ -n "${REPO_OF[$d]+set}" ]; then printf '%s' "${REPO_OF[$d]}"; return 0; fi
  r=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)
  REPO_OF["$d"]="$r"
  printf '%s' "$r"
}
repo_of(){ repo_of_abs "$(abs_of "$1")"; }

# one line: state <TAB> blob <TAB> commit <TAB> bind   (state: ok | uncommitted | untracked | no-repo)
# `git diff --quiet HEAD -- <rel>` compares the working tree to HEAD across staged and unstaged
# changes, so "the change is committed" is one question with one answer.
bind_of(){
  local f="$1" abs repo rel commit blob
  [ "$GIT_OK" = 1 ] || { printf 'no-git\t-\t-\tno-repo'; return 0; }
  abs=$(abs_of "$f"); repo=$(repo_of "$f")
  [ -n "$repo" ] || { printf 'no-repo\t-\t-\tno-repo'; return 0; }
  rel="${abs#"$repo"/}"
  if ! git -C "$repo" cat-file -e "HEAD:$rel" 2>/dev/null; then
    printf 'untracked\t-\t-\t-'; return 0
  fi
  if ! git -C "$repo" diff --quiet HEAD -- "$rel" 2>/dev/null; then
    printf 'uncommitted\t-\t-\t-'; return 0
  fi
  commit=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)
  blob=$(git -C "$repo" rev-parse "HEAD:$rel" 2>/dev/null || true)
  printf 'ok\t%s\t%s\tcommitted' "${blob:--}" "${commit:--}"
}

# ── THE RECOVERY PROBE ─────────────────────────────────────────────────────────
# GONE is a claim about ONE snapshot (the working tree), not about the world. Before the audit
# reports a document as gone it must ask where else the recorded bytes might live, because the
# answer changes the remedy: a recoverable loss is an accident waiting to be undone, an
# unrecoverable one is an Owner ruling. The probe is READ-ONLY — it never writes an object, never
# creates a ref, never touches a stash — and every git call fails silently, because a probe that
# cannot run must not invent a false hope either.
#
#   1. recorded commit   `git rev-parse <commit>:<path>` — if the row's own commit still holds
#                        the path, the loss is one checkout away.
#   2. the index         `git ls-files -s` — an unstaged deletion leaves the bytes in the index,
#                        one `git checkout -- <path>` away.
#   3. any stash         `git stash list`, then `git cat-file -e <stash>:<path>` per entry — the
#                        stash's own tree first, then its base parent — because a stashed deletion
#                        is the second most common way bytes vanish from a tree.
#   4. the HEAD reflog  — by object id, not by path: a bound row carries the git blob id of the
#                        recorded bytes; a legacy (pre-binding) row has none, so candidates are
#                        matched by CONTENT — the sha256 of each candidate's bytes must equal the
#                        recorded digest. Deleted content survives until gc.
#   5. reachable history — `git log --all -- <path>`: a commit the row does not name (a restore,
#                        an ancestor, another branch) may still hold the exact bytes. gc can
#                        never erase these, so a history verdict is stable.
#   6. unreachable      — `git fsck --unreachable`, same matching: a dangling blob, gone at the
#                        next gc.
#
# Honest ceiling: probes 4–6 stop at the gc horizon. Once gc has pruned, a loss with no commit,
# index, or reachable history behind it IS unrecoverable, and the probe must say so (no-trace),
# not guess.

# one line of evidence: <where>TAB<detail>. Empty when nothing recoverable is found. Memoized per
# (path, recorded digest): the answer cannot change inside one run.
declare -A RECOVERY_CACHE=()
recovery_probe(){
  local f="$1" rsha="$2" abs repo rel ev key gsha bsha loc sid at
  local TAB=$'\t'
  abs=$(abs_of "$f")
  if [ -f "$abs" ]; then printf ''; return 0; fi
  key="$f|$rsha"
  if [ -n "${RECOVERY_CACHE[$key]+set}" ]; then printf '%s' "${RECOVERY_CACHE[$key]}"; return 0; fi
  [ "$GIT_OK" = 1 ] && [ -n "$rsha" ] || { RECOVERY_CACHE["$key"]=''; return 0; }
  repo=$(repo_of "$f")
  [ -n "$repo" ] || { RECOVERY_CACHE["$key"]=''; return 0; }
  rel="${abs#"$repo"/}"
  ev=''
  # 1. the recorded commit's own tree
  gsha=$(git -C "$repo" rev-parse "${RCOMMIT[$f]:--}:$rel" 2>/dev/null || true)
  if [ -n "$gsha" ] && git -C "$repo" cat-file -e "$gsha" 2>/dev/null; then
    ev="commit${TAB}git checkout ${RCOMMIT[$f]:0:12} -- $rel restores the recorded bytes (blob $gsha)"
  fi
  # 2. the index — a deletion leaves the bytes staged until the deletion itself is staged
  if [ -z "$ev" ]; then
    gsha=$(git -C "$repo" ls-files -s -- "$rel" 2>/dev/null | awk 'NR==1{print $2}')
    if [ -n "$gsha" ] && git -C "$repo" cat-file -e "$gsha" 2>/dev/null; then
      ev="index${TAB}the recorded bytes are still staged — git checkout -- $rel restores them (blob $gsha)"
    fi
  fi
  # 3. any stash — the stash's worktree tree first, then its base parent
  if [ -z "$ev" ]; then
    sid=$(git -C "$repo" stash list 2>/dev/null | while IFS= read -r line; do
            s=${line%%:*}
            for at in "$s" "$s^1"; do
              git -C "$repo" cat-file -e "${at}:$rel" 2>/dev/null && { printf '%s\n' "$at"; break 2; }
            done
          done)
    if [ -n "$sid" ]; then
      ev="stash${TAB}deleted content exists in ${sid} — git checkout ${sid} -- $rel restores it"
    fi
  fi
  # 4. reflog + unreachable, by object id: the recorded sha256 is a content handle whose git blob
  # id the row carries, so the object database can be asked for those exact bytes.
  if [ -z "$ev" ]; then
    bsha=$(awk -F'\t' -v want="$rsha" '$2==want && $5 ~ /^[0-9a-f]{40}$/ {print $5; exit}' "$DIGESTS" 2>/dev/null)
    if [ -z "$bsha" ]; then
      # legacy (pre-binding) row: no git blob id is known, so candidates are matched by CONTENT —
      # the sha256 of the candidate's bytes must equal the recorded digest
      match_blob(){ git -C "$repo" cat-file blob "$1" 2>/dev/null | sha256sum | cut -d' ' -f1 | grep -qx "$rsha"; }
    elif git -C "$repo" cat-file -e "$bsha" 2>/dev/null; then
      # bound row: the recorded git blob id IS the handle
      match_blob(){ [ "$1" = "$bsha" ]; }
    fi
    if [ "$(declare -F match_blob)" ]; then
      loc=$(git -C "$repo" reflog --format='%H' HEAD 2>/dev/null | while IFS= read -r c; do
              g=$(git -C "$repo" rev-parse -q --verify "${c}:$rel" 2>/dev/null || true)
              [ -n "$g" ] && match_blob "$g" && { git -C "$repo" describe --always "$c" 2>/dev/null; break; }
            done)
      if [ -n "$loc" ]; then
        ev="reflog${TAB}the recorded bytes survive as blob ${bsha:-<content-matched>} at ${loc} in the HEAD reflog history — git cat-file blob <sha> > $rel restores them"
      else
        # reachable history: a commit that still holds the path at the recorded bytes, even one
        # the recorded row does not name (a restore, an ancestor, another branch)
        loc=$(git -C "$repo" log --all --format='%H' -- "$rel" 2>/dev/null | while IFS= read -r c; do
                g=$(git -C "$repo" rev-parse -q --verify "${c}:$rel" 2>/dev/null || true)
                [ -n "$g" ] && match_blob "$g" && { git -C "$repo" describe --always "$c" 2>/dev/null; break; }
              done)
        if [ -n "$loc" ]; then
          ev="history${TAB}the recorded bytes survive at ${loc} in reachable history — git checkout ${loc} -- $rel restores them"
        else
          ub=$(git -C "$repo" fsck --unreachable 2>/dev/null | awk '$2=="blob"{print $3}' | while IFS= read -r u; do
                 match_blob "$u" && { printf '%s\n' "$u"; break; }
               done)
          if [ -n "$ub" ]; then
            ev="unreachable${TAB}the recorded bytes survive as UNREACHABLE blob $ub — gc will erase them; git cat-file blob $ub > $rel restores them"
          fi
        fi
      fi
    fi
  fi
  RECOVERY_CACHE["$key"]="$ev"
  printf '%s' "$ev"
}

# ok | unbound | unbound-repo | no-git | bind-fail:<reason>
# `dst` is the digest-layer status, used to avoid reporting the same change twice: when the digest
# layer already says DRIFT, the working tree differing from the commit is the same fact.
bind_verify(){
  local f="$1" dst="$2" abs repo rel blob commit got
  [ "$GIT_OK" = 1 ] || { printf 'no-git'; return 0; }
  blob="${RBLOB[$f]:--}"; commit="${RCOMMIT[$f]:--}"
  abs=$(abs_of "$f"); repo=$(repo_of "$f")
  [ -n "$repo" ] || { printf 'unbound'; return 0; }
  if [ "$blob" = '-' ] || [ "$commit" = '-' ]; then printf 'unbound-repo'; return 0; fi
  rel="${abs#"$repo"/}"
  if ! git -C "$repo" cat-file -e "$commit" 2>/dev/null; then
    printf 'bind-fail:the recorded commit %s is not in the repository' "${commit:0:12}"; return 0
  fi
  got=$(git -C "$repo" rev-parse "$commit:$rel" 2>/dev/null || true)
  if [ "$got" != "$blob" ]; then
    printf 'bind-fail:commit %s does not hold the recorded bytes for this path' "${commit:0:12}"; return 0
  fi
  if [ "$dst" = ok ] && [ -f "$abs" ]; then
    got=$(git -C "$repo" hash-object -- "$abs" 2>/dev/null || true)
    if [ "$got" != "$blob" ]; then
      printf 'bind-fail:the working tree is not the bytes that commit holds'; return 0
    fi
  fi
  printf 'ok'
}

# the same verdict, collapsed to a column width
bind_label(){
  case "$(bind_verify "$1" "$2")" in
    ok)           printf 'ok' ;;
    unbound)      printf 'no-repo' ;;
    unbound-repo) printf 'NO-COMMIT' ;;
    no-git)       printf 'NO-GIT' ;;
    bind-fail:*)  printf 'FAIL' ;;
    *)            printf '?' ;;
  esac
}

# ── the ledger's own binding ────────────────────────────────────────────────────
# Everything above binds DOCUMENTS to commits. The three files the gate itself reads were the last
# thing in the workspace with no history behind them: the declaration says what is measured, the
# recording says what was blessed, and this tool is the logic that decides. Any of the three could
# be rewritten or deleted in place and leave nothing behind — which is how
# crew-research-council/PROTECTED.md was lost (§11 of the receipt). So the same question is asked of
# them: does a commit hold these bytes?
#
# Scope, stated so it is not a hidden rule: only ledger files INSIDE $HOME_DIR are checked. A
# self-test run points HOME_DIR at a fixture, so the fixture's ledger is what gets judged and the
# real tool is not dragged in.
#
# Honest ceiling: this stops at "whatever is committed". A commit that weakens the checker is not
# detected by the checker — the diff is the only signal. Git is the anchor here, not cryptography.
LEDGER_FAILS=0
LEDGER_FINDINGS=""
# THE LEDGER'S OWN BINDING — the gate's three inputs (the declaration `ceilings.tsv`, the
# recording `digests.tsv`, and this script) are held to the same question as the documents: does a
# commit hold these bytes? A `dirty` or `untracked` or `no-repo` answer is a failure, because an
# edit to any of the three changes what the gate says without leaving a trace.

tool_abs(){
  case "$0" in
    /*)  printf '%s' "$0" ;;
    */*) printf '%s/%s' "$PWD" "$0" ;;
    *)   printf '%s/%s' "$PWD" "$0" ;;
  esac
}

# ok | dirty | untracked | no-repo | no-git | absent
ledger_state(){
  local abs="$1" repo rel
  [ -f "$abs" ] || { printf 'absent'; return 0; }
  [ "$GIT_OK" = 1 ] || { printf 'no-git'; return 0; }
  repo=$(repo_of_abs "$abs")
  [ -n "$repo" ] || { printf 'no-repo'; return 0; }
  rel="${abs#"$repo"/}"
  if ! git -C "$repo" cat-file -e "HEAD:$rel" 2>/dev/null; then printf 'untracked'; return 0; fi
  if ! git -C "$repo" diff --quiet HEAD -- "$rel" 2>/dev/null; then printf 'dirty'; return 0; fi
  printf 'ok'
}

ledger_abs_list(){
  local a t
  for a in "$CEILINGS" "$DIGESTS"; do
    a=$(abs_of "$a")
    case "$a" in "$HOME_DIR"/*) printf '%s\n' "$a" ;; esac
  done
  t=$(tool_abs)
  case "$t" in "$HOME_DIR"/*) [ -f "$t" ] && printf '%s\n' "$t" ;; esac
}

build_ledger_findings(){
  LEDGER_FINDINGS=""; LEDGER_FAILS=0
  local a st fails=0
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    st=$(ledger_state "$a")
    case "$st" in
      ok)        ;;
      absent)    fails=$((fails+1)); LEDGER_FINDINGS="${LEDGER_FINDINGS}FAIL  [ledger] ${a#$HOME_DIR/}: missing"$'\n' ;;
      no-git)    fails=$((fails+1)); LEDGER_FINDINGS="${LEDGER_FINDINGS}FAIL  [ledger] ${a#$HOME_DIR/}: git is unavailable, so its history cannot be checked"$'\n' ;;
      no-repo)   fails=$((fails+1)); LEDGER_FINDINGS="${LEDGER_FINDINGS}FAIL  [ledger] ${a#$HOME_DIR/}: not under version control — an edit or a deletion leaves no trace (git init, then commit it)"$'\n' ;;
      untracked) fails=$((fails+1)); LEDGER_FINDINGS="${LEDGER_FINDINGS}FAIL  [ledger] ${a#$HOME_DIR/}: not committed — nothing in history holds it"$'\n' ;;
      dirty)     fails=$((fails+1)); LEDGER_FINDINGS="${LEDGER_FINDINGS}FAIL  [ledger] ${a#$HOME_DIR/}: uncommitted changes — commit it, so any edit leaves a trace"$'\n' ;;
    esac
  done < <(ledger_abs_list)
  LEDGER_FAILS=$fails
}

# one header line for the report: which commit the ledger is at, and whether it is clean
ledger_headline(){
  local a st repo commit any=0 dirty=0
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    any=$((any+1))
    st=$(ledger_state "$a")
    [ "$st" = ok ] || dirty=$((dirty+1))
    repo=$(repo_of_abs "$a")
    if [ -n "$repo" ]; then commit=$(git -C "$repo" rev-parse --short=8 HEAD 2>/dev/null || true); else commit='-'; fi
  done < <(ledger_abs_list)
  if [ "$any" = 0 ]; then printf 'not in scope'; return 0; fi
  if [ "$dirty" = 0 ]; then printf '%s · %s files committed' "$commit" "$any"; else printf '%s · %s of %s file(s) not committed' "$commit" "$dirty" "$any"; fi
}

load_digests(){
  REC=(); RW=(); RBLOB=(); RCOMMIT=(); RBIND=(); DIG_LOADED=0
  [ -f "$DIGESTS" ] || return 1
  local p s w b c bd rest
  while IFS=$'\t' read -r p s w b c bd rest || [ -n "${p:-}" ]; do
    p="${p%$'\r'}"; s="${s%$'\r'}"; w="${w%$'\r'}"
    [ -n "$p" ] || continue
    case "$p" in '#'*) continue ;; esac
    # a 3-column row is a recording from before the binding layer: bind stays `-` so --check can
    # name it NO-COMMIT instead of quietly treating an unbound row as verified
    REC["$p"]="$s"; RW["$p"]="$w"
    RBLOB["$p"]="${b:--}"; RCOMMIT["$p"]="${c:--}"; RBIND["$p"]="${bd:--}"
  done < "$DIGESTS"
  DIG_LOADED=1
  return 0
}

digest_status(){
  local f="$1" abs
  abs=$(abs_of "$f")
  if [ -z "${REC[$f]:-}" ]; then
    if [ -f "$abs" ]; then printf 'NEW'; else printf 'NEW'; fi
    return 0
  fi
  if [ ! -f "$abs" ]; then printf 'GONE'; return 0; fi
  if [ "$(sha_of "$abs")" = "${REC[$f]}" ]; then printf 'ok'; else printf 'DRIFT'; fi
}

build_digest_findings(){
  DIG_FINDINGS=""; DIG_FAILS=0; DIG_UNBOUND=0
  local r f st bres ev fails=0 unbound=0
  if [ "$DIG_LOADED" != 1 ]; then
    DIG_FINDINGS="FAIL  [digest] the surface is not pinned: ${DIGESTS#$HOME_DIR/} is absent — run --record"$'\n'
    DIG_FAILS=1
    return 0
  fi
  if [ "$GIT_OK" != 1 ]; then
    DIG_FINDINGS="FAIL  [bind] git is unavailable, so no recording can be bound to a commit"$'\n'
    fails=$((fails+1))
  fi
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    f=$(printf '%s' "$r" | fld 1)
    st=$(digest_status "$f")
    case "$st" in
      ok) ;;
      DRIFT) DIG_FINDINGS="${DIG_FINDINGS}FAIL  [digest] ${f}: bytes changed since the last recording — re-record if intended, and record why"$'\n'; fails=$((fails+1)) ;;
      NEW)   DIG_FINDINGS="${DIG_FINDINGS}FAIL  [digest] ${f}: declared but never recorded — run --record"$'\n'; fails=$((fails+1)) ;;
      GONE)  ev=$(recovery_probe "$f" "${REC[$f]:-}" | head -n 1)
             case "${ev%%$'\t'*}" in
               commit|index|stash|reflog|history|unreachable)
                 fails=$((fails+1))
                 DIG_FINDINGS="${DIG_FINDINGS}FAIL  [digest] ${f}: absent from disk — a deletion is an Owner ruling, not a re-record — but the recorded bytes are RECOVERABLE: ${ev#*$'\t'}"$'\n' ;;
               *)
                 fails=$((fails+1))
                 DIG_FINDINGS="${DIG_FINDINGS}FAIL  [digest] ${f}: recorded but absent from disk, and no recovery probe found the bytes (recorded commit, index, stash, reflog, unreachable objects) — a deletion is an Owner ruling, not a re-record"$'\n' ;;
             esac ;;
    esac
    # the commit binding. A row that never existed has nothing to verify (NEW already fired).
    [ -n "${REC[$f]:-}" ] || continue
    bres=$(bind_verify "$f" "$st")
    case "$bres" in
      ok) ;;
      no-git) ;;
      unbound)      unbound=$((unbound+1))
                    DIG_FINDINGS="${DIG_FINDINGS}WARN  [bind] ${f}: outside any git repository — bytes pinned, but no commit holds them"$'\n' ;;
      unbound-repo) fails=$((fails+1))
                    DIG_FINDINGS="${DIG_FINDINGS}FAIL  [bind] ${f}: sits in a git repository but its recording carries no commit — re-record after committing"$'\n' ;;
      bind-fail:*)  fails=$((fails+1))
                    DIG_FINDINGS="${DIG_FINDINGS}FAIL  [bind] ${f}: ${bres#bind-fail:}"$'\n' ;;
    esac
  done <<< "$ROWS"
  DIG_FAILS=$fails
  DIG_UNBOUND=$unbound
}

digests_view(){
  local r f abs st rs as bs cs w ev
  printf '%-42s %-7s %-9s %8s %10s %14s %6s %s\n' DOCUMENT DIGEST BIND COMMIT RECORDED ON-DISK WORDS ZONE
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    f=$(printf '%s' "$r" | fld 1)
    w=$(printf '%s' "$r" | fld 5)
    abs=$(abs_of "$f")
    st=$(digest_status "$f")
    if [ -f "$abs" ]; then as=$(sha_of "$abs"); else as='-'; fi
    if [ "$st" = GONE ]; then
      ev=$(recovery_probe "$f" "${REC[$f]:-}" | head -n 1)
      case "${ev%%$'\t'*}" in
        commit|index|stash|reflog|history|unreachable) as="gone·${ev%%$'\t'*}" ;;
        *)                                     as='gone·no-trace' ;;
      esac
    fi
    rs="${REC[$f]:--}"; rs="${rs:0:8}"
    case "$as" in gone·*) ;; *) as="${as:0:8}" ;; esac
    cs="${RCOMMIT[$f]:--}"; [ "$cs" = '-' ] || cs="${cs:0:8}"
    bs=$(bind_label "$f" "$st")
    printf '%-42s %-7s %-9s %8s %10s %14s %6s %s\n' "$f" "$st" "$bs" "$cs" "$rs" "$as" "$w" \
      "$(printf '%s' "$r" | fld 8)"
  done <<< "$ROWS"
}

record_digests(){
  local r f abs sha w prev bst state blob commit bind reason
  local unchanged=0 changed=0 added=0 carried=0 unbound=0 refused=0 tmp
  tmp=$(mktemp)
  {
    printf '# content digests — recorded state, not law\n'
    printf '# path\tsha256\twords\tblob\tcommit\tbind\n'
    printf '# A document whose bytes differ from its recorded digest is DRIFT. Intentional change is a\n'
    printf '# two-step act: edit the document, COMMIT it, then --record, and say why in the receipt.\n'
    printf '# bind is `committed` (the working tree equals HEAD for that path) or `no-repo` (outside\n'
    printf '# version control, so no commit can hold it — counted and named, never silent).\n'
    printf '# --record REFUSES a changed document that no commit holds: the working tree differs from\n'
    printf '# HEAD, or the document sits outside version control entirely. It keeps the previous row\n'
    printf '# and exits 1, so a change the repository does not hold cannot be blessed by re-recording\n'
    printf '# the surface. A first pin of an out-of-git document is allowed (nothing is overwritten).\n'
    printf '# --record never drops a digest for a file that is gone: it carries the old digest forward,\n'
    printf '# so a deletion cannot be laundered by re-recording the surface without it.\n'
    printf '# recorded: %s\n' "$(date '+%Y-%m-%d %H:%M')"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      f=$(printf '%s' "$r" | fld 1)
      abs=$(abs_of "$f")
      w=$(printf '%s' "$r" | fld 5)
      # a document that is gone from disk is carried forward, never dropped (see the header)
      if [ ! -f "$abs" ]; then
        sha="${REC[$f]:-}"
        if [ -n "$sha" ]; then
          carried=$((carried+1)); w="${RW[$f]:-0}"
          printf 'CARRIED \t%s\tfile is gone; digest kept so the loss cannot be recorded away\n' "$f" >&2
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$f" "$sha" "$w" \
            "${RBLOB[$f]:--}" "${RCOMMIT[$f]:--}" "${RBIND[$f]:--}"
        fi
        continue
      fi
      bst=$(bind_of "$f")
      state=$(printf '%s' "$bst" | fld 1)
      blob=$(printf '%s' "$bst" | fld 2)
      commit=$(printf '%s' "$bst" | fld 3)
      bind=$(printf '%s' "$bst" | fld 4)
      sha=$(sha_of "$abs")
      prev="${REC[$f]:-}"
      # THE REFUSAL. A change that no commit holds is not a recording, it is a claim — whether the
      # working tree was never committed, or no repository holds the document at all. Both are
      # refused, because with no commit there is no way to tell an intended edit from a silent
      # rewrite, so neither may turn the gate green. The remedy is the same either way: commit it.
      reason=''
      case "$state" in
        uncommitted) reason='working tree differs from HEAD — commit, then re-record' ;;
        untracked)   reason='no commit holds it (absent from HEAD) — commit, then re-record' ;;
        *)           if [ "$bind" = no-repo ] && [ -n "$prev" ] && [ "$prev" != "$sha" ]; then
                       reason='the bytes changed and no repository holds them — put the document under version control, then re-record'
                     fi ;;
      esac
      if [ -n "$reason" ]; then
        refused=$((refused+1))
        # counted here too, so this line and the check summary both mean "declared documents that
        # sit outside version control" — the same number, not two different questions
        if [ "$bind" = no-repo ]; then unbound=$((unbound+1)); fi
        printf 'REFUSED \t%s\t%s\n' "$f" "$reason" >&2
        [ -n "$prev" ] && printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$f" "$prev" "${RW[$f]:-0}" "${RBLOB[$f]:--}" "${RCOMMIT[$f]:--}" "${RBIND[$f]:--}"
        continue
      fi
      if [ -z "$prev" ]; then
        added=$((added+1)); printf 'ADDED   \t%s\t%s\n' "$f" "$bind" >&2
      elif [ "$prev" = "$sha" ]; then
        unchanged=$((unchanged+1))
      else
        changed=$((changed+1))
        printf 'CHANGED \t%s\twords %s -> %s\n' "$f" "${RW[$f]:-?}" "$w" >&2
      fi
      if [ "$bind" = no-repo ]; then
        unbound=$((unbound+1))
        printf 'UNBOUND \t%s\toutside any git repository — pinned, but no commit holds it\n' "$f" >&2
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$f" "$sha" "$w" "$blob" "$commit" "$bind"
    done <<< "$ROWS"
  } > "$tmp"
  mv "$tmp" "$DIGESTS"
  printf 'recorded: %s doc(s) — %s unchanged, %s changed, %s added, %s carried forward (file gone), %s unbound (no repo)\n' \
    "${#SURF[@]}" "$unchanged" "$changed" "$added" "$carried" "$unbound"
  # the recording just changed, so the ledger it lives in is now uncommitted. Say so here rather
  # than only at --check time: this is the step at which a trace is either kept or dropped.
  local dst
  dst=$(ledger_state "$(abs_of "$DIGESTS")")
  case "$dst" in
    dirty|untracked) printf 'note: the recording is now uncommitted — commit it, so the re-record leaves a trace.\n' >&2 ;;
    no-repo)         printf 'note: the recording sits outside version control — nothing holds its history (git init, then commit it).\n' >&2 ;;
  esac
  if [ "$refused" -gt 0 ]; then
    printf 'record-refused: %s document(s) have no commit to bind to — a change with no commit cannot be blessed.\n' "$refused" >&2
    return 1
  fi
  return 0
}

# ── report ─────────────────────────────────────────────────────────────────────

report(){
  local today sw pw
  today=$(date '+%Y-%m-%d %H:%M')
  sw=$(printf '%s' "$SLOP" | sed '/^$/d' | grep -c . || true)
  pw=$(printf '%s' "$ROWS" | sed '/^$/d' | grep -c . || true)
  printf '# CONTEXT REGISTRY — generated, not law\n\n'
  printf '> generated: %s · declaration: `%s` · tool: `local/scripts/context-audit.sh`\n' \
    "$today" "${CEILINGS#$HOME_DIR/}"
  printf '> declaration digest: sha256=%s · bytes=%s\n' \
    "$(sha256sum "$CEILINGS" 2>/dev/null | sed 's/[[:space:]].*$//')" \
    "$(wc -c < "$CEILINGS" 2>/dev/null | tr -d ' ')"
  printf '> ledger: %s\n' "$(ledger_headline)"
  printf '> Counts are computed at emit time (R14). Re-run this file; never edit it.\n'
  printf '> words/lines/bytes are exact; tokens are an ESTIMATE (bytes/4).\n'
  printf '> The law is §3 of `CONSTITUTION.md`: reduce lines, never reduce meaning.\n'
  printf '> Burden of proof per line, from He et al. 2026 (arXiv:2607.17598: one disclosure\n'
  printf '> level is enough), Gloaguen et al. 2026 (arXiv:2602.11988: context files lower\n'
  printf '> success and raise cost >20%%), and Liu et al. 2024 (use is U-shaped in position).\n\n'
  printf '## 1. Surface — declared documents, measured\n\n'
  printf '| document | status | lines | bytes | words | ~tok | ceiling | zone | bind |\n'
  printf '|---|---|---|---|---|---|---|---|---|\n'
  local r rf
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    rf=$(printf '%s' "$r" | fld 1)
    printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
      "$rf" "$(printf '%s' "$r" | fld 2)" \
      "$(printf '%s' "$r" | fld 3)" "$(printf '%s' "$r" | fld 4)" \
      "$(printf '%s' "$r" | fld 5)" "$(printf '%s' "$r" | fld 6)" \
      "$(printf '%s' "$r" | fld 7)" "$(printf '%s' "$r" | fld 8)" \
      "$(bind_label "$rf" "$(digest_status "$rf")")"
  done <<< "$ROWS"
  printf '\n## 2. Counts (generated at emit time)\n\n```\n'
  printf 'declared=%s  surface_total_words=%s  surface_total_bytes=%s\n' \
    "$pw" "$(sum_field 5 <<< "$ROWS")" "$(sum_field 4 <<< "$ROWS")"
  printf 'over_ceiling=%s  missing=%s  conflicts=%s  slop_findings=%s\n' \
    "$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^OVER$' || true)" \
    "$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^MISSING$' || true)" \
    "$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^CONFLICT$' || true)" "$sw"
  printf 'digest_failures=%s  unbound=%s  (DRIFT / NEW / GONE / BIND-FAIL; run --digests for the table,\n' "$DIG_FAILS" "$DIG_UNBOUND"
  printf '%s--record to pin intent; a recording is bound to the commit that holds its bytes)\n' '  '
  printf 'ledger_failures=%s  (the declaration, the recording and this tool must each be committed:\n' "$LEDGER_FAILS"
  printf '%san uncommitted ledger is an edit with no trace)\n' '  '
  printf 'walls=%s  dup_headings=%s  dup_invariants=%s  history=%s  status=%s  preamble=%s  emphasis=%s  caps=%s\n' \
    "$(slop_count WALL)" "$(slop_count DUP-HEADING)" "$(slop_count DUP-INVARIANT)" \
    "$(slop_count HISTORY)" "$(slop_count STATUS)" "$(slop_count PREAMBLE)" \
    "$(slop_count EMPHASIS)" "$(slop_count CAPS)"
  printf '```\n'
  printf '\n## 3. Findings — filed, not fixed\n\n```\n'
  slop_view
  printf '%s' "$DIG_FINDINGS" | sed '/^$/d'
  printf '%s' "$LEDGER_FINDINGS" | sed '/^$/d'
  printf '```\n'
}

# ── self-test — the known-positive rule, same discipline as constitution-sweep.sh ──
self_test(){
  local tmp fails=0 got real_const="$CONSTITUTION" row_before row_after row_after2
  tmp=$(mktemp -d)
  mkdir -p "$tmp/fixture/proj"
  {
    printf '# Fixture context contract\n\n'
    printf 'This file previously described a thing that used to exist.\n'
    printf 'TODO finish this later.\n'
    printf 'Operations must never rename the archive directory in place.\n'
    printf 'x'
    i=0; while [ $i -lt 130 ]; do printf ' word%s' "$i"; i=$((i+1)); done
    printf '\n'
  } > "$tmp/fixture/proj/AGENTS.md"
  printf '**a** **b** **c** **d** **e** **f** **g** **h**\n' >> "$tmp/fixture/proj/AGENTS.md"
  {
    printf '# Fixture context contract\n\n'
    printf 'Operations must never rename the archive directory in place.\n'
  } > "$tmp/fixture/proj/README.md"
  {
    printf 'fixture/proj/AGENTS.md\t4\tedit\n'
    printf 'fixture/proj/README.md\t999\tedit\n'
  } > "$tmp/ceilings.tsv"

  # re-run the same code path against the fixture, in a subshell
  got=$(CEILINGS="$tmp/ceilings.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" --slop 2>/dev/null || true)
  printf '%s' "$got" | grep -q '^HISTORY' || { printf 'SELF-TEST: FAIL — planted history line not caught\n'; fails=$((fails+1)); }
  printf '%s' "$got" | grep -q '^WALL'    || { printf 'SELF-TEST: FAIL — planted paragraph wall not caught\n'; fails=$((fails+1)); }
  printf '%s' "$got" | grep -q '^EMPHASIS'|| { printf 'SELF-TEST: FAIL — planted emphasis inflation not caught\n'; fails=$((fails+1)); }
  printf '%s' "$got" | grep -q '^DUP-HEADING' || { printf 'SELF-TEST: FAIL — planted duplicate heading not caught\n'; fails=$((fails+1)); }
  printf '%s' "$got" | grep -q '^DUP-INVARIANT' || { printf 'SELF-TEST: FAIL — planted duplicate invariant not caught\n'; fails=$((fails+1)); }

  CEILINGS="$tmp/ceilings.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
    bash "$0" --check >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — planted over-ceiling file passed --check\n'; fails=$((fails+1)); }

  got=$(CEILINGS="$tmp/ceilings.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" 2>/dev/null | sed -n 's/^declared=\([0-9]*\).*/\1/p' || true)
  [ "$got" = 2 ] || { printf 'SELF-TEST: FAIL — declared count wrong (got %s, want 2)\n' "$got"; fails=$((fails+1)); }

  # the digest layer: an explicit re-record accepts intent, a silent rewrite is DRIFT, and a
  # deletion cannot be laundered by re-recording the surface without it
  CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
    bash "$0" --record >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --record failed on the fixture\n'; fails=$((fails+1)); }
  printf 'a silent rewrite appended by the fixture\n' >> "$tmp/fixture/proj/AGENTS.md"
  got=$(CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" --digests 2>/dev/null | grep -c 'DRIFT' || true)
  [ "$got" -ge 1 ] || { printf 'SELF-TEST: FAIL — planted silent rewrite not caught (DRIFT)\n'; fails=$((fails+1)); }

  rm -f "$tmp/fixture/proj/README.md"
  CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
    bash "$0" --record >/dev/null 2>&1 || true
  got=$(CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" --digests 2>/dev/null | grep -c 'GONE' || true)
  [ "$got" -ge 1 ] || { printf 'SELF-TEST: FAIL — a deletion was laundered by re-recording the surface\n'; fails=$((fails+1)); }

  # ── the recovery probe: a GONE verdict is reported only after the escape routes are checked ──
  git init -q "$tmp/rec" >/dev/null 2>&1 || true
  mkdir -p "$tmp/rec/proj"
  printf 'proj/AGENTS.md\t1000\tedit\n' > "$tmp/rec/ceilings.tsv"
  printf '# Recovery fixture\n\nOperations must never rename the archive directory in place.\n' \
    > "$tmp/rec/proj/AGENTS.md"
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: recovery base' >/dev/null 2>&1 || true
  recrun(){ CEILINGS="$tmp/rec/ceilings.tsv" DIGESTS="$tmp/rec/digests.tsv" HOME_DIR="$tmp/rec" \
            CONSTITUTION="$real_const" bash "$0" "$@" ; }
  recrun --record >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --record failed on the recovery fixture\n'; fails=$((fails+1)); }

  # a committed deletion: the recorded commit still holds the bytes, so the finding names the way out
  rm "$tmp/rec/proj/AGENTS.md"
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: deletion committed' >/dev/null 2>&1 || true
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·commit" ] || { printf 'SELF-TEST: FAIL — a committed deletion was not probed as recoverable (got "%s", want "gone·commit")\n' "$got"; fails=$((fails+1)); }
  chk=$(recrun --check 2>&1 || true)
  printf '%s' "$chk" | grep -q 'RECOVERABLE' || { printf 'SELF-TEST: FAIL — a committed deletion did not name its recovery path\n'; fails=$((fails+1)); }

  # an unstaged deletion over a legacy (pre-binding) row: the index still holds the bytes
  git -C "$tmp/rec" checkout HEAD^ -- proj/AGENTS.md >/dev/null 2>&1 || true
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: restore' >/dev/null 2>&1 || true
  recrun --record >/dev/null 2>&1 || true
  sha=$(awk -F'\t' '$1=="proj/AGENTS.md"{print $2; exit}' "$tmp/rec/digests.tsv")
  printf 'proj/AGENTS.md\t%s\t4\n' "$sha" > "$tmp/rec/digests.tsv"   # simulate a pre-binding recording
  rm "$tmp/rec/proj/AGENTS.md"
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·index" ] || { printf 'SELF-TEST: FAIL — an unstaged deletion did not name the index (got "%s", want "gone·index")\n' "$got"; fails=$((fails+1)); }

  # with the index emptied too, only HEAD's reflog history still holds the bytes
  git -C "$tmp/rec" rm -q --cached proj/AGENTS.md >/dev/null 2>&1 || true
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·reflog" ] || { printf 'SELF-TEST: FAIL — a deletion reachable only through the HEAD reflog did not name it (got "%s", want "gone·reflog")\n' "$got"; fails=$((fails+1)); }

  # a stashed deletion: the stash is parked while the ledger is clean, because `git stash`
  # resets tracked files to HEAD — a ledger hazard this tool itself warns about — and only then
  # is the row reduced to its legacy 3-column form
  rm -f "$tmp/rec/proj/AGENTS.md"
  git -C "$tmp/rec" stash -q >/dev/null 2>&1 || true            # park the deletion; the file comes back
  sha=$(awk -F'\t' '$1=="proj/AGENTS.md"{print $2; exit}' "$tmp/rec/digests.tsv")
  printf 'proj/AGENTS.md\t%s\t4\n' "$sha" > "$tmp/rec/digests.tsv"   # legacy row, again
  git -C "$tmp/rec" rm -q --cached proj/AGENTS.md >/dev/null 2>&1 || true
  git -C "$tmp/rec" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: deletion committed' >/dev/null 2>&1 || true
  rm -f "$tmp/rec/proj/AGENTS.md"   # the commit un-tracked the restored copy
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·stash" ] || { printf 'SELF-TEST: FAIL — a stashed deletion did not name the stash (got "%s", want "gone·stash")\n' "$got"; fails=$((fails+1)); }

  # with the stash cleared, the index empty and reflogs still intact, the HEAD reflog names them
  git -C "$tmp/rec" stash clear >/dev/null 2>&1 || true
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·reflog" ] || { printf 'SELF-TEST: FAIL — a deletion reachable only through the HEAD reflog did not name it (got "%s", want "gone·reflog")\n' "$got"; fails=$((fails+1)); }

  # reflogs expired, but the bytes sit in reachable history (an ancestor holds the path)
  git -C "$tmp/rec" reflog expire --expire=now --expire-unreachable=now --all >/dev/null 2>&1 || true
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·history" ] || { printf 'SELF-TEST: FAIL — bytes held by a reachable ancestor were not named history (got "%s", want "gone·history")\n' "$got"; fails=$((fails+1)); }

  # gc cannot fake a loss when reachable history holds the bytes
  git -C "$tmp/rec" gc --prune=now --quiet >/dev/null 2>&1 || true
  got=$(recrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·history" ] || { printf 'SELF-TEST: FAIL — gc changed a reachable-history verdict (got "%s")\n' "$got"; fails=$((fails+1)); }

  # a second fixture where the bytes are TRULY unreachable: the path was added, removed, and the
  # branch reset below both commits, so no reachable commit and no reflog holds the bytes — only
  # a dangling object does, until gc prunes it
  mkdir -p "$tmp/rec2/proj"
  printf 'proj/AGENTS.md\t1000\tedit\n' > "$tmp/rec2/ceilings.tsv"
  printf '# Unreachable fixture\n' > "$tmp/rec2/proj/README.md"
  printf 'digests.tsv\n' > "$tmp/rec2/.gitignore"   # the recording must survive resets in this fixture
  git init -q "$tmp/rec2" >/dev/null 2>&1 || true
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: base without the path' >/dev/null 2>&1 || true
  printf '# Recovery fixture\n\nOperations must never rename the archive directory in place.\n' > "$tmp/rec2/proj/AGENTS.md"
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: the path exists' >/dev/null 2>&1 || true
  rec2run(){ CEILINGS="$tmp/rec2/ceilings.tsv" DIGESTS="$tmp/rec2/digests.tsv" HOME_DIR="$tmp/rec2" \
             CONSTITUTION="$real_const" bash "$0" "$@" ; }
  rec2run --record >/dev/null 2>&1 || true
  sha=$(awk -F'\t' '$1=="proj/AGENTS.md"{print $2; exit}' "$tmp/rec2/digests.tsv")
  printf 'proj/AGENTS.md\t%s\t4\n' "$sha" > "$tmp/rec2/digests.tsv"   # legacy row; the file is untracked here, so resets leave it alone
  rm "$tmp/rec2/proj/AGENTS.md"
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/rec2" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: the path is removed' >/dev/null 2>&1 || true
  git -C "$tmp/rec2" reset -q --hard HEAD~2 >/dev/null 2>&1 || true   # below both commits that held the path
  git -C "$tmp/rec2" reflog expire --expire=now --expire-unreachable=now --all >/dev/null 2>&1 || true
  got=$(rec2run --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·unreachable" ] || { printf 'SELF-TEST: FAIL — a reset-away blob was not named unreachable (got "%s", want "gone·unreachable")\n' "$got"; fails=$((fails+1)); }

  # after gc pulls the last handle, the probe must say so plainly — GONE with no trace
  git -C "$tmp/rec2" gc --prune=now --quiet >/dev/null 2>&1 || true
  got=$(rec2run --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $6}' || true)
  [ "$got" = "gone·no-trace" ] || { printf 'SELF-TEST: FAIL — after gc pulled every handle the probe did not report no-trace (got "%s")\n' "$got"; fails=$((fails+1)); }

  # ── the ledger's own binding ──────────────────────────────────────────────────
  # A clean fixture, because the ledger check has to be shown to PASS as well as to fail, and this
  # is the only place in the suite where --check is expected to exit 0 at all.
  mkdir -p "$tmp/ledger/proj"
  printf 'proj/AGENTS.md\t1000\tedit\n' > "$tmp/ledger/ceilings.tsv"   # relative to HOME_DIR, not to $tmp
  printf '# Ledger fixture\n\nOperations must never rename the archive directory in place.\n' \
    > "$tmp/ledger/proj/AGENTS.md"
  git init -q "$tmp/ledger" >/dev/null 2>&1 || true
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: clean ledger' >/dev/null 2>&1 || true
  ledrun(){ CEILINGS="$tmp/ledger/ceilings.tsv" DIGESTS="$tmp/ledger/digests.tsv" HOME_DIR="$tmp/ledger" \
            CONSTITUTION="$real_const" bash "$0" "$@" ; }
  ledrun --record >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --record failed on the clean ledger fixture\n'; fails=$((fails+1)); }
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: record it' >/dev/null 2>&1 || true
  ledrun --check >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --check failed on a clean, fully committed fixture\n'; fails=$((fails+1)); }

  # a hand edit to the ledger: no finding and no exit code would mean the trace is gone
  printf '# a hand edit to the ledger\n' >> "$tmp/ledger/digests.tsv"
  ledrun --check >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — a hand edit to the ledger passed --check\n'; fails=$((fails+1)); }
  got=$(ledrun --check 2>&1 | grep -c 'FAIL  \[ledger\]' || true)
  [ "$got" -ge 1 ] || { printf 'SELF-TEST: FAIL — a hand edit to the ledger left no finding\n'; fails=$((fails+1)); }
  git -C "$tmp/ledger" checkout -- digests.tsv >/dev/null 2>&1 || true
  ledrun --check >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — committing the ledger back did not clear the finding\n'; fails=$((fails+1)); }

  # the enforcer is in the ledger set too: a copy living inside HOME_DIR must be committed, or the
  # logic that decides PASS can be rewritten without a trace (the regress has to stop somewhere,
  # and it stops at "the committed tool is the reference behaviour")
  cp "$(tool_abs)" "$tmp/ledger/tool.sh"
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid add -A >/dev/null 2>&1 || true
  git -C "$tmp/ledger" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: the tool' >/dev/null 2>&1 || true
  runled(){ CEILINGS="$tmp/ledger/ceilings.tsv" DIGESTS="$tmp/ledger/digests.tsv" HOME_DIR="$tmp/ledger" \
            CONSTITUTION="$real_const" bash "$tmp/ledger/tool.sh" "$@" ; }
  runled --check >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — a committed tool copy failed --check\n'; fails=$((fails+1)); }
  printf '\n# a hand edit to the tool\n' >> "$tmp/ledger/tool.sh"
  runled --check >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — an edited tool copy passed --check\n'; fails=$((fails+1)); }
  got=$(runled --check 2>&1 | grep -c 'FAIL  \[ledger\] .*tool\.sh' || true)
  [ "$got" -ge 1 ] || { printf 'SELF-TEST: FAIL — an edited tool copy was not named as an uncommitted ledger file\n'; fails=$((fails+1)); }

  rm -rf "$tmp"
  if [ "$fails" = 0 ]; then
    printf 'SELF-TEST: PASS — slop lies (history/wall/emphasis/duplicate-heading/duplicate-invariant) caught; over-ceiling file failed --check; a silent rewrite registered as DRIFT; a deletion survived re-recording as GONE; a change with no commit was REFUSED by --record and stayed DRIFT; a change outside version control was REFUSED too; the same change was bound after being committed; a forged binding was caught while the digest layer still said ok; an unchanged out-of-git document was named (WARN) not failed; a clean committed fixture passed --check outright; a hand edit to the ledger failed it and left a finding; an edited copy of the tool itself was named as an uncommitted ledger file; a committed deletion was probed and named RECOVERABLE; an unstaged deletion named the index; a stashed deletion named the stash; a reflog-only deletion named the reflog; bytes held by a reachable ancestor were named history and survived gc; a reset-away blob was named unreachable; after gc pulled every handle the probe said no-trace; counts intact.\n'
    exit 0
  fi
  printf 'SELF-TEST: FAIL — %s assertion(s) failed.\n' "$fails"
  exit 2
}

# ── main ───────────────────────────────────────────────────────────────────────

mode=report
strict=0
for a in "$@"; do
  case "$a" in
    --help|-h)   usage; exit 0 ;;
    --self-test) self_test ;;
    --list)      mode=list ;;
    --slop)      mode=slop ;;
    --write)     mode=write ;;
    --check)     mode=check ;;
    --strict)    strict=1 ;;
    --discover)  mode=discover ;;
    --density)   mode=density ;;
    --digests)   mode=digests ;;
    --record)    mode=record ;;   # exits non-zero when it refuses a document with no commit
    "")          ;;
    *)           die "unknown argument: $a (try --help)" ;;
  esac
done

[ -f "$CONSTITUTION" ] || die "source not found: $CONSTITUTION"
load_ceilings || die "declaration not found or empty: $CEILINGS"
load_protected

measure
load_digests || true
build_digest_findings
build_ledger_findings
collect_duplicates
dup_rows "$DUP_H" DUP-HEADING
dup_rows "$DUP_N" DUP-INVARIANT

# slop scanning, one pass per declared document
for f in ${SURF[@]+"${SURF[@]}"}; do
  abs=$(abs_of "$f")
  [ -f "$abs" ] || continue
  scan_slop_file "$f" "$abs"
done

case "$mode" in
  list)    list_view ;;
  slop)    slop_view ;;
  discover) discover ;;
  density)  density_view ;;
  digests)  digests_view ;;
  record)   record_digests || exit 1 ;;
  report)  report ;;
  write)
    mkdir -p "$OUT"
    report > "$OUT/REGISTRY.md"
    {
      printf 'path\tstatus\tlines\tbytes\twords\test_tokens\tceiling\tzone\n'
      printf '%s' "$ROWS"
    } > "$OUT/registry.tsv"
    {
      printf 'class\tpath\tline\tdetail\n'
      printf '%s' "$SLOP" | sed '/^$/d' | sort
    } > "$OUT/slop.tsv"
    printf 'wrote: %s/REGISTRY.md\nwrote: %s/registry.tsv\nwrote: %s/slop.tsv\n' \
      "${OUT#$HOME_DIR/}" "${OUT#$HOME_DIR/}" "${OUT#$HOME_DIR/}" ;;
  check)
    report
    hard=0
    if [ "$strict" = 1 ]; then
      hard=$(( $(slop_count WALL) + $(slop_count DUP-INVARIANT) ))
    fi
    over=$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^OVER$' || true)
    miss=$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^MISSING$' || true)
    conf=$(printf '%s' "$ROWS" | sed '/^$/d' | fld 2 | grep -c '^CONFLICT$' || true)
    printf '\ncheck: over_ceiling=%s missing=%s conflicts=%s digest_failures=%s unbound=%s ledger_failures=%s hard_slop=%s (strict=%s)\n' \
      "$over" "$miss" "$conf" "$DIG_FAILS" "$DIG_UNBOUND" "$LEDGER_FAILS" "$hard" "$strict"
    if [ "$over" = 0 ] && [ "$miss" = 0 ] && [ "$hard" = 0 ] && [ "$DIG_FAILS" = 0 ] && [ "$LEDGER_FAILS" = 0 ]; then
      printf 'check: PASS — every declared document exists, is within ceiling, matches its recording,\n'
      printf 'check: and every recording is bound to a commit that proves those bytes.\n'
      [ "$DIG_UNBOUND" = 0 ] || printf 'check: NOTE — %s recording(s) sit outside version control (unbound, listed as WARN above).\n' "$DIG_UNBOUND"
      printf 'check: the ledger itself is committed, so an edit to it would leave a trace.\n'
      exit 0
    fi
    printf 'check: FAIL — findings above are filed, not fixed (exit 1).\n'
    exit 1 ;;
esac
