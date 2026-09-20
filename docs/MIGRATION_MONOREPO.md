# Migration vers le monorepo `paul`

Date : 2026-09-20
Spécification appliquée : [`spec-refactoring-paul-v1.4.md`](spec-refactoring-paul-v1.4.md)

Retour d'une chaîne de repos `agent-*` / `automation-*` / `workspace-*` vers un
monorepo unique `paul`, la hiérarchie métier étant portée par les dossiers.

## 1. Mapping appliqué

| Source (ancien repo) | Destination |
|---|---|
| `agent-common/.agents/skills/*` | `paul/.agents/skills/*` (`document-processing`, `structured-data-duckdb`, `start-use-case`) |
| `agent-authoring/.agents/skills/grill-me` | `paul/.agents/skills/grill-me` |
| `automation-create-use-case/.agents/skills/create-use-case` | `paul/.agents/skills/create-use-case` |
| `agent-finance` | supprimé — aucun skill Finance ; `finance/` est un simple dossier |
| `agent-contract-management/.agents/skills/*` | `paul/finance/contract-management/.agents/skills/*` |
| `automation-obligations` | `paul/finance/contract-management/obligations/` |
| `workspace-obligations` | `paul/finance/contract-management/obligations/workspace-obligations/` (repo Git indépendant conservé) |
| `agent-rh`, `agent-recrutement` | supprimés — aucun skill ; `rh/`, `rh/recrutement/` sont de simples dossiers |
| `automation-candidature` | `paul/rh/recrutement/candidature/` |
| `workspace-candidature` | `paul/rh/recrutement/candidature/workspace-candidature/` (repo Git indépendant conservé) |
| `workspace-create-use-case` | supprimé — `create-use-case` n'a plus de workspace |

## 2. Supprimé

- tous les `_deps` et les submodules agentiques (les quatre de
  `workspace-obligations`, les quatre de `workspace-candidature`, les deux de
  `workspace-create-use-case`) ;
- le niveau `authoring/` ;
- les préfixes `automation-` / `agent-` des cas d'usage (`automation-obligations`
  → `obligations`, `automation-candidature` → `candidature`) ;
- les README des niveaux intermédiaires et des cas d'usage ;
- l'état `.create-use-case/` embarqué dans les cas d'usage générés (il ne vit
  plus que dans `paul/.create-use-case/<slug>/`, gitignored et temporaire) ;
- `catalog.yaml` : les parents métier sont désormais les dossiers eux-mêmes, et
  le parent par défaut est le répertoire courant ;
- les `docs/legacy/` des anciens repos (dont
  `process-automation-bootstrap-*`), conservés dans l'archive (§4) ;
- le `TASK.md` de chaque workspace : le point d'entrée est celui du cas
  d'usage.

## 3. Adapté

- `create-use-case` : `SKILL.md`, `references/PROJECT_LAYOUTS.md`,
  `references/READINESS_MODEL.md` et `scripts/scaffold.py` réécrits pour le
  modèle monorepo. `references/GIT_SUBMODULES.md` supprimé. Les améliorations
  fonctionnelles sont conservées : existing-data-first, reuse-before-creation,
  architecture minimale, interview `grill-me`, reprise d'une création
  interrompue, génération sans invention, modes `DISCOVERY` / `COMPLETE` /
  `GENERATE_NOW` / `SCAFFOLD_ONLY`, readiness R1-R10.
  `process-automation-bootstrap` n'est pas réintroduit.
- `scaffold.py` : une seule commande `use-case` (plus de `simple-task` /
  `automation`), plus de submodule, plus de catalogue ; refuse les noms
  préfixés ; commande `pi-adapter` réécrite pour la hiérarchie de dossiers.
- `start-use-case` : le point d'entrée implicite est le `TASK.md` du
  **dossier courant** du cas d'usage, jamais celui d'un `workspace-*`,
  de `.agents/`, `evaluator/` ou `.git/`.
- `TASK.md`, `AGENTS.md`, `AUTOMATION_SPEC.md`, `PROCESS_AUTOMATION.md`,
  `USE_CASE.md` et les skills locaux : chemins de données préfixés par
  `workspace-<slug>/`.
- `verify.sh` : réécrit pour les tests structurels du monorepo (§30-33 de la
  spec) ; 108 assertions.
- `harness-check/pi-skills.mjs` : affiche les skills hérités des niveaux
  supérieurs (chemins relatifs à la racine du monorepo).
- `publish-github.ps1` : publie `paul` puis les repos `workspace-*` imbriqués
  découverts sur disque (toujours privés).
- `analyse-candidature/SKILL.md` : frontmatter `name` / `description` ajouté —
  il était absent, le skill n'était donc chargeable par aucun harness.

## 4. Anciens repos archivés

Les dix anciens repos ont été **déplacés**, avec leur `.git` intact, vers :

```text
G:\DEV\paul-legacy\
├── agent-authoring\   agent-common\   agent-contract-management\
├── agent-finance\     agent-recrutement\   agent-rh\
├── automation-candidature\   automation-create-use-case\   automation-obligations\
└── workspace-create-use-case\
```

Rien n'a été supprimé et rien n'a été poussé. `agent-recrutement`, `agent-rh` et
`automation-candidature` n'avaient **aucun remote** : cette archive est leur
seule copie. Les autres existent encore sous `github.com/paul-agent/`.

Après validation, ces dépôts GitHub peuvent être archivés (pas supprimés) ;
`workspace-obligations` et `workspace-candidature` restent actifs.

## 5. Workspaces

Les deux workspaces conservent leur `.git`, leur historique et leur remote. Un
commit y a retiré `.agents/skills/_deps/`, `.gitmodules`, `.pi/settings.json`
et `TASK.md`, et réécrit leur `README.md`. Rien n'a été poussé.

Les deux PDF déposés dans `workspace-candidature/input/` (CV et offre)
restent **non suivis**, comme avant la migration.

## 6. Vérification

```bash
bash verify.sh        # 108 assertions : structure, workspaces, skills, scaffold, sondes Pi/Hermes
```

Découverte des skills depuis `finance/contract-management/obligations` :

| Harness | Résultat |
|---|---|
| Pi | les 5 skills communs + `contract-obligation-extraction` + `obligation-register-duckdb`, chacun une seule fois, aucun diagnostic |
| Hermes | les 5 skills communs uniquement |

Hermes ne parcourt que `<racine Git>/.agents/skills` : les niveaux métier
intermédiaires et les skills locaux ne lui sont pas visibles. Limite du
harness, consignée dans `ARCHITECTURE.md` §6 et traitée séparément —
aucun `SKILL.md` n'est dupliqué pour la contourner.
