#!/usr/bin/env bash
# Structural verification of the PAUL repositories (flat dependency model).
#
# Run with Git Bash from anywhere:  bash verify.sh
#
# Model: only workspace-* repos have submodules; they mount, flat, under
# .agents/skills/_deps/<id>, their automation and the whole business parent
# chain, with relative URLs (../agent-common). agent-* and automation-* repos
# have no submodule.
#
# Hosting is simulated: bare copies <repo>.git are made in
# .verify-tmp/host/<org>/ (same layout as a GitHub organisation) and the
# workspaces are cloned from there. Everything happens in ./.verify-tmp
# (deleted at the end, kept with KEEP_TMP=1). Nothing is sent anywhere.
#
# Optional harness probes (skipped when not installed):
#   PI_INDEX     path to @earendil-works/pi-coding-agent/dist/index.js
#   HERMES_DIR   hermes-agent checkout; HERMES_PY its venv python
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MONOREPO="${MONOREPO:-$ROOT/../pi-workspace}"
TMP="$ROOT/.verify-tmp"
SCAFFOLD="$ROOT/automation-create-use-case/.agents/skills/create-use-case/scripts/scaffold.py"
PY="${PYTHON:-python}"
export PYTHONIOENCODING=utf-8

AGENTS=(agent-common agent-authoring agent-finance agent-contract-management)
AUTOMATIONS=(automation-create-use-case automation-obligations)
WORKSPACES=(workspace-create-use-case workspace-obligations)
REPOS=("${AGENTS[@]}" "${AUTOMATIONS[@]}" "${WORKSPACES[@]}")

export GIT_CONFIG_COUNT=3 \
  GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always \
  GIT_CONFIG_KEY_1=core.longpaths      GIT_CONFIG_VALUE_1=true \
  GIT_CONFIG_KEY_2=advice.detachedHead GIT_CONFIG_VALUE_2=false

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   $*"; }
ko()   { FAIL=$((FAIL+1)); echo "  FAIL $*"; }
check() { local msg=$1; shift; if "$@" >/dev/null 2>&1; then ok "$msg"; else ko "$msg"; fi; }
section() { echo; echo "== $*"; }
skills_of() { (cd "$1" && find .agents/skills -name SKILL.md 2>/dev/null | sort); }
has_skill() { skills_of "$1" | grep -q "/$2/SKILL.md$"; }
skill_count() { skills_of "$1" | grep -c "/$2/SKILL.md$"; }
tracked() { git -C "$1" ls-files; }
deps_of() { git -C "$1" config -f .gitmodules --get-regexp '^submodule\..*\.url$' 2>/dev/null \
            | sed -E 's#^submodule\.\.agents/skills/_deps/([^ ]+)\.url #\1=#' | sort | tr '\n' ' '; }

rm -rf "$TMP"; mkdir -p "$TMP"

# ---------------------------------------------------------------------------
section "Git — status and submodule status in each repo"
for r in "${REPOS[@]}"; do
  check "$r: git status --short is clean" test -z "$(git -C "$ROOT/$r" status --short)"
  check "$r: git submodule status --recursive" git -C "$ROOT/$r" submodule status --recursive
  if git -C "$ROOT/$r" submodule status --recursive | grep -qE '^[-+U]'; then
    ko "$r: submodules initialised at the recorded commit"
  else ok "$r: submodules initialised at the recorded commit"; fi
done

section "Flat model — only workspaces have submodules, relative URLs"
for r in "${AGENTS[@]}" "${AUTOMATIONS[@]}"; do
  check "$r has no submodule" test ! -e "$ROOT/$r/.gitmodules"
done
expect_deps() {
  local got; got=$(deps_of "$ROOT/$1")
  if [ "$got" = "$2" ]; then ok "$1 mounts: $2"; else ko "$1 mounts: expected '$2' got '$got'"; fi
}
expect_deps workspace-create-use-case "authoring=../agent-authoring automation=../automation-create-use-case "
expect_deps workspace-obligations "automation=../automation-obligations common=../agent-common contract-management=../agent-contract-management finance=../agent-finance "
check "no host or organisation hard-coded in .gitmodules" test -z "$(cat "$ROOT"/workspace-*/.gitmodules | grep -E 'url = .*(github|gitlab|@|://)')"

section "Short names — no parent names in use-case repos"
for r in "${AUTOMATIONS[@]}" "${WORKSPACES[@]}"; do
  check "$r does not contain 'finance' or 'contract-management'" test -z "$(echo "$r" | grep -E 'finance|contract-management')"
done

# ---------------------------------------------------------------------------
section "Simulated hosting (bare <repo>.git in one organisation)"
HOST="$TMP/host/paul-org"; mkdir -p "$HOST"
for r in "${REPOS[@]}"; do
  git clone -q --bare "$ROOT/$r" "$HOST/$r.git" || ko "bare copy $r"
done
ok "8 bare repositories published in the simulated organisation"

section "Clean recursive clone of workspace-obligations (from the simulated host)"
OBL="$TMP/clone/workspace-obligations"
check "git clone --recurse-submodules <host>/workspace-obligations.git" git clone -q --recurse-submodules "$HOST/workspace-obligations.git" "$OBL"
SUBS=$(git -C "$OBL" submodule status --recursive 2>/dev/null)
for d in automation contract-management finance common; do
  if printf '%s\n' "$SUBS" | grep -q " .agents/skills/_deps/$d "; then ok "submodule _deps/$d"; else ko "submodule _deps/$d"; fi
done
check "exactly 4 submodules, none nested" test "$(printf '%s\n' "$SUBS" | grep -c .)" = 4
for s in obligation-register-duckdb contract-obligation-extraction structured-data-duckdb start-use-case document-processing; do
  check "skill $s present exactly once" test "$(skill_count "$OBL" "$s")" = 1
done
check "obligation-register-duckdb at _deps/automation/.agents/skills" test -f "$OBL/.agents/skills/_deps/automation/.agents/skills/obligation-register-duckdb/SKILL.md"
check "contract-obligation-extraction at _deps/contract-management/.agents/skills" test -f "$OBL/.agents/skills/_deps/contract-management/.agents/skills/contract-obligation-extraction/SKILL.md"
check "structured-data-duckdb at _deps/common/.agents/skills" test -f "$OBL/.agents/skills/_deps/common/.agents/skills/structured-data-duckdb/SKILL.md"
check "test ! -d workspace" test ! -d "$OBL/workspace"
for d in contract data output evaluator .tmp; do check "root folder $d/" test -d "$OBL/$d"; done
check "no process-automation-bootstrap skill" test -z "$(skills_of "$OBL" | grep process-automation-bootstrap)"
check "Pi adapter lists the 4 mounted skill dirs" test "$(grep -c '_deps/[a-z-]*/.agents/skills"' "$OBL/.pi/settings.json")" = 4
LONGEST=$(cd "$OBL" && find . -type f | awk '{print length}' | sort -n | tail -1)
check "longest path in the clone is short ($LONGEST chars relative)" test "$LONGEST" -lt 120

section "Clean recursive clone of workspace-create-use-case (from the simulated host)"
CUC="$TMP/clone/workspace-create-use-case"
check "git clone --recurse-submodules" git clone -q --recurse-submodules "$HOST/workspace-create-use-case.git" "$CUC"
for s in create-use-case grill-me; do check "skill $s present exactly once" test "$(skill_count "$CUC" "$s")" = 1; done
check "catalog target_root: .." grep -qx 'target_root: \.\.' "$CUC/catalog.yaml"
for p in "common:../agent-common" "finance:../agent-finance" "contract-management:../agent-contract-management"; do
  check "catalog parent ${p%%:*} -> ${p#*:}" grep -q "git: ${p#*:}$" "$CUC/catalog.yaml"
done
check "catalog chain contract-management -> finance -> common" \
  "$PY" -c "import yaml,sys; c=yaml.safe_load(open(sys.argv[1],encoding='utf-8'))['parents']; assert c['contract-management']['parent']=='finance' and c['finance']['parent']=='common' and 'parent' not in c['common']" "$CUC/catalog.yaml"
for f in READINESS ASSUMPTIONS OPEN_QUESTIONS PROMOTION_CANDIDATES GENERATED interview; do check ".create-use-case/$f.md" test -f "$CUC/.create-use-case/$f.md"; done
check "no business skill visible from create-use-case" test -z "$(skills_of "$CUC" | grep -E 'structured-data-duckdb|start-use-case|contract-obligation')"

# ---------------------------------------------------------------------------
section "Data and logic separation"
for r in "${AUTOMATIONS[@]}"; do
  check "$r: no business data files" test -z "$(tracked "$ROOT/$r" | grep -iE '\.(pdf|xlsx|xls|docx|duckdb|csv)$')"
  check "$r: no data folders" test -z "$(tracked "$ROOT/$r" | grep -E '^(contract|input|data|output|documents|state|evaluator|test-data|workspace)/')"
done
for r in "${WORKSPACES[@]}"; do
  check "$r: no local skill/agent/script outside _deps" test -z "$(tracked "$ROOT/$r" | grep -E '(^|/)SKILL\.md$|^agents/|^scripts/')"
  check "$r: no workspace/ sub-directory" test -z "$(tracked "$ROOT/$r" | grep -E '^workspace/')"
done
check "BOOTSTRAP_TASK.md only as docs/legacy" test "$(tracked "$ROOT/automation-obligations" | grep BOOTSTRAP_TASK)" = "docs/legacy/BOOTSTRAP_TASK.md"
active=$(for r in "${REPOS[@]}"; do tracked "$ROOT/$r" | grep -v '^docs/legacy/' | sed "s#^#$ROOT/$r/#"; done \
  | tr '\n' '\0' | xargs -0 grep -lE 'Utilise le skill `process-automation-bootstrap`|Use process-automation-bootstrap' 2>/dev/null)
check "no active instruction to use process-automation-bootstrap" test -z "$active"
check "no package.json" test -z "$(for r in "${REPOS[@]}"; do tracked "$ROOT/$r" | grep -E '(^|/)package\.json$'; done)"
check "no .pi/skills or .hermes/skills copies" test -z "$(for r in "${REPOS[@]}"; do tracked "$ROOT/$r" | grep -E '^\.(pi|hermes)/skills/'; done)"

section "Skill frontmatter (name == directory, description, valid YAML)"
while IFS= read -r f; do
  if "$PY" - "$f" <<'EOF' >/dev/null 2>&1
import re, sys, pathlib, yaml
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", t, re.S); fm = yaml.safe_load(m.group(1))
assert fm["name"] == p.parent.name and fm["description"]
EOF
  then ok "${f#$ROOT/}"; else ko "${f#$ROOT/}"; fi
done < <(for r in "${REPOS[@]}"; do tracked "$ROOT/$r" | grep -E '^\.agents/skills/[^/]+/SKILL\.md$' | sed "s#^#$ROOT/$r/#"; done)

section "Migrated data is bit-identical to the monorepo HEAD"
if [ -d "$MONOREPO/.git" ]; then
  SRC=domains/contract-management/obligations; diffs=0
  while read -r mode blob stage path; do
    case "$path" in .gitmodules|.pi/*|README.md|TASK.md|.agents/*) continue ;;
      evaluator/*) src="$SRC/$path" ;; *) src="$SRC/workspace/$path" ;; esac
    [ "$(git -C "$MONOREPO" rev-parse "HEAD:$src" 2>/dev/null)" = "$blob" ] || { diffs=$((diffs+1)); echo "     differs: $path"; }
  done < <(git -C "$ROOT/workspace-obligations" ls-files -s)
  check "data/evaluator files identical to the monorepo (0 differences)" test "$diffs" = 0
  n_src=$(git -C "$MONOREPO" ls-tree -r --name-only HEAD "$SRC/workspace" "$SRC/evaluator" | wc -l)
  n_dst=$(git -C "$ROOT/workspace-obligations" ls-files | grep -vE '^(\.gitmodules|\.pi/|README\.md|TASK\.md|\.agents/)' | wc -l)
  check "same number of data/evaluator files ($n_src)" test "$n_src" = "$n_dst"
  check "monorepo source intact (no tracked change)" test -z "$(git -C "$MONOREPO" status --short --untracked-files=no)"
else
  echo "  skip monorepo not found at $MONOREPO"
fi

# ---------------------------------------------------------------------------
section "create-use-case scaffold (static tests, sandbox with the agent-* repos)"
SB="$TMP/sandbox"; mkdir -p "$SB"
for r in "${AGENTS[@]}"; do git clone -q "$ROOT/$r" "$SB/$r"; done
run_scaffold() { (cd "$SB" && "$PY" "$SCAFFOLD" "$@") >"$TMP/scaffold.log" 2>&1 || { cat "$TMP/scaffold.log"; return 1; }; }
CM=(--dep contract-management=../agent-contract-management --dep finance=../agent-finance --dep common=../agent-common)

check "simple task attached to finance" run_scaffold simple-task --name monthly-finance-review \
  --target-root . --parent-id finance --dep finance=../agent-finance --dep common=../agent-common
W="$SB/workspace-monthly-finance-review"
check "  single repo (no automation-*)" test ! -e "$SB/automation-monthly-finance-review"
check "  mounts exactly finance and common" test "$(deps_of "$W")" = "common=../agent-common finance=../agent-finance "
check "  inherits common skills" has_skill "$W" structured-data-duckdb
check "  does NOT inherit contract-management" test -z "$(skills_of "$W" | grep contract-obligation-extraction)"
check "  TASK.md, input/, output/ at root; no workspace/" test -f "$W/TASK.md" -a -d "$W/input" -a -d "$W/output" -a ! -d "$W/workspace"
check "  state PARENT_MODULE: finance" grep -q '^PARENT_MODULE: finance$' "$W/.create-use-case/READINESS.md"
check "  Pi adapter lists finance and common" test "$(grep -c '_deps/\(finance\|common\)/.agents/skills' "$W/.pi/settings.json")" = 2
check "  committed and clean" test -z "$(git -C "$W" status --short)"
check "  recursive clone of the generated repo works" git clone -q --recurse-submodules "$W" "$TMP/clone-simple-finance"

check "simple task attached to contract-management" run_scaffold simple-task --name supplier-contract-review \
  --target-root . --parent-id contract-management "${CM[@]}" --dirs input,output,documents
W="$SB/workspace-supplier-contract-review"
check "  mounts contract-management, finance, common" test "$(deps_of "$W")" = "common=../agent-common contract-management=../agent-contract-management finance=../agent-finance "
check "  contract-obligation-extraction visible once" test "$(skill_count "$W" contract-obligation-extraction)" = 1
check "  no local SKILL.md outside _deps" test -z "$(tracked "$W" | grep SKILL.md)"

check "automation (obligations model, scaffold only)" run_scaffold automation --name obligations-demo \
  --target-root . --parent-id contract-management "${CM[@]}" --dirs contract,data,output,evaluator
A="$SB/automation-obligations-demo"; W="$SB/workspace-obligations-demo"
check "  automation + workspace repos" test -d "$A/.git" -a -d "$W/.git"
check "  automation has no submodule" test ! -e "$A/.gitmodules"
check "  workspace mounts automation + chain, flat" test "$(deps_of "$W")" = "automation=../automation-obligations-demo common=../agent-common contract-management=../agent-contract-management finance=../agent-finance "
check "  no local skill or agents/ by default" test -z "$(tracked "$A" | grep -E 'SKILL\.md|^agents/')"
check "  data folders only in the workspace" test -d "$W/contract" -a ! -d "$A/contract"
check "  .create-use-case/ in the automation repo" test -f "$A/.create-use-case/READINESS.md"
check "  both repos committed and clean" test -z "$(git -C "$A" status --short)$(git -C "$W" status --short)"

check "automation with explicit placeholders (--no-git)" run_scaffold automation --name placeholders-demo \
  --target-root . --parent-id finance --dep finance=../agent-finance --dep common=../agent-common --no-git \
  --placeholder-skills stub-skill,dir-skill:dir,empty-skill:empty --placeholder-agents reviewer
A="$SB/automation-placeholders-demo"
check "  stub SKILL.md is valid" grep -q '^description: TODO - à définir.$' "$A/.agents/skills/stub-skill/SKILL.md"
check "  dir placeholder has no SKILL.md" test -d "$A/.agents/skills/dir-skill" -a ! -f "$A/.agents/skills/dir-skill/SKILL.md"
check "  empty SKILL.md" test -f "$A/.agents/skills/empty-skill/SKILL.md" -a ! -s "$A/.agents/skills/empty-skill/SKILL.md"
check "  agent placeholder" test -f "$A/agents/reviewer/AGENTS.md"
check "  --no-git: no repository" test ! -d "$A/.git"

check "refuses to overwrite an existing repo" bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' simple-task --name supplier-contract-review --target-root . --parent-id finance --dep finance=../agent-finance"
check "rejects a non kebab-case name" bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' simple-task --name Bad_Name --target-root . --parent-id finance --dep finance=../agent-finance"
check "rejects a parent missing from --dep" bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' simple-task --name x --target-root . --parent-id finance --dep common=../agent-common"

# ---------------------------------------------------------------------------
section "Harness probes (optional)"
PI_INDEX="${PI_INDEX:-$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent/dist/index.js}"
PROBES=("$OBL:obligation-register-duckdb contract-obligation-extraction structured-data-duckdb start-use-case document-processing"
        "$CUC:create-use-case grill-me")
if [ -f "$PI_INDEX" ] && command -v node >/dev/null; then
  for pair in "${PROBES[@]}"; do
    dir=${pair%%:*}; out=$(node "$ROOT/harness-check/pi-skills.mjs" "$PI_INDEX" "$dir" 2>"$TMP/pi.err")
    for s in ${pair#*:}; do
      if [ "$(printf '%s\n' "$out" | grep -c "^$s	")" = 1 ]; then ok "Pi loads $s once ($(basename "$dir"))"; else ko "Pi loads $s once ($(basename "$dir"))"; fi
    done
    check "Pi: no skill diagnostics ($(basename "$dir"))" test ! -s "$TMP/pi.err"
  done
else echo "  skip Pi not found (set PI_INDEX)"; fi
HERMES_DIR="${HERMES_DIR:-${LOCALAPPDATA:-}/hermes/hermes-agent}"
HERMES_PY="${HERMES_PY:-$HERMES_DIR/venv/Scripts/python.exe}"
if [ -f "$HERMES_DIR/agent/skill_utils.py" ] && [ -x "$HERMES_PY" ]; then
  for pair in "${PROBES[@]}"; do
    dir=${pair%%:*}; out=$("$HERMES_PY" "$ROOT/harness-check/hermes_skills.py" "$HERMES_DIR" "$dir" 2>/dev/null)
    for s in ${pair#*:}; do
      if [ "$(printf '%s\n' "$out" | grep -c "^$s	")" = 1 ]; then ok "Hermes indexes $s once ($(basename "$dir"))"; else ko "Hermes indexes $s once ($(basename "$dir"))"; fi
    done
  done
else echo "  skip Hermes not found (set HERMES_DIR / HERMES_PY)"; fi

# ---------------------------------------------------------------------------
[ "${KEEP_TMP:-0}" = 1 ] || rm -rf "$TMP"
echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
