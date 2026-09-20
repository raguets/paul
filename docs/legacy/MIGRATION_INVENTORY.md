# MIGRATION_INVENTORY — pi-workspace → multi-repos

> Audit initial (phase 0). Les destinations ont ensuite été révisées (noms
> courts, modèle plat) : voir `MIGRATION_REPORT.md` §0 et `ARCHITECTURE.md`.

Audit réalisé le 2026-09-19 sur `G:\DEV\pi-workspace` (branche `main`, HEAD `891f3cf`),
avant toute création de repo. Le monorepo n'a pas été modifié (seul fichier non suivi :
`spec-refactoring-pi-workspace-multi-repos-v1.2.md`, la spécification elle-même).

## 1. Fichiers du monorepo (63 fichiers suivis)

| Zone | Fichiers |
|---|---|
| Racine | `AGENTS.md`, `README.md`, `LICENSE` (MIT, openlabollioules) |
| `.agents/skills/document-processing/` | `SKILL.md`, `README.md`, `agents/openai.yaml`, `assets/icon.svg`, `references/pi-docparser.md` |
| `.agents/skills/process-automation-bootstrap/` | `SKILL.md` (V3, 36 Ko), `README.md` |
| `.agents/skills/structured-data-duckdb/` | `SKILL.md` |
| `domains/contract-management/` | `AGENTS.md` (règles de domaine) |
| `domains/contract-management/obligations/` | `PROCESS_AUTOMATION.md`, `AUTOMATION_SPEC.md`, `TASK.md`, `README.md`, `AGENTS.md`, `BOOTSTRAP_TASK.md` |
| `…/obligations/.agents/skills/` | `contract-obligation-extraction/SKILL.md`, `obligation-register-duckdb/SKILL.md` |
| `…/obligations/.bootstrap/` | `READINESS.md`, `ASSUMPTIONS.md`, `OPEN_QUESTIONS.md`, `DECISIONS.md` |
| `…/obligations/evaluator/` | `ground-truth.md`, `scoring-rubric.md`, `.parts/` (9 fragments) |
| `…/obligations/workspace/` | voir §3 |

## 2. `SKILL.md` présents (5)

| Skill | Emplacement actuel | Destination |
|---|---|---|
| `document-processing` | `.agents/skills/` (COMMON) | `agent-common` |
| `structured-data-duckdb` | `.agents/skills/` (COMMON) | `agent-common` (+ `PORTABILITY.md`) |
| `process-automation-bootstrap` | `.agents/skills/` (COMMON) | **non migré comme skill** → absorbé par `create-use-case`, archivé en `automation-create-use-case/docs/legacy/` |
| `contract-obligation-extraction` | `obligations/.agents/skills/` (LOCAL) | **promu** dans `agent-contract-management` |
| `obligation-register-duckdb` | `obligations/.agents/skills/` (LOCAL) | `automation-obligations` (reste LOCAL) |

Aucun skill de domaine sous `domains/contract-management/.agents/skills/` (le répertoire n'existe pas).

## 3. Contenu de `obligations/workspace/` (à aplatir)

| Ancien chemin | Nouveau chemin (repo workspace) | Contenu |
|---|---|---|
| `workspace/contract/` | `contract/` | 2 PDF + 3 XLSX (corpus FNG-01, lecture seule) |
| `workspace/data/` | `data/` | `obligations.duckdb` (6,8 Mo) + `.gitkeep` |
| `workspace/output/` | `output/` | 4 rapports + `.parts/` (9 fragments) + `.gitkeep` |
| `workspace/.tmp/` | `.tmp/` | 8 scripts Python de run (`gen_f*.py`, `ins_*.py`) |
| `workspace/input/` | — | **absent** : non créé |
| `evaluator/` | `evaluator/` | ground truth + rubric |
| `test-data/` | — | **absent** dans le monorepo : non créé |

Aucun répertoire `documents/` ni `state/` n'existe : ils ne sont pas créés.

## 4. État `.bootstrap`

`READINESS.md`, `ASSUMPTIONS.md`, `OPEN_QUESTIONS.md`, `DECISIONS.md`
(pas de `PROMOTION_CANDIDATES.md`). R1–R10 tous `CONFIRMED`.
Destination : `automation-obligations/.create-use-case/`.

## 5. Agents locaux

Aucun répertoire `agents/` dans `obligations` : un seul agent principal
(`obligations/AGENTS.md` + `TASK.md`). Aucun agent additionnel à migrer.
(`document-processing/agents/openai.yaml` est une métadonnée de skill, pas un agent.)

## 6. `AGENTS.md`

| Fichier | Traitement |
|---|---|
| `AGENTS.md` (plateforme) | Conservé en référence : `agent-common/docs/legacy/AGENTS.md` (non actif) |
| `domains/contract-management/AGENTS.md` | Conservé en référence : `agent-contract-management/docs/legacy/AGENTS.md` (non actif) |
| `obligations/AGENTS.md` | Définition de l'agent principal → racine du repo automation, référencé explicitement par `TASK.md` |

## 7. Points d'attention identifiés pendant l'audit

1. **Pi ne découvre pas les skills sous un répertoire caché imbriqué.**
   `@earendil-works/pi-coding-agent` 0.84.2 (`dist/core/package-manager.js`, `collectSkillEntries`)
   ignore tout répertoire dont le nom commence par `.` pendant la récursion. Les skills situés sous
   `.agents/skills/_deps/<x>/.agents/skills/` ne sont donc **pas** découverts automatiquement par Pi,
   contrairement à l'hypothèse de la spec §6. Hermes 0.21.2 (`agent/skill_utils.py`,
   `iter_skill_index_files`) parcourt bien ces répertoires (seuls `.git`, `node_modules`, `.venv`…
   sont exclus).
   → Adaptateur Pi minimal : `.pi/settings.json` projet listant les répertoires `.agents/skills` des
   dépendances (aucune copie de skill).
2. `structured-data-duckdb` et `document-processing` référencent des extensions Pi (`pi-office`,
   `pi-alchemy`, `pi-docparser`) → notes `PORTABILITY.md`.
3. Plusieurs fichiers d'obligations utilisent le préfixe `workspace/` → à adapter (chemins seulement).
4. `BOOTSTRAP_TASK.md` et `README.md` d'obligations référencent `process-automation-bootstrap`.
