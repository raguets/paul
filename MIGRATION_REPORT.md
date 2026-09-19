# MIGRATION_REPORT — pi-workspace → PAUL (spec v1.2, révision « modèle plat »)

Date : 2026-09-19 · Source : `G:\DEV\pi-workspace` (`main`, HEAD `891f3cf`), **non modifié**.
Racine : `G:\DEV\paul\` (repo système `paul` + 8 repos frères). Publié le 2026-09-19 dans l'organisation GitHub **`paul-agent`** (9 repos privés).

## 0. Révision par rapport à la spec v1.2

Une première passe a appliqué la spec à la lettre (chaîne de submodules imbriqués
`workspace → automation → contract-management → finance → common`, noms longs,
URLs GitLab). Elle a révélé trois contraintes : Pi ignore les skills sous
`_deps/x/.agents/…`, les chemins `.git/modules/…` imbriqués dépassent `MAX_PATH`
sous Windows, et chaque repo intermédiaire devait porter sa chaîne. Sur décision
utilisateur, la cible a été révisée :

| Point | Spec v1.2 | PAUL (retenu) |
|---|---|---|
| Dépendances | chaque repo contient son parent (imbriqué) | seul le **workspace** a des submodules ; il monte à plat l'automatisation et toute la chaîne de parents |
| Taxonomie | encodée dans les submodules et les noms | `ARCHITECTURE.md` + `catalog.yaml` (`parent:`) |
| Noms | `agent-finance-contract-management`, `…-finance-contract-management-obligations` | `agent-contract-management`, `automation-obligations`, `workspace-obligations` |
| URLs | SSH GitLab absolues | relatives (`../agent-common`), valables GitHub/GitLab/local |
| Hébergement | GitLab, 3 groupes | une organisation GitHub (à choisir : `paul` est un compte utilisateur existant) ; préfixes + topics à la place des dossiers |
| `target_root` | `../generated` | `..` (à côté des repos `agent-*`, requis par les URLs relatives) |
| Emplacement | `migration-root/` | `G:\DEV\paul\`, lui-même repo `paul` |

Écart assumé : la transitivité n'est plus « matérialisée par des submodules
imbriqués » (§2.2, §5) mais par la liste plate des submodules du workspace,
calculée par `create-use-case` depuis le catalogue.

## 1. Repos et commits locaux

Un commit par repo : `Initial split from openlabollioules/pi-workspace`.

| Repo | Commit | Fichiers | Submodules (`.agents/skills/_deps/…`) |
|---|---|---|---|
| `agent-common` | `f7598a1` | 14 | — |
| `agent-authoring` | `9f2e978` | 4 | — |
| `agent-finance` | `5784cc0` | 3 | — |
| `agent-contract-management` | `3528fb4` | 5 | — |
| `automation-create-use-case` | `ab071a2` | 24 | — |
| `automation-obligations` | `16fdf73` | 14 | — |
| `workspace-create-use-case` | `771bda5` | 14 | `automation` → `../automation-create-use-case`, `authoring` → `../agent-authoring` |
| `workspace-obligations` | `8718882` | 48 | `automation` → `../automation-obligations`, `contract-management`, `finance`, `common` |
| `paul` | voir `git log` | — | — (ignore les repos frères) |

## 2. Source → destination

| Source (monorepo) | Destination |
|---|---|
| `.agents/skills/document-processing/`, `structured-data-duckdb/` | `agent-common/.agents/skills/` (+ `PORTABILITY.md`) |
| — | `agent-common/.agents/skills/start-use-case/` (nouveau) |
| `.agents/skills/process-automation-bootstrap/` | inactif : `automation-create-use-case/docs/legacy/` ; absorbé par `create-use-case` |
| `AGENTS.md` (plateforme) | `agent-common/docs/legacy/AGENTS.md` (référence) |
| `domains/contract-management/AGENTS.md` | `agent-contract-management/docs/legacy/AGENTS.md` (référence) |
| `…/obligations/.agents/skills/contract-obligation-extraction/` | `agent-contract-management/.agents/skills/` (**promu**) |
| `…/obligations/.agents/skills/obligation-register-duckdb/` | `automation-obligations/.agents/skills/` (LOCAL) |
| `…/obligations/{PROCESS_AUTOMATION,AUTOMATION_SPEC,TASK,README,AGENTS}.md` | `automation-obligations/` (chemins adaptés) |
| `…/obligations/BOOTSTRAP_TASK.md` | `automation-obligations/docs/legacy/` (inactif, « remplacé par create-use-case ») |
| `…/obligations/.bootstrap/*` | `automation-obligations/.create-use-case/*` (champs renommés, + `PROMOTION_CANDIDATES.md`, `GENERATED.md`, D8–D9) |
| `…/obligations/workspace/{contract,data,output,.tmp}/`, `evaluator/` | `workspace-obligations/` (aplati) — 40 fichiers **identiques bit à bit** |
| grill-me upstream `600ffe9` (MIT) | `agent-authoring/.agents/skills/grill-me/` (adapté) + `THIRD_PARTY_NOTICES.md` |

Adaptations de chemins uniquement dans les fichiers de définition d'obligations
(`workspace/contract|data|output` → `contract|data|output`) ; contenu métier inchangé.

## 3. Skills

| Skill | Repo | Statut |
|---|---|---|
| `document-processing`, `structured-data-duckdb` | agent-common | déplacés |
| `start-use-case` | agent-common | nouveau |
| `grill-me` | agent-authoring | nouveau (upstream MIT adapté) |
| `contract-obligation-extraction` | agent-contract-management | promu, aucune copie locale |
| `obligation-register-duckdb` | automation-obligations | LOCAL |
| `create-use-case` | automation-create-use-case | nouveau, remplace `process-automation-bootstrap` |

## 4. Publication GitHub

Organisation : https://github.com/paul-agent (propriétaire `openlabollioules`).

1. Fait : `.\publish-github.ps1 -Org paul-agent` : crée les 9 repos (privés par défaut,
   workspaces toujours privés), ajoute les topics, `origin`, et pousse dans
   l'ordre `agent-*` → `automation-*` → `workspace-*` → `paul`.
3. Droits : équipe large sur `agent-*`/`paul`, équipe de maintenance sur
   `automation-*`, équipe « besoin d'en connaître » par workspace ; base
   permission de l'organisation à « No permission ».

Aucune modification de `.gitmodules` n'est nécessaire (URLs relatives).

## 5. Problèmes détectés et décisions

1. **Pi et les répertoires cachés** : Pi 0.84.2 saute les répertoires `.xxx`
   pendant la récursion. Adaptateur `.pi/settings.json` dans chaque workspace
   (4 chemins à profondeur 1 + `!**/README.md`), généré par
   `scaffold.py pi-adapter`. Hermes 0.21.2 n'en a pas besoin.
2. **Frontmatter YAML invalide (préexistant)** : descriptions non quotées
   contenant `: ` dans `contract-obligation-extraction` et
   `obligation-register-duckdb` → rejetées par Pi, y compris dans le monorepo.
   Corrigé (description quotée, texte inchangé).
3. **Windows `MAX_PATH`** : résolu par le modèle plat (chemin relatif le plus
   long < 120 caractères) ; `core.longpaths` reste recommandé.
4. **Duplication évitée** : monter `common` dans plusieurs repos intermédiaires
   aurait produit plusieurs copies dans un clone récursif (skills en double pour
   Hermes, versions divergentes) → aucun submodule hors workspaces.
5. **Développement d'une automatisation seule** : ses skills hérités ne sont
   visibles que depuis un workspace ; le README l'indique (développer dans
   `workspace-x/.agents/skills/_deps/automation`).
6. `obligations/AGENTS.md` à la racine de l'automatisation, référencé par
   `TASK.md` ; `AGENTS.md` plateforme/domaine en `docs/legacy/` (non chargés).
7. `.tmp/` du workspace Obligations : scripts temporaires du dernier run, migrés
   tels quels.
8. `LICENSE` MIT dans `paul`, `agent-*`, `automation-*` ; pas dans les workspaces.
9. `structured-data-duckdb`, `document-processing` : dépendances Pi documentées
   (`PORTABILITY.md`), adaptation Hermes à faire.

## 6. Hors scope

Héritage cross-repo des `AGENTS.md`, packaging, registry, résolution de
versions, CI/CD, Git LFS, secrets, `filter-repo`, promotion automatique,
collisions de noms de skills, extension « premier tour » pour `start-use-case`.

## 7. Tests effectués — `bash verify.sh` : 145 passed, 0 failed

- statut Git propre et `submodule status --recursive` dans les 8 repos ;
- modèle plat : aucun submodule dans `agent-*`/`automation-*` ; ensembles de
  submodules exacts des deux workspaces ; aucune URL absolue ;
- noms courts (aucun nom de parent dans les repos de cas d'usage) ;
- hébergement simulé (repos bare `<repo>.git` dans une « organisation ») : clone
  `--recurse-submodules` des deux workspaces, résolution des URLs relatives ;
  4 submodules non imbriqués ; chaque skill présent **une seule fois** ;
  `test ! -d workspace` ; chemins < 120 caractères ;
- catalogue : `target_root: ..`, chaîne `contract-management → finance → common` ;
- séparation données/logique, absence d'instruction active vers le bootstrap,
  pas de `package.json`, pas de `.pi/skills`/`.hermes/skills` ;
- frontmatter YAML valide des 7 skills ;
- 40 fichiers de données identiques bit à bit au monorepo ; monorepo intact ;
- `scaffold.py` : tâche simple → `finance` (monte finance+common, pas
  contract-management), tâche simple → `contract-management` (chaîne complète),
  automation (sans submodule, workspace monte automation + chaîne),
  placeholders, `--no-git`, refus d'écraser, slug invalide, parent absent des
  `--dep` ;
- sondes harness avec le code installé : Pi 0.84.2 et Hermes 0.21.2 chargent
  chaque skill exactement une fois, sans diagnostic Pi.

## 7b. Après publication

Clone propre `git clone --recurse-submodules https://github.com/paul-agent/workspace-obligations.git`
(et `workspace-create-use-case`) : URLs relatives résolues vers `paul-agent`, 4 (resp. 2)
submodules, tous les skills attendus présents.

## 8. Tests non effectués

- Scénarios conversationnels `create-use-case` A–D et `start-use-case` SU1–SU5
  (session Pi/Hermes avec modèle).
- `hermes skills trust` / approbation Pi interactive (modifient la config
  utilisateur).
- Droits d'équipes GitHub non configurés (à faire dans `paul-agent`).
