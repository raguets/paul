#!/usr/bin/env bash
# Structural verification of the PAUL monorepo.
#
# Run with Git Bash from anywhere:  bash verify.sh
#
# Model: one Git repo `paul` holds all the agentic logic; the business
# hierarchy is expressed by folders; skills are inherited structurally through
# `.agents/skills` at each level; the persistent data of a use case lives in a
# nested, independent Git repository `workspace-<slug>` that `paul` ignores.
# No `_deps`, no agentic submodule, no `automation-*` / `agent-*` repository,
# no `authoring/` level.
#
# Scaffold tests run in a throw-away sandbox under ./.verify-tmp (deleted at
# the end, kept with KEEP_TMP=1). Nothing is sent anywhere.
#
# Optional harness probes (skipped when not installed):
#   PI_INDEX     path to @earendil-works/pi-coding-agent/dist/index.js
#   HERMES_DIR   hermes-agent checkout; HERMES_PY its venv python
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP="$ROOT/.verify-tmp"
SCAFFOLD="$ROOT/.agents/skills/create-use-case/scripts/scaffold.py"
PY="${PYTHON:-python}"
export PYTHONIOENCODING=utf-8

COMMON_SKILLS=(create-use-case grill-me start-use-case structured-data-duckdb document-processing)
USE_CASES=(finance/contract-management/obligations rh/recrutement/candidature)
WORKSPACES=(finance/contract-management/obligations/workspace-obligations
            rh/recrutement/candidature/workspace-candidature)

export GIT_CONFIG_COUNT=2 \
  GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always \
  GIT_CONFIG_KEY_1=core.longpaths      GIT_CONFIG_VALUE_1=true

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   $*"; }
ko()   { FAIL=$((FAIL+1)); echo "  FAIL $*"; }
check() { local msg=$1; shift; if "$@" >/dev/null 2>&1; then ok "$msg"; else ko "$msg"; fi; }
section() { echo; echo "== $*"; }
tracked() { git -C "$1" ls-files; }

rm -rf "$TMP"; mkdir -p "$TMP"

# ---------------------------------------------------------------------------
section "Monorepo — one repository for all the agentic logic"
check "paul is a Git repository" test -d "$ROOT/.git"
check "paul/README.md exists" test -f "$ROOT/README.md"
check "no _deps anywhere" test -z "$(find "$ROOT" -path '*/.agents/skills/_deps' -not -path '*/.verify-tmp/*')"
check "no agentic submodule (.gitmodules)" test -z "$(find "$ROOT" -name .gitmodules -not -path '*/.verify-tmp/*')"
check "no authoring/ level" test ! -d "$ROOT/authoring"
check "no automation-* directory" test -z "$(find "$ROOT" -maxdepth 3 -type d -name 'automation-*' -not -path '*/.verify-tmp/*')"
check "no agent-* directory" test -z "$(find "$ROOT" -maxdepth 3 -type d -name 'agent-*' -not -path '*/.verify-tmp/*')"
check "no workspace-create-use-case" test ! -d "$ROOT/workspace-create-use-case"
check "no process-automation-bootstrap skill" test -z "$(find "$ROOT" -type d -name process-automation-bootstrap)"
active=$(grep -rlE 'Utilise le skill `process-automation-bootstrap`|Use process-automation-bootstrap' \
  "$ROOT" --exclude-dir=.git --exclude-dir=.verify-tmp --exclude-dir='workspace-*' \
  --exclude='spec-refactoring-*.md' --exclude=verify.sh 2>/dev/null)
check "no active instruction to use process-automation-bootstrap" test -z "$active"

section "Common skills at paul/.agents/skills"
for s in "${COMMON_SKILLS[@]}"; do
  check "$s/SKILL.md" test -f "$ROOT/.agents/skills/$s/SKILL.md"
done
check "create-use-case/scripts/scaffold.py" test -f "$SCAFFOLD"
check "no catalog-driven target root left" test ! -f "$ROOT/.agents/skills/create-use-case/catalog.yaml"

section "Business hierarchy — folders, skills at the right level"
check "finance/contract-management/.agents/skills/contract-obligation-extraction" \
  test -f "$ROOT/finance/contract-management/.agents/skills/contract-obligation-extraction/SKILL.md"
check "obligations/.agents/skills/obligation-register-duckdb" \
  test -f "$ROOT/finance/contract-management/obligations/.agents/skills/obligation-register-duckdb/SKILL.md"
check "contract-obligation-extraction is NOT at the use case level" \
  test ! -e "$ROOT/finance/contract-management/obligations/.agents/skills/contract-obligation-extraction"
check "obligation-register-duckdb is NOT at the sub-domain level" \
  test ! -e "$ROOT/finance/contract-management/.agents/skills/obligation-register-duckdb"
for s in contract-obligation-extraction obligation-register-duckdb analyse-candidature; do
  n=$(find "$ROOT" -path '*/.agents/skills/'"$s"'/SKILL.md' -not -path '*/.verify-tmp/*' | wc -l)
  check "$s exists exactly once (no duplicate for a harness)" test "$n" = 1
done

section "Use cases — functional names, single model, no README"
for uc in "${USE_CASES[@]}"; do
  name=$(basename "$uc")
  check "$name: TASK.md at the use case root" test -f "$ROOT/$uc/TASK.md"
  check "$name: no prefix in the folder name" test -z "$(echo "$name" | grep -E '^(automation|agent|workspace)-')"
  check "$name: no README.md" test ! -f "$ROOT/$uc/README.md"
  check "$name: no .create-use-case/ state" test ! -e "$ROOT/$uc/.create-use-case"
done
for d in finance finance/contract-management rh rh/recrutement; do
  check "no intermediate README at $d/" test ! -f "$ROOT/$d/README.md"
done
check "no transient create-use-case state committed" test -z "$(tracked "$ROOT" | grep '^\.create-use-case/')"

section "Workspaces — nested independent Git repositories"
check ".gitignore ignores **/*workspace*" grep -qx '\*\*/\*workspace\*' "$ROOT/.gitignore"
check ".gitignore ignores /.create-use-case/" grep -qx '/\.create-use-case/' "$ROOT/.gitignore"
check ".gitignore ignores the generated /.hermes/ adapter" grep -qx '/\.hermes/' "$ROOT/.gitignore"
check "no .pi/settings.json anywhere (Pi needs no adapter)" \
  test -z "$(find "$ROOT" -name settings.json -path '*/.pi/*' -not -path '*/.verify-tmp/*')"
check "paul tracks no workspace file" test -z "$(tracked "$ROOT" | grep -i workspace)"
check "git status --short hides the workspaces" test -z "$(git -C "$ROOT" status --short | grep -i workspace)"
for ws in "${WORKSPACES[@]}"; do
  name=$(basename "$ws")
  check "$name: own .git" test -d "$ROOT/$ws/.git"
  check "$name: sits under its use case" test -f "$ROOT/$(dirname "$ws")/TASK.md"
  check "$name: no workspace/ sub-directory" test ! -d "$ROOT/$ws/workspace"
  check "$name: no .agents/ (skills stay in paul)" test ! -d "$ROOT/$ws/.agents"
  check "$name: no TASK.md (entry point is the use case)" test ! -f "$ROOT/$ws/TASK.md"
  check "$name: no submodule" test ! -e "$ROOT/$ws/.gitmodules"
  check "$name: clean working tree (tracked files)" test -z "$(git -C "$ROOT/$ws" status --short --untracked-files=no)"
  remote=$(git -C "$ROOT/$ws" remote get-url origin 2>/dev/null)
  paul_remote=$(git -C "$ROOT" remote get-url origin 2>/dev/null)
  if [ -z "$remote" ]; then ok "$name: no remote yet (local repository)"
  elif [ "$remote" != "$paul_remote" ]; then ok "$name: remote distinct from paul ($remote)"
  else ko "$name: remote is the same as paul"; fi
done
check "obligations data stays in its workspace" test -f "$ROOT/finance/contract-management/obligations/workspace-obligations/data/obligations.duckdb"
check "no business data tracked by paul" test -z "$(tracked "$ROOT" | grep -iE '\.(pdf|xlsx|xls|docx|duckdb|csv)$')"

section "Skill frontmatter (name == directory, description, valid YAML)"
while IFS= read -r f; do
  if "$PY" - "$f" <<'EOF' >/dev/null 2>&1
import re, sys, pathlib, yaml
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", t, re.S); fm = yaml.safe_load(m.group(1))
assert fm["name"] == p.parent.name and fm["description"]
EOF
  then ok "${f#$ROOT/}"; else ko "${f#$ROOT/}"; fi
done < <(find "$ROOT" -path '*/.agents/skills/*/SKILL.md' \
           -not -path '*/.verify-tmp/*' -not -path '*/workspace-*/*' | sort)

# ---------------------------------------------------------------------------
section "create-use-case scaffold (sandbox monorepo)"
SB="$TMP/sandbox"; mkdir -p "$SB/finance/contract-management/.agents/skills/demo-subdomain-skill" \
                            "$SB/.agents/skills/demo-common-skill"
printf -- "---\nname: demo-common-skill\ndescription: demo.\n---\n" > "$SB/.agents/skills/demo-common-skill/SKILL.md"
printf -- "---\nname: demo-subdomain-skill\ndescription: demo.\n---\n" > "$SB/finance/contract-management/.agents/skills/demo-subdomain-skill/SKILL.md"
cp "$ROOT/.gitignore" "$SB/.gitignore"
git -C "$SB" init -q -b main && git -C "$SB" add -A && git -C "$SB" commit -q -m "sandbox"
run_scaffold() { (cd "$1" && shift && "$PY" "$SCAFFOLD" "$@") >"$TMP/scaffold.log" 2>&1 \
                 || { cat "$TMP/scaffold.log"; return 1; }; }

check "use case created in the current directory (CU1)" \
  run_scaffold "$SB/finance/contract-management" use-case --name test-case
UC="$SB/finance/contract-management/test-case"
check "  folder carries the functional name" test -d "$UC"
check "  TASK.md generated" test -f "$UC/TASK.md"
check "  no .agents/skills when no specific skill is needed (CU4)" test ! -e "$UC/.agents/skills"
check "  no workspace when no persistent data is needed (CU5)" test -z "$(find "$UC" -maxdepth 1 -name 'workspace-*')"
check "  no .create-use-case/ inside the use case (CU3)" test ! -e "$UC/.create-use-case"
check "  no README.md" test ! -f "$UC/README.md"
check "  no .pi/settings.json written (Pi walks up on its own)" test ! -e "$UC/.pi"
check "  no _deps, no submodule" test ! -e "$UC/.agents/skills/_deps" -a ! -e "$UC/.gitmodules"

check "use case with a local skill, scripts and a workspace" \
  run_scaffold "$SB" use-case --name demo-full --parent-dir finance/contract-management \
    --skills demo-local --scripts --workspace --workspace-dirs input,output
UC="$SB/finance/contract-management/demo-full"
check "  local skill stub is valid" grep -q '^name: demo-local$' "$UC/.agents/skills/demo-local/SKILL.md"
check "  scripts/ created" test -d "$UC/scripts"
check "  workspace-demo-full is an independent repo (CU5)" test -d "$UC/workspace-demo-full/.git"
check "  workspace has the requested folders only" \
  test -d "$UC/workspace-demo-full/input" -a -d "$UC/workspace-demo-full/output" -a ! -d "$UC/workspace-demo-full/workspace"
check "  paul ignores the workspace" test -z "$(git -C "$SB" status --short | grep -i workspace)"
check "  workspace commits do not touch the paul index" \
  bash -c "cd '$UC/workspace-demo-full' && touch input/x && git add -A && git commit -q -m t && test -z \"\$(git -C '$SB' status --short | grep -i workspace)\""

check "rejects a prefixed name (automation-*)" \
  bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' use-case --name automation-obligations"
check "rejects a prefixed name (agent-*)" \
  bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' use-case --name agent-finance"
check "rejects a non kebab-case name" \
  bash -c "cd '$SB' && ! '$PY' '$SCAFFOLD' use-case --name Bad_Name"
check "refuses to overwrite an existing use case" \
  bash -c "cd '$SB/finance/contract-management' && ! '$PY' '$SCAFFOLD' use-case --name test-case"

# ---------------------------------------------------------------------------
section "Harness probes (optional)"
PI_INDEX="${PI_INDEX:-$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent/dist/index.js}"
if [ -f "$PI_INDEX" ] && command -v node >/dev/null; then
  probe() {
    local dir=$1; shift
    local out; out=$(node "$ROOT/harness-check/pi-skills.mjs" "$PI_INDEX" "$dir" 2>"$TMP/pi.err")
    for s in "$@"; do
      if [ "$(printf '%s\n' "$out" | grep -c "^$s	")" = 1 ]
      then ok "Pi loads $s once (from $(basename "$dir"))"
      else ko "Pi loads $s once (from $(basename "$dir"))"; fi
    done
    check "Pi: no skill diagnostics (from $(basename "$dir"))" test ! -s "$TMP/pi.err"
  }
  probe "$ROOT/finance/contract-management/obligations" \
    "${COMMON_SKILLS[@]}" contract-obligation-extraction obligation-register-duckdb
  probe "$ROOT/rh/recrutement/candidature" "${COMMON_SKILLS[@]}" analyse-candidature
  out=$(node "$ROOT/harness-check/pi-skills.mjs" "$PI_INDEX" "$ROOT/rh/recrutement/candidature" 2>/dev/null)
  check "Pi does not leak another branch's skills" \
    test -z "$(printf '%s\n' "$out" | grep -E 'obligation|contract-')"
else echo "  skip Pi not found (set PI_INDEX)"; fi

HERMES_DIR="${HERMES_DIR:-${LOCALAPPDATA:-}/hermes/hermes-agent}"
HERMES_PY="${HERMES_PY:-$HERMES_DIR/venv/Scripts/python.exe}"
hermes_skills() { "$HERMES_PY" "$ROOT/harness-check/hermes_skills.py" "$HERMES_DIR" "$1" 2>/dev/null; }
if [ -f "$HERMES_DIR/agent/skill_utils.py" ] && [ -x "$HERMES_PY" ]; then
  OBL="$ROOT/finance/contract-management/obligations"
  # Hermes scans only <git root>/.agents/skills and <git root>/.hermes/skills.
  "$PY" "$SCAFFOLD" hermes-adapter --clear >/dev/null 2>&1
  out=$(hermes_skills "$OBL")
  for s in "${COMMON_SKILLS[@]}"; do
    if [ "$(printf '%s
' "$out" | grep -c "^$s	")" = 1 ]
    then ok "Hermes indexes the common skill $s once (no adapter)"
    else ko "Hermes indexes the common skill $s once (no adapter)"; fi
  done
  check "without the adapter, Hermes misses the business levels"     test -z "$(printf '%s
' "$out" | grep -E 'contract-obligation-extraction|obligation-register-duckdb')"

  check "hermes-adapter builds the branch farm" "$PY" "$SCAFFOLD" hermes-adapter --path "$OBL"
  out=$(hermes_skills "$OBL")
  for s in "${COMMON_SKILLS[@]}" contract-obligation-extraction obligation-register-duckdb; do
    if [ "$(printf '%s
' "$out" | grep -c "^$s	")" = 1 ]
    then ok "Hermes indexes $s exactly once (with adapter)"
    else ko "Hermes indexes $s exactly once (with adapter)"; fi
  done
  check "  adapter keeps the business scoping"     test -z "$(printf '%s
' "$out" | grep analyse-candidature)"
  check "  no SKILL.md copied: each skill exists once on disk"     test "$(find "$ROOT/finance" "$ROOT/rh" -path '*/.agents/skills/*' -name SKILL.md | wc -l)" = 3
  check "  the farm is gitignored" test -z "$(git -C "$ROOT" status --short | grep hermes)"

  check "hermes-adapter --all links every branch" "$PY" "$SCAFFOLD" hermes-adapter --all
  out=$(hermes_skills "$ROOT/rh/recrutement/candidature")
  check "  analyse-candidature reachable" test "$(printf '%s
' "$out" | grep -c '^analyse-candidature	')" = 1

  check "hermes-adapter --clear removes the farm" "$PY" "$SCAFFOLD" hermes-adapter --clear
  check "  targets survived the link removal"     test -f "$ROOT/finance/contract-management/.agents/skills/contract-obligation-extraction/SKILL.md"       -a -f "$OBL/.agents/skills/obligation-register-duckdb/SKILL.md"       -a -f "$ROOT/rh/recrutement/candidature/.agents/skills/analyse-candidature/SKILL.md"
  mkdir -p "$ROOT/.hermes/skills/not-a-link" && : > "$ROOT/.hermes/skills/not-a-link/SKILL.md"
  check "  refuses to remove a real directory"     bash -c "! '$PY' '$SCAFFOLD' hermes-adapter --all"
  rm -rf "$ROOT/.hermes"
else echo "  skip Hermes not found (set HERMES_DIR / HERMES_PY)"; fi

# ---------------------------------------------------------------------------
[ "${KEEP_TMP:-0}" = 1 ] || rm -rf "$TMP"
echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
