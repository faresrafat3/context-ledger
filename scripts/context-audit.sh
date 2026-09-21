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
#                                    its ceiling, a digest failure (DRIFT / NEW / GONE), or a broken
#                                    commit binding (BIND-FAIL / NO-COMMIT)
#   context-audit.sh --strict        --check plus hard slop (walls, duplicate homes)
#   context-audit.sh --discover      context-looking docs on disk that no row declares
#   context-audit.sh --density       numbers / citations / falsifiers per 100 words, per doc
#                                    (the measurement behind an `evidence` vs `edit` zone)
#   context-audit.sh --record        pin every declared document into $DIGESTS — its sha256, its git
#                                    blob, and the commit that holds those bytes. REFUSES (exit 1) any
#                                    CHANGED document that no commit holds, whether the working tree is
#                                    uncommitted or the document sits outside version control: commit
#                                    the edit (or put it under version control) and then record it
#   context-audit.sh --digests       digest and binding per document (ok/DRIFT/NEW/GONE · ok/no-repo/NO-COMMIT/FAIL)
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
#   GONE   recorded but absent from disk — a deletion
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
repo_of(){
  local f="$1" d r
  d=$(dirname "$(abs_of "$f")")
  if [ -n "${REPO_OF[$d]+set}" ]; then printf '%s' "${REPO_OF[$d]}"; return 0; fi
  r=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)
  REPO_OF["$d"]="$r"
  printf '%s' "$r"
}

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
  local r f st bres fails=0 unbound=0
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
      GONE)  DIG_FINDINGS="${DIG_FINDINGS}FAIL  [digest] ${f}: recorded but absent from disk — a deletion is an Owner ruling, not a re-record"$'\n'; fails=$((fails+1)) ;;
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
  local r f abs st rs as bs cs w
  printf '%-42s %-7s %-9s %8s %10s %10s %6s %s\n' DOCUMENT DIGEST BIND COMMIT RECORDED ON-DISK WORDS ZONE
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    f=$(printf '%s' "$r" | fld 1)
    w=$(printf '%s' "$r" | fld 5)
    abs=$(abs_of "$f")
    st=$(digest_status "$f")
    if [ -f "$abs" ]; then as=$(sha_of "$abs"); else as='-'; fi
    rs="${REC[$f]:--}"; rs="${rs:0:8}"; as="${as:0:8}"
    cs="${RCOMMIT[$f]:--}"; [ "$cs" = '-' ] || cs="${cs:0:8}"
    bs=$(bind_label "$f" "$st")
    printf '%-42s %-7s %-9s %8s %10s %10s %6s %s\n' "$f" "$st" "$bs" "$cs" "$rs" "$as" "$w" \
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
  printf 'walls=%s  dup_headings=%s  dup_invariants=%s  history=%s  status=%s  preamble=%s  emphasis=%s  caps=%s\n' \
    "$(slop_count WALL)" "$(slop_count DUP-HEADING)" "$(slop_count DUP-INVARIANT)" \
    "$(slop_count HISTORY)" "$(slop_count STATUS)" "$(slop_count PREAMBLE)" \
    "$(slop_count EMPHASIS)" "$(slop_count CAPS)"
  printf '```\n'
  printf '\n## 3. Findings — filed, not fixed\n\n```\n'
  slop_view
  printf '%s' "$DIG_FINDINGS" | sed '/^$/d'
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

  # a CHANGED document outside version control is refused too: with no commit there is no way to
  # tell an intended edit from a silent rewrite, so the recording must not follow the bytes
  row_before=$(grep '^fixture/proj/AGENTS\.md' "$tmp/digests.tsv" || true)
  CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
    bash "$0" --record >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — --record blessed a change that no repository holds\n'; fails=$((fails+1)); }
  row_after=$(grep '^fixture/proj/AGENTS\.md' "$tmp/digests.tsv" || true)
  [ "$row_before" = "$row_after" ] || { printf 'SELF-TEST: FAIL — a refused out-of-git document had its recording rewritten\n'; fails=$((fails+1)); }
  got=$(CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" --digests 2>/dev/null | awk '$1=="fixture/proj/AGENTS.md"{print $2}' || true)
  [ "$got" = DRIFT ] || { printf 'SELF-TEST: FAIL — a refused out-of-git change is not still DRIFT (got %s)\n' "$got"; fails=$((fails+1)); }

  # a document outside version control is NAMED, not failed: it has no commit to bind to, so the
  # honest verdict is a warning, never a silent pass and never a false failure
  got=$(CEILINGS="$tmp/ceilings.tsv" DIGESTS="$tmp/digests.tsv" HOME_DIR="$tmp" CONSTITUTION="$real_const" \
        bash "$0" --check 2>&1 | grep -c '^FAIL  \[bind\]' || true)
  [ "$got" = 0 ] || { printf 'SELF-TEST: FAIL — a document outside version control was failed as a binding change\n'; fails=$((fails+1)); }

  # ── the commit binding: a change no commit holds cannot be blessed ────────────
  mkdir -p "$tmp/bind/proj"
  printf 'proj/AGENTS.md\t1000\tedit\n' > "$tmp/bind/ceilings.tsv"
  git init -q "$tmp/bind" >/dev/null 2>&1 || true
  printf '# Bound fixture\n\nOperations must never rename the archive directory in place.\n' \
    > "$tmp/bind/proj/AGENTS.md"
  git -C "$tmp/bind" -c user.name=fixture -c user.email=fixture@invalid add proj/AGENTS.md >/dev/null 2>&1 || true
  git -C "$tmp/bind" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: bind' >/dev/null 2>&1 || true
  bindrun(){ CEILINGS="$tmp/bind/ceilings.tsv" DIGESTS="$tmp/bind/digests.tsv" HOME_DIR="$tmp/bind" \
             CONSTITUTION="$real_const" bash "$0" "$@" ; }

  bindrun --record >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --record refused a committed document\n'; fails=$((fails+1)); }
  got=$(bindrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $2, $3}' || true)
  [ "$got" = "ok ok" ] || { printf 'SELF-TEST: FAIL — a committed document was not bound (got \"%s\", want \"ok ok\")\n' "$got"; fails=$((fails+1)); }

  # edit with no commit behind it: --record must refuse, keep the previous row, and stay red
  printf 'an edit with no commit behind it\n' >> "$tmp/bind/proj/AGENTS.md"
  row_before=$(grep '^proj/AGENTS\.md' "$tmp/bind/digests.tsv" || true)
  bindrun --record >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — --record blessed a change no commit holds\n'; fails=$((fails+1)); }
  row_after=$(grep '^proj/AGENTS\.md' "$tmp/bind/digests.tsv" || true)
  [ "$row_before" = "$row_after" ] || { printf 'SELF-TEST: FAIL — a refused document had its recording rewritten anyway\n'; fails=$((fails+1)); }
  got=$(bindrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $2}' || true)
  [ "$got" = DRIFT ] || { printf 'SELF-TEST: FAIL — the refused change is not still uncommitted at check time (got %s)\n' "$got"; fails=$((fails+1)); }

  # commit it, and the same recording is accepted
  git -C "$tmp/bind" -c user.name=fixture -c user.email=fixture@invalid add proj/AGENTS.md >/dev/null 2>&1 || true
  git -C "$tmp/bind" -c user.name=fixture -c user.email=fixture@invalid commit -q -m 'fixture: commit the edit' >/dev/null 2>&1 || true
  bindrun --record >/dev/null 2>&1 || { printf 'SELF-TEST: FAIL — --record refused a document that is now committed\n'; fails=$((fails+1)); }
  row_after2=$(grep '^proj/AGENTS\.md' "$tmp/bind/digests.tsv" || true)
  [ "$row_after2" != "$row_before" ] || { printf 'SELF-TEST: FAIL — the recording did not follow the commit\n'; fails=$((fails+1)); }
  got=$(bindrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $2, $3}' || true)
  [ "$got" = "ok ok" ] || { printf 'SELF-TEST: FAIL — a re-committed document is not bound (got \"%s\")\n' "$got"; fails=$((fails+1)); }

  # a forged binding: the row is pointed at a commit that does not exist. The digest layer still
  # says ok — only the binding layer can see this, which is the whole reason it exists.
  awk -F'\t' 'BEGIN{OFS="\t"} $1=="proj/AGENTS.md"{$5="0000000000000000000000000000000000000000"} {print}' \
    "$tmp/bind/digests.tsv" > "$tmp/bind/forged" && mv "$tmp/bind/forged" "$tmp/bind/digests.tsv"
  got=$(bindrun --digests 2>/dev/null | awk '$1=="proj/AGENTS.md"{print $2, $3}' || true)
  [ "$got" = "ok FAIL" ] || { printf 'SELF-TEST: FAIL — a forged binding was not caught (got \"%s\", want \"ok FAIL\")\n' "$got"; fails=$((fails+1)); }
  bindrun --check >/dev/null 2>&1 && { printf 'SELF-TEST: FAIL — a forged binding passed --check\n'; fails=$((fails+1)); }

  rm -rf "$tmp"
  if [ "$fails" = 0 ]; then
    printf 'SELF-TEST: PASS — slop lies (history/wall/emphasis/duplicate-heading/duplicate-invariant) caught; over-ceiling file failed --check; a silent rewrite registered as DRIFT; a deletion survived re-recording as GONE; a change with no commit was REFUSED by --record and stayed DRIFT; a change outside version control was REFUSED too; the same change was bound after being committed; a forged binding was caught while the digest layer still said ok; an unchanged out-of-git document was named (WARN) not failed; counts intact.\n'
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
    printf '\ncheck: over_ceiling=%s missing=%s conflicts=%s digest_failures=%s unbound=%s hard_slop=%s (strict=%s)\n' \
      "$over" "$miss" "$conf" "$DIG_FAILS" "$DIG_UNBOUND" "$hard" "$strict"
    if [ "$over" = 0 ] && [ "$miss" = 0 ] && [ "$hard" = 0 ] && [ "$DIG_FAILS" = 0 ]; then
      printf 'check: PASS — every declared document exists, is within ceiling, matches its recording,\n'
      printf 'check: and every recording is bound to a commit that proves those bytes.\n'
      [ "$DIG_UNBOUND" = 0 ] || printf 'check: NOTE — %s recording(s) sit outside version control (unbound, listed as WARN above).\n' "$DIG_UNBOUND"
      exit 0
    fi
    printf 'check: FAIL — findings above are filed, not fixed (exit 1).\n'
    exit 1 ;;
esac
