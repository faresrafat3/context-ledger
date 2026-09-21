#!/usr/bin/env bash
#
# constitution-sweep.sh — make CONSTITUTION.md §2 executable.
#
# WHY THIS EXISTS
#   CONSTITUTION.md §2 (the protected-zone registry) is a hand-written table, and the
#   constitution's own standing consequence says: "a project that does not declare its
#   gate command and its protected zones is incomplete." Nothing measured that claim.
#   This sweep reads the table from disk, probes every row against the live tree, and
#   prints counts computed at read time (R14: generated counts, never hand counts).
#
# HOW IT WORKS
#   §2's table rows are read from CONSTITUTION.md (scoped to the "## 2." section; a bare fixture
#   file is accepted so --self-test exercises the same code path). Each row yields its path cell,
#   its protected-referent tokens and its gate cell. Gates are classified (COMMAND / EXTERNAL /
#   PROSE / NONE) and tiered; the "One home per fact" paragraph (CONSTITUTION.md:41-47) is read
#   too, so a missing local declaration and a "two homes" project are both filed as failures.
#
# WHAT IT DOES NOT DO
#   It never edits a project, never edits CONSTITUTION.md, never repairs a finding.
#   A failure is filed (printed; exit 1 under --check), not fixed silently.
#   It does not call a gate green unless --run-gates actually ran it on this tree.
#   Globs/ranges in the protected column are reduced to their parent directory; the
#   reduction is printed per referent so nothing is resolved silently.
#
# USAGE
#   constitution-sweep.sh                 report to stdout
#   constitution-sweep.sh --write         write REGISTRY.md + registry.tsv to $OUT
#   constitution-sweep.sh --check         exit 1 if any row fails (missing path /
#                                         no runnable gate / missing protected referent)
#   constitution-sweep.sh --run-gates     also execute tier-1 whitelisted gates
#   constitution-sweep.sh --heavy         with --run-gates: also run pnpm-tier gates
#   constitution-sweep.sh --self-test     plant known lies in a fixture and prove this
#                                         tool catches them (the known-positive rule)
#   constitution-sweep.sh --help
#
# EXIT CODES
#   0  report emitted / --check found no failure / self-test passed
#   1  --check found failures
#   2  bad usage / missing source / self-test failed
#
set -euo pipefail

HOME_DIR="${HOME}"
CONSTITUTION="${CONSTITUTION:-$HOME_DIR/CONSTITUTION.md}"
OUT="${OUT:-$HOME_DIR/local/compliance}"
GATE_TIMEOUT="${GATE_TIMEOUT:-300}"

mode=report
run_gates=0
heavy=0

# ── helpers ────────────────────────────────────────────────────────────────────

usage(){ sed -n '/^# USAGE/,/^set -euo pipefail/p' "$0" | sed '$d; s/^# \{0,1\}//' ; }

die(){ printf 'constitution-sweep: %s\n' "$1" >&2; exit 2; }

# expand a leading ~ and return an absolute path
abs_path(){ case "$1" in "~"*) printf '%s\n' "$HOME_DIR${1#\~}" ;; *) printf '%s\n' "$1" ;; esac; }

# every backticked token in a string, one per line
bt_tokens(){ printf '%s\n' "$1" | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' || true; }

# a leading command word of a backticked token (used for whitelist classification)
gate_first_word(){ printf '%s\n' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]].*$//'; }

# resolve a §2 path cell (may be ~-rooted, absolute, or a home-level dot-dir)
row_path_abs(){
  case "$1" in
    '~'*) abs_path "$1" ;;
    /*)   printf '%s\n' "$1" ;;
    .*)   printf '%s\n' "$HOME_DIR/${1%/}" ;;
    *)    printf '%s\n' "$1" ;;
  esac
}

# reduce a protected-referent token to something checkable, and say how it was
# reduced: exact | parent-dir(glob) | parent-dir(range)
normalize_ref(){
  local tok="$1" base="$2" p rest
  p="$tok"
  case "$p" in
    *..*) rest=$(printf '%s' "$p" | sed 's/\.\..*$//'); [ -n "$rest" ] || rest="$p"
          p="$rest"; printf 'parent-dir(range)\t%s\n' "$p"; return 0 ;;
  esac
  case "$p" in
    *'*'*) rest=$(printf '%s' "$p" | sed 's/\*.*$//'); [ -n "$rest" ] || rest="."
           p="$rest"; printf 'parent-dir(glob)\t%s\n' "$p"; return 0 ;;
  esac
  printf 'exact\t%s\n' "$p"
}

# resolve a referent (relative to a project dir, or absolute/~-rooted) to a path
ref_exists(){
  local ref="$1" base="$2" abs
  case "$ref" in
    /*)   abs="$ref" ;;
    '~'*) abs="$(abs_path "$ref")" ;;
    *)    abs="$base/$ref" ;;
  esac
  [ -e "$abs" ] && printf '%s\n' "$abs"
  return 0
}

# tier classification for --run-gates. Tier 1 = cheap, read-only-ish, whitelisted.
# Tier 2 = pnpm-tier monorepo gates (opt-in via --heavy). Anything else: not-run.
gate_tier(){
  local cmd="$1" w
  w="$(gate_first_word "$cmd")"
  case "$cmd" in
    *'pnpm run'*) printf '2\n'; return 0 ;;
  esac
  case "$w" in
    sha256sum|node|npm|bash|tools/audit.sh|tools/citecheck.sh) printf '1\n'; return 0 ;;
  esac
  printf '0\n'
}

# ── TSV field helpers (sed only — no awk/cut, per the coreutils allowlist) ─────
f1(){ sed 's/\t.*$//' ; }
f2(){ sed 's/^[^\t]*\t//; s/\t.*$//' ; }
f3(){ sed 's/^[^\t]*\t[^\t]*\t//; s/\t.*$//' ; }
f4(){ sed 's/^[^\t]*\t[^\t]*\t[^\t]*\t//; s/\t.*$//' ; }

# ── reference classification ───────────────────────────────────────────────────
# A referent is a backticked token in the protected column. Classification:
#   LOCAL-PATH     exists under the project (after glob/range reduction)
#   NOT-A-LOCAL-PATH  neither the token nor its first segment exists there
#                     (e.g. an upstream repo name) — printed, never counted missing
#   MISSING        looks local, does not resolve — a failure
ref_classify(){
  local tok="$1" base="$2" kind red full first found
  # a token that carries arguments (e.g. `scripts/collect.sh --apply`) is checked by its
  # first word when the whole token does not resolve — arguments are not paths
  case "$tok" in
    *' '*) if [ -z "$(ref_exists "$tok" "$base")" ]; then tok="${tok%% *}"; fi ;;
  esac
  if ! printf '%s' "$tok" | grep -qE '\.md$|\.json$|\.txt$|\.ya?ml$|\.js$|\.ts$|\.sh$|\.py$|/$|\*|\.\.|/'; then
    printf 'NONPATH\n'; return 0
  fi
  kind=$(normalize_ref "$tok" "$base" | f1)
  red=$(normalize_ref "$tok" "$base" | f2)
  full=$(ref_exists "$red" "$base")
  if [ -n "$full" ]; then
    printf 'LOCAL-PATH\t%s\t%s\t%s\n' "$tok" "$kind" "$red"; return 0
  fi
  first=$(printf '%s' "$red" | sed 's#/.*$##')
  if [ "$kind" != exact ] && [ "$first" = "$red" ]; then
    # a glob/range reduced to a bare prefix: its parent is the project root itself
    if [ -d "$base" ]; then
      printf 'LOCAL-PATH\t%s\t%s\t%s\n' "$tok" "root-of:$kind" "."; return 0
    fi
  fi
  if [ "$kind" != exact ] && [ -n "$first" ] && [ -e "$base/$first" ]; then
    printf 'LOCAL-PATH\t%s\t%s\t%s\n' "$tok" "parent-of:$kind" "$first"; return 0
  fi
  # a bare basename that resolves deeper in the project is shorthand, not a loss
  if [ "$kind" = exact ] && [ "$first" = "$red" ]; then
    found=$(find "$base" -maxdepth 3 -name "$red" -not -path '*/.git/*' 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then
      printf 'SHORTHAND\t%s\t%s\t%s\n' "$tok" "$kind" "${found#$base/}"; return 0
    fi
    printf 'MISSING\t%s\t%s\t%s\n' "$tok" "$kind" "$red"; return 0
  fi
  if [ -n "$first" ] && [ -e "$base/$first" ]; then
    printf 'MISSING\t%s\t%s\t%s\n' "$tok" "$kind" "$red"; return 0
  fi
  printf 'NOT-A-LOCAL-PATH\t%s\t%s\t%s\n' "$tok" "$kind" "$red"
  return 0
}

# ── the probe: read §2 rows, emit one TSV record per (row, path) ───────────────
# fields: line  name  path  exists  gate_kind  gate_cmd  tier  refs_ok  refs_missing
#         missing_list  nonlocal_list
probe_rows(){
  local cfile="$1" content no name projcell protcell gatecell safecell
  local paths p abs exists gate_kind gate_cmd tier refs_ok refs_missing rows
  local missing_list nonlocal_list shorthand_list tok cls kind red
  if grep -q '^## 2\.' "$cfile"; then
    rows=$(sed -n '/^## 2\./,/^---/{/^| \*\*/{=;p;}}' "$cfile")
  else
    rows=$(sed -n '/^| \*\*/{=;p;}' "$cfile")   # fixture mode: whole file
  fi
  while IFS= read -r no; do
    IFS= read -r content || break
    name=$(printf '%s' "$content" | sed -n 's/^| \*\*\([^*]*\)\*\*.*/\1/p')
    IFS='|' read -r _ projcell protcell gatecell safecell _ <<EOF
$content
EOF
    paths=$(printf '%s' "$projcell" | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' | grep -E '^~|^/|^\.' || true)
    [ -n "$paths" ] || paths='-'
    if printf '%s' "$gatecell" | grep -qi 'upstream'; then
      gate_kind=EXTERNAL
    elif printf '%s' "$gatecell" | grep -q '`'; then
      gate_kind=COMMAND
    elif printf '%s' "$gatecell" | grep -q '—' \
      || [ -z "$(printf '%s' "$gatecell" | sed 's/[[:space:]]//g')" ]; then
      gate_kind=NONE
    else
      gate_kind=PROSE
    fi
    gate_cmd=$(bt_tokens "$gatecell" | head -1 || true)
    case "$gate_kind" in
      COMMAND) tier=$(gate_tier "$gate_cmd") ;;
      *)       tier='-' ;;
    esac
    printf '%s\n' "$paths" | while IFS= read -r p; do
      abs="$(row_path_abs "$p")"
      if [ -e "$abs" ]; then exists=yes; else exists=NO; fi
      refs_ok=0; refs_missing=0; missing_list=''; nonlocal_list=''; shorthand_list=''
      while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        cls=$(ref_classify "$tok" "$abs")
        case "$cls" in
          NONPATH) continue ;;
        esac
        kind=$(printf '%s' "$cls" | f1)
        case "$kind" in
          LOCAL-PATH)     refs_ok=$((refs_ok+1)) ;;
          MISSING)        refs_missing=$((refs_missing+1))
                          red=$(printf '%s' "$cls" | f4)
                          missing_list="$missing_list${missing_list:+,}$tok[->$red]" ;;
          NOT-A-LOCAL-PATH) nonlocal_list="$nonlocal_list${nonlocal_list:+,}$tok" ;;
          SHORTHAND)      red=$(printf '%s' "$cls" | f4)
                          shorthand_list="$shorthand_list${shorthand_list:+,}$tok[->$red]" ;;
        esac
      done <<EOF
$(bt_tokens "$protcell")
EOF
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$no" "$name" "$p" "$exists" "$gate_kind" "${gate_cmd:--}" "$tier" \
        "$refs_ok" "$refs_missing" "${missing_list:--}" "${nonlocal_list:--}" "${shorthand_list:--}"
    done
  done <<EOF
$rows
EOF
}

# ── generic TSV field accessor + integer sum (sed/bash only) ───────────────────
fld(){ sed "s/^\([^\t]*\t\)\{$(($1-1))\}//; s/\t.*$//" ; }

sum_field(){   # N < tsv — integer sum of field N
  local n="$1" total=0 line v
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    v=$(printf '%s' "$line" | fld "$n")
    case "$v" in ''|*[!0-9]*) continue ;; esac
    total=$((total+v))
  done
  printf '%s\n' "$total"
}

count_rows(){   # unique source lines (a row may own several path lines)
  local tsv="$1" n=0 no
  local -A seen=()
  while IFS= read -r no; do
    [ -n "$no" ] || continue
    [ -n "${seen[$no]:-}" ] && continue
    seen[$no]=1; n=$((n+1))
  done <<EOF
$(printf '%s\n' "$tsv" | fld 1)
EOF
  printf '%s\n' "$n"
}

count_row_kind(){   # <tsv> <field> <value> — rows (deduped by source line) with that value
  local tsv="$1" f="$2" want="$3" n=0 r no v
  local -A seen=()
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    no=$(printf '%s' "$r" | fld 1); v=$(printf '%s' "$r" | fld "$f")
    [ "$v" = "$want" ] || continue
    [ -n "${seen[$no]:-}" ] && continue
    seen[$no]=1; n=$((n+1))
  done <<EOF
$tsv
EOF
  printf '%s\n' "$n"
}

count_list(){   # <tsv> <field> — rows whose field is not "-"
  printf '%s\n' "$1" | fld "$2" | grep -vc '^-$' || true
}

# ── coverage: every depth-1 tree on disk vs the §2 paths ───────────────────────
covered(){   # covered <candidate-abs> <tsv> — 0 if equal to / under a §2 path
  local c="$1" tsv="$2" p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    p="$(abs_path "$p" | sed 's#/$##')"
    case "$c" in "$p"|"$p"/*) return 0 ;; esac
  done <<EOF
$(printf '%s\n' "$tsv" | fld 3)
EOF
  return 1
}

looks_like_project(){   # declared heuristic: git repo or doc/config file at depth<=2
  local d="$1"
  [ -d "$d/.git" ] && return 0
  [ -n "$(find "$d" -maxdepth 2 -type f \( -name '*.md' -o -name '*.txt' -o -name '*.json' \
      -o -name '*.yaml' -o -name '*.yml' -o -name '*.sh' \) 2>/dev/null | head -1 || true)" ] && return 0
  return 1
}

coverage_report(){
  local tsv="$1" d base cand=0 cov=0 unc=0 cov_cont=0 unc_list='' cont_list='' flag b c child_covered
  for d in "$HOME_DIR"/*/ "$HOME_DIR"/Projects/*/ ; do
    [ -d "$d" ] || continue
    cand=$((cand+1))
    base="${d%/}"
    if covered "$base" "$tsv"; then cov=$((cov+1)); continue; fi
    child_covered=0
    for c in "$base"/*/; do
      [ -d "$c" ] || continue
      if covered "${c%/}" "$tsv"; then child_covered=1; break; fi
    done
    if [ "$child_covered" = 1 ]; then
      cov_cont=$((cov_cont+1))
      cont_list="$cont_list${cont_list:+,}${base#$HOME_DIR/}"
      continue
    fi
    unc=$((unc+1))
    flag='-'
    looks_like_project "$base" && flag='looks-like-a-project'
    b=$(basename "$base")
    case "$b" in .*) flag="runtime-ish,${flag}" ;; esac
    unc_list="$unc_list${unc_list:+,}${base#$HOME_DIR/}[$flag]"
  done
  printf 'candidates=%s covered=%s containers=%s uncovered=%s\n' "$cand" "$cov" "$cov_cont" "$unc"
  [ -n "$cont_list" ] && printf 'containers (children already covered): %s\n' "$cont_list"
  [ -n "$unc_list" ] && printf 'uncovered: %s\n' "$unc_list"
  printf 'note: the "looks-like-a-project" flag is a declared heuristic (git repo or doc/config file at depth<=2), not a verdict.\n'
}

runtime_doctrine_scan(){
  local tsv="$1" p abs md hits files
  printf '%s\n' "$tsv" | while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$(printf '%s' "$r" | fld 2)" in *runtime*) ;; *) continue ;; esac
    p=$(printf '%s' "$r" | fld 3); abs="$(row_path_abs "$p")"
    if [ ! -d "$abs" ]; then printf '%s\t(absent)\t-\t-\n' "$p"; continue; fi
    md=$(find "$abs" -maxdepth 3 -type f -name '*.md' 2>/dev/null | wc -l || true)
    files=$(grep -rIlE '\b(RULES?|GOVERNANCE|CONSTITUTION|INVARIANT|PROTOCOL)\b' "$abs" \
              --include='*.md' 2>/dev/null | head -5 | sed "s#^$HOME_DIR/##" || true)
    hits=$(printf '%s\n' "$files" | grep -c . || true)
    printf '%s\t%s\t%s\t%s\n' "$p" "$md" "$hits" "$(printf '%s\n' "$files" | paste -sd, -)"
  done
}

# ── local declarations — CONSTITUTION.md §2 "One home per fact" paragraph ──────
# The law names, in prose, the projects that carry their own PROTECTED.md (authoritative)
# and the projects whose protection stays in their own doctrine (a second declaration
# would create two homes). Both lists are read from disk here, never hardcoded.
law_local_decl_dirs(){   # existing directories named in the "One home per fact" paragraph
  sed -n '/^\*\*One home per fact:\*\*/,/^$/p' "$CONSTITUTION" \
    | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' | while IFS= read -r tok; do
        case "$tok" in 'PROTECTED.md') continue ;; esac
        abs="$HOME_DIR/$tok"
        [ -d "$abs" ] && printf '%s\n' "$abs"
      done | sort -u
}

is_local_decl_dir(){ printf '%s\n' "$(law_local_decl_dirs)" | grep -qx "$1" ; }

declare_scan(){   # <tsv> — PROTECTED.md presence + its own referents
  local tsv="$1" d f ok miss tok cls kind
  printf '%s\n' "$(law_local_decl_dirs)" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    f="$d/PROTECTED.md"
    if [ ! -f "$f" ]; then printf '%s\tMISSING\t-\t-\n' "${d#$HOME_DIR/}"; continue; fi
    ok=0; miss=0; miss_list=''
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      cls=$(ref_classify "$tok" "$d")
      case "$cls" in NONPATH|NOT-A-LOCAL-PATH|SHORTHAND) continue ;; esac
      kind=$(printf '%s' "$cls" | f1)
      case "$kind" in
        LOCAL-PATH) ok=$((ok+1)) ;;
        MISSING)    miss=$((miss+1)); miss_list="$miss_list${miss_list:+,}$tok" ;;
      esac
    done <<EOF
$(grep -E '^\|' "$f" | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//')
EOF
    printf '%s\tpresent\t%s\t%s%s\n' "${d#$HOME_DIR/}" "$ok" "$miss" "${miss_list:+ ($miss_list)}"
  done
}

run_one_gate(){   # <project-abs> <cmd> → rc / last non-empty output line
  local dir="$1" cmd="$2" log rc=0 last
  log=$(mktemp)
  ( cd "$dir" && timeout "$GATE_TIMEOUT" bash -c "$cmd" ) >"$log" 2>&1 || rc=$?
  last=$(grep -v '^[[:space:]]*$' "$log" | tail -1 || true)
  last=$(printf '%s' "$last" | sed 's/^\(.\{0,100\}\).*$/\1/')
  printf '%s\t%s\n' "$rc" "${last:-(no output)}"
  rm -f "$log"
}

# ── findings — filed, never fixed ──────────────────────────────────────────────
findings(){   # <tsv>
  local tsv="$1" fails=0
  local -A seen_gate=() seen_path=()
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    local no name path exists gk miss nl
    no=$(printf '%s' "$r" | fld 1);     name=$(printf '%s' "$r" | fld 2)
    path=$(printf '%s' "$r" | fld 3);   exists=$(printf '%s' "$r" | fld 4)
    gk=$(printf '%s' "$r" | fld 5);     miss=$(printf '%s' "$r" | fld 9)
    nl=$(printf '%s' "$r" | fld 11)
    if [ "$exists" = NO ] && [ -z "${seen_path[$no]:-}" ]; then
      printf 'FAIL  [L%s %s] path does not exist: %s\n' "$no" "$name" "$path"; fails=$((fails+1))
      seen_path[$no]=1
    fi
    if [ "$miss" != 0 ] && [ "$miss" != '-' ]; then
      printf 'FAIL  [L%s %s] %s protected referent(s) unresolved: %s\n' \
        "$no" "$name" "$miss" "$(printf '%s' "$r" | fld 10)"; fails=$((fails+1))
    fi
    if [ -z "${seen_gate[$no]:-}" ]; then
      case "$gk" in
        NONE)  printf 'GAP   [L%s %s] no gate declared in §2 (gate column: em dash)\n' "$no" "$name"; fails=$((fails+1)); seen_gate[$no]=1 ;;
        PROSE) printf 'GAP   [L%s %s] gate is prose, no executable command in §2\n' "$no" "$name"; fails=$((fails+1)); seen_gate[$no]=1 ;;
      esac
    fi
    if [ "$nl" != '-' ]; then
      printf 'NOTE  [L%s %s] tokens not resolvable locally (not counted missing): %s\n' "$no" "$name" "$nl"
    fi
    if [ "$(printf '%s' "$r" | fld 12)" != '-' ]; then
      printf 'NOTE  [L%s %s] shorthand referent(s) resolved deeper in the tree: %s\n' \
        "$no" "$name" "$(printf '%s' "$r" | fld 12)"
    fi
  done <<EOF
$tsv
EOF
  # ── the "One home per fact" rules, read from the law's own prose ──────────────
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ ! -f "$d/PROTECTED.md" ]; then
      printf 'FAIL  [CONSTITUTION.md:41-47] local declaration named by the law is missing: %s/PROTECTED.md\n' \
        "${d#$HOME_DIR/}"; fails=$((fails+1))
    fi
  done <<EOF
$(law_local_decl_dirs)
EOF
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$(printf '%s' "$r" | fld 2)" in *runtime*) continue ;; esac
    d="$(row_path_abs "$(printf '%s' "$r" | fld 3)")"
    [ -d "$d" ] || continue
    is_local_decl_dir "$d" && continue
    if [ -f "$d/PROTECTED.md" ]; then
      printf 'FAIL  [CONSTITUTION.md:41-47] two homes: %s carries PROTECTED.md while the law keeps its protection in its own doctrine\n' \
        "${d#$HOME_DIR/}"; fails=$((fails+1))
    fi
  done <<EOF
$tsv
EOF
  printf 'failures=%s\n' "$fails"
}

# ── report ─────────────────────────────────────────────────────────────────────
report(){
  local tsv="$1" today
  today=$(date '+%Y-%m-%d %H:%M')
  printf '# COMPLIANCE REGISTRY — generated, not law\n\n'
  printf '> generated: %s · source: `%s` · tool: `local/scripts/constitution-sweep.sh`\n' \
    "$today" "${CONSTITUTION#$HOME_DIR/}"
  printf '> source digest: sha256=%s · bytes=%s · mtime=%s\n' \
    "$(sha256sum "$CONSTITUTION" | sed 's/[[:space:]].*$//')" \
    "$(wc -c < "$CONSTITUTION" | sed 's/[[:space:]]//g')" \
    "$(date -r "$CONSTITUTION" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf 'unknown')"
  printf '> A registry whose digest differs from the file on disk was graded against a different revision. Re-run before quoting.\n'
  printf '> Counts are computed at emit time (R14). Re-run it; never edit it.\n'
  printf '> A gate is GREEN only if `--run-gates` executed it in this run; otherwise it is UNRUN, not passed.\n'
  printf '> Referent classes: LOCAL-PATH (exists) · MISSING (local-looking, unresolved = failure) · NOT-A-LOCAL-PATH (printed, not counted as missing).\n\n'
  printf '## 1. Rows — CONSTITUTION.md §2 read from disk\n\n'
  printf '| line | project | path | exists | gate kind | gate command | tier | refs ok | refs missing | non-local | shorthand |\n'
  printf '|---|---|---|---|---|---|---|---|---|---|---|\n'
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    printf '| %s | %s | `%s` | %s | %s | `%s` | %s | %s | %s | %s | %s |\n' \
      "$(printf '%s' "$r" | fld 1)"  "$(printf '%s' "$r" | fld 2)"  "$(printf '%s' "$r" | fld 3)" \
      "$(printf '%s' "$r" | fld 4)"  "$(printf '%s' "$r" | fld 5)"  "$(printf '%s' "$r" | fld 6)" \
      "$(printf '%s' "$r" | fld 7)"  "$(printf '%s' "$r" | fld 8)"  "$(printf '%s' "$r" | fld 9)" \
      "$(printf '%s' "$r" | fld 11)" "$(printf '%s' "$r" | fld 12)"
  done <<EOF
$tsv
EOF
  printf '\n## 2. Counts (generated at emit time)\n\n```\n'
  printf 'rows_total=%s  paths_total=%s\n' "$(count_rows "$tsv")" "$(printf '%s\n' "$tsv" | grep -c . || true)"
  printf 'gate_command=%s (tier1=%s tier2=%s not-runnable=%s)\n' \
    "$(count_row_kind "$tsv" 5 COMMAND)" "$(count_row_kind "$tsv" 7 1)" \
    "$(count_row_kind "$tsv" 7 2)" "$(count_row_kind "$tsv" 7 0)"
  printf 'gate_none=%s  gate_prose=%s  gate_external=%s  paths_missing=%s\n' \
    "$(count_row_kind "$tsv" 5 NONE)" "$(count_row_kind "$tsv" 5 PROSE)" \
    "$(count_row_kind "$tsv" 5 EXTERNAL)" "$(count_row_kind "$tsv" 4 NO)"
  printf 'referents_ok=%s  referents_missing=%s  shorthand=%s  non_local_tokens=%s\n' \
    "$(sum_field 8 <<EOF
$tsv
EOF
)" \
    "$(sum_field 9 <<EOF
$tsv
EOF
)" \
    "$(count_list "$tsv" 12)" \
    "$(count_list "$tsv" 11)"
  printf '```\n'
  printf '\n## 3. Gate observations\n\n'
  if [ "$run_gates" = 1 ]; then
    printf 'run_gates=ON (heavy=%s, timeout=%ss). Format: tier | rc | command | last output line\n\n```\n' "$heavy" "$GATE_TIMEOUT"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      gk=$(printf '%s' "$r" | fld 5); [ "$gk" = COMMAND ] || continue
      tier=$(printf '%s' "$r" | fld 7)
      if [ "$tier" = 2 ] && [ "$heavy" != 1 ]; then continue; fi
      cmd=$(printf '%s' "$r" | fld 6); path=$(printf '%s' "$r" | fld 3)
      out=$(run_one_gate "$(abs_path "$path")" "$cmd")
      rc=$(printf '%s' "$out" | sed 's/\t.*$//'); last=$(printf '%s' "$out" | sed 's/^[^\t]*\t//')
      printf 'tier%s | rc=%s | %s | %s\n' "$tier" "$rc" "$cmd" "$last"
    done <<EOF
$tsv
EOF
    printf '```\n'
  else
    printf 'run_gates=OFF — no gate was executed in this run. Every COMMAND row is UNRUN.\n'
    printf 'Quote a receipt on disk, or re-run with `--run-gates`, before calling any gate green.\n'
  fi
  printf '\n## 4. Coverage — depth-1 trees on disk vs §2\n\n```\n'
  coverage_report "$tsv"
  printf '```\n'
  printf '\n## 5. Runtime-tree doctrine scan (§2 last row claims "executable state only")\n\n'
  printf '| path | *.md files (depth<=3) | doctrine-keyword files (first 5) |\n|---|---|---|\n'
  runtime_doctrine_scan "$tsv" | while IFS= read -r l; do
    printf '| `%s` | %s | %s |\n' \
      "$(printf '%s' "$l" | f1)" \
      "$(printf '%s' "$l" | f2)" \
      "$(printf '%s' "$l" | f3)"
  done
  printf '\n```\n'
  runtime_doctrine_scan "$tsv" | while IFS= read -r l; do
    case "$(printf '%s' "$l" | f3)" in ''|0|'-'|*[!0-9]*) continue ;; esac
    printf 'doctrine-keyword files under %s: %s\n' "$(printf '%s' "$l" | f1)" "$(printf '%s' "$l" | f4)"
  done
  printf '```\n'
  printf '\n## 6. Local declarations — §2 "One home per fact" (CONSTITUTION.md:41-47)\n\n'
  printf 'PROTECTED.md present at every directory the law names, with that file'"'"'s own referents resolved:\n\n'
  printf '| project | PROTECTED.md | referents ok | referents missing |\n|---|---|---|---|\n'
  declare_scan "$tsv" | while IFS= read -r l; do
    printf '| `%s` | %s | %s | %s |\n' \
      "$(printf '%s' "$l" | f1)" "$(printf '%s' "$l" | f2)" \
      "$(printf '%s' "$l" | f3)" "$(printf '%s' "$l" | f4)"
  done
  printf '\n'
  printf 'Projects the law keeps in their own doctrine (a PROTECTED.md here would be two homes): '
  printf 'NOTRICK, Colony Kernel, DSH, upstream Hermes — checked under §7.\n'
  printf '\n## 7. Findings — filed, not fixed\n\n```\n'
  findings "$tsv"
  printf '```\n'
}

# ── self-test — the known-positive rule (a checker is believed only after it has
#    caught a planted lie; same rule as Projects/notrick/tools/citecheck.sh) ────
self_test(){
  local ghost="$HOME_DIR/__constitution_sweep_selftest_no_such_project__"
  local fixture tsv fails=0 got
  if [ -e "$ghost" ]; then
    printf 'SELF-TEST: FAIL — fixture path exists (%s); the test cannot prove anything.\n' "$ghost"
    exit 2
  fi
  fixture=$(mktemp)
  cat > "$fixture" <<'FIXTURE'
| Project | Protected (do not edit in place) | Gate / verifier | Safe write-path |
|---|---|---|---|
| **GHOST** `~/__constitution_sweep_selftest_no_such_project__` | `souls/**`, `gone-file.md` | — | none |
| **LOCAL** `~/local` | `scripts/sync-hermes-mirror.sh` | `sha256sum -c scripts/NOPE` | yes |
FIXTURE
  tsv=$(probe_rows "$fixture")
  rm -f "$fixture"

  got=$(printf '%s\n' "$tsv" | grep 'GHOST' | fld 4 || true)
  [ "$got" = NO ] || { printf 'SELF-TEST: FAIL — planted missing path not flagged (exists=%s)\n' "$got"; fails=$((fails+1)); }
  got=$(printf '%s\n' "$tsv" | grep 'GHOST' | fld 5 || true)
  [ "$got" = NONE ] || { printf 'SELF-TEST: FAIL — planted no-gate row classified %s\n' "$got"; fails=$((fails+1)); }
  got=$(printf '%s\n' "$tsv" | grep 'GHOST' | fld 9 || true)
  case "$got" in ''|*[!0-9]*) got=0 ;; esac
  [ "$got" -ge 1 ] || { printf 'SELF-TEST: FAIL — planted unresolved referents not counted (got %s)\n' "$got"; fails=$((fails+1)); }

  got=$(printf '%s\n' "$tsv" | grep 'LOCAL' | fld 4 || true)
  [ "$got" = yes ] || { printf 'SELF-TEST: FAIL — control row path misclassified (got %s)\n' "$got"; fails=$((fails+1)); }
  got=$(printf '%s\n' "$tsv" | grep 'LOCAL' | fld 5 || true)
  [ "$got" = COMMAND ] || { printf 'SELF-TEST: FAIL — control row gate misclassified (got %s)\n' "$got"; fails=$((fails+1)); }
  got=$(printf '%s\n' "$tsv" | grep 'LOCAL' | fld 7 || true)
  [ "$got" = 1 ] || { printf 'SELF-TEST: FAIL — control row tier misclassified (got %s)\n' "$got"; fails=$((fails+1)); }
  got=$(printf '%s\n' "$tsv" | grep 'LOCAL' | fld 9 || true)
  [ "$got" = 0 ] || { printf 'SELF-TEST: FAIL — control row referents flagged missing (got %s)\n' "$got"; fails=$((fails+1)); }

  if [ "$fails" = 0 ]; then
    printf 'SELF-TEST: PASS — planted lie caught (missing path, no gate, unresolved referents); control row untouched.\n'
    exit 0
  fi
  printf 'SELF-TEST: FAIL — %s assertion(s) failed.\n' "$fails"
  exit 2
}

# ── main ───────────────────────────────────────────────────────────────────────
mode=report
for a in "$@"; do
  case "$a" in
    --help|-h)   usage; exit 0 ;;
    --self-test) self_test ;;
    --write)     mode=write ;;
    --check)     mode=check ;;
    --run-gates) run_gates=1 ;;
    --heavy)     heavy=1 ;;
    "")          ;;
    *)           die "unknown argument: $a (try --help)" ;;
  esac
done

[ -f "$CONSTITUTION" ] || die "source not found: $CONSTITUTION"
tsv=$(probe_rows "$CONSTITUTION")
[ -n "$tsv" ] || die "no §2 rows parsed from $CONSTITUTION (table format changed?)"

case "$mode" in
  report) report "$tsv" ;;
  check)
    report "$tsv"
    if findings "$tsv" | grep -q 'failures=0'; then
      printf '\ncheck: PASS — every §2 row declares a runnable gate and every protected referent resolves.\n'
      exit 0
    fi
    printf '\ncheck: FAIL — findings above are filed, not fixed (exit 1).\n'
    exit 1 ;;
  write)
    mkdir -p "$OUT"
    report "$tsv" > "$OUT/REGISTRY.md"
    {
      printf 'line\tproject\tpath\texists\tgate_kind\tgate_cmd\ttier\trefs_ok\trefs_missing\tmissing\tnonlocal\tshorthand\n'
      printf '%s\n' "$tsv"
    } > "$OUT/registry.tsv"
    printf 'wrote: %s/REGISTRY.md\nwrote: %s/registry.tsv\n' "${OUT#$HOME_DIR/}" "${OUT#$HOME_DIR/}" ;;
esac


