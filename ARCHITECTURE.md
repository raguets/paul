# PAUL — Architecture

**PAUL — Personal Assistant for Universal Labor.**

Document de référence de l'organisation du monorepo `paul` : hiérarchie
métier, cas d'usage, skills, workspaces.

## 1. Un seul repo pour la logique agentique

`paul` contient **toute** la logique agentique : skills communs, skills
métier, cas d'usage. Il n'y a plus de chaîne de repos `agent-*` /
`automation-*`, plus de submodule d'héritage et plus de `_deps`.

```text
paul/
├── .git/
├── .gitignore                            # **/*workspace* · /.create-use-case/ · /.hermes/
├── README.md                             # le seul README par défaut
├── ARCHITECTURE.md
├── verify.sh                             # tests structurels
├── harness-check/                        # sondes Pi / Hermes
├── tests/                                # scénarios fonctionnels
├── .create-use-case/                     # temporaire, gitignored
├── .hermes/skills/                       # adaptateur Hermes généré, gitignored
│
├── .agents/
│   └── skills/                           # skills communs
│       ├── create-use-case/
│       ├── grill-me/
│       ├── start-use-case/
│       ├── structured-data-duckdb/
│       └── document-processing/
│
├── finance/
│   └── contract-management/
│       ├── .agents/skills/
│       │   └── contract-obligation-extraction/
│       └── obligations/                  # cas d'usage
│           ├── TASK.md
│           ├── AGENTS.md
│           ├── AUTOMATION_SPEC.md
│           ├── PROCESS_AUTOMATION.md
│           ├── .agents/skills/obligation-register-duckdb/
│           └── workspace-obligations/    # repo Git indépendant
│
└── rh/
    └── recrutement/
        └── candidature/                  # cas d'usage
            ├── TASK.md
            ├── USE_CASE.md
            ├── AUTOMATION_SPEC.md
            ├── .agents/skills/analyse-candidature/
            └── workspace-candidature/    # repo Git indépendant
```

## 2. Hiérarchie métier = dossiers

Les domaines et sous-domaines sont de simples dossiers. Ils sont
**facultatifs** : un cas d'usage peut vivre à n'importe quelle profondeur.

```text
paul/finance/contract-management/obligations/
paul/rh/recrutement/candidature/
paul/finance/monthly-close/
paul/customer-service/ticket-triage/
```

Un dossier métier sans skill est simplement un dossier : pas de README, pas de
`.agents/skills/` vide pour « tenir » le niveau.

## 3. Cas d'usage

Un cas d'usage porte son **nom fonctionnel** (`obligations`, jamais
`automation-obligations`). Il n'existe plus deux architectures distinctes
« tâche simple » et « automatisation » : un seul modèle, dont on ne crée que ce
qui sert.

| Élément | Quand |
|---|---|
| `TASK.md` | toujours — point d'entrée canonique |
| spécifications (`AUTOMATION_SPEC.md`, `USE_CASE.md`, `PROCESS_AUTOMATION.md`, `AGENTS.md`) | si utiles |
| `.agents/skills/` | seulement si un skill spécifique est nécessaire |
| `scripts/` | seulement si des scripts propres sont nécessaires |
| `workspace-<slug>/` | seulement si des données persistent |

Cas d'usage actuels :

| Cas d'usage | Emplacement | Skill local | Workspace |
|---|---|---|---|
| `obligations` | `finance/contract-management/` | `obligation-register-duckdb` | `workspace-obligations` |
| `candidature` | `rh/recrutement/` | `analyse-candidature` | `workspace-candidature` |

## 4. Skills — héritage structurel

La source canonique reste `.agents/skills/<skill>/SKILL.md`. Un cas d'usage
voit les `.agents/skills` de toute sa chaîne de dossiers :

```text
paul/.agents/skills
        ↓
finance/.agents/skills
        ↓
finance/contract-management/.agents/skills
        ↓
finance/contract-management/obligations/.agents/skills
```

Aucun `_deps`, aucun submodule, aucune copie de `SKILL.md`, y compris pour
satisfaire un harness.

Un skill est placé au niveau où il est réutilisable. Un nouveau skill commence
`LOCAL` dans le cas d'usage ; sa promotion vers un niveau supérieur est
manuelle et se réduit à un `git mv`.

## 5. Workspaces métier

Les données, documents et résultats persistants d'un cas d'usage vivent dans un
repo Git **indépendant** imbriqué sous le cas d'usage :

```text
paul/finance/contract-management/obligations/workspace-obligations/.git/
```

- nom obligatoire `workspace-<slug>` ; le repo **est** le workspace (jamais de
  sous-dossier `workspace/`) ;
- son `.git` et son remote lui appartiennent, distincts de ceux de `paul` ;
- `paul/.gitignore` contient `**/*workspace*` : le monorepo n'indexe jamais
  leur contenu, sans `.gitkeep` ni autre artifice ;
- les commits du workspace ne modifient pas l'index de `paul`, et inversement ;
- contenu au besoin seulement : `input/`, `contract/`, `data/`, `documents/`,
  `output/`, `state/`, `.tmp/`, `test-data/`, `evaluator/`.

Les droits peuvent être plus restrictifs que ceux de `paul` : un workspace
contient des documents métier, des données et parfois un ground truth, alors
que `paul` ne contient que de la logique agentique.

## 6. Lancement et harnesses

Le harness se lance depuis le **dossier du cas d'usage** :

```bash
cd paul/finance/contract-management/obligations
pi        # ou hermes, opencode…
```

Le `.git` du workspace est *en dessous* de ce répertoire : il ne perturbe pas
la recherche ascendante de la racine de projet.

| Harness | Découverte native | Adaptateur |
|---|---|---|
| Pi | remonte de `cwd` jusqu'à la racine Git en collectant `<niveau>/.agents/skills` (`collectAncestorAgentsSkillDirs`) | **aucun** — l'héritage structurel est natif, y compris le cloisonnement entre branches |
| Hermes | `<racine Git>/.agents/skills/**` et `<racine Git>/.hermes/skills/**` uniquement : seuls les skills **communs** | `scaffold.py hermes-adapter --path <use-case>` |

L'adaptateur Hermes construit `paul/.hermes/skills/` avec un **lien de
répertoire** (jonction Windows, symlink POSIX) par niveau métier de la branche
visée :

```bash
python .agents/skills/create-use-case/scripts/scaffold.py \
       hermes-adapter --path finance/contract-management/obligations
hermes skills trust      # au premier usage, à la racine de paul
```

```text
paul/.hermes/skills/
├── finance-contract-management             -> finance/contract-management/.agents/skills
└── finance-contract-management-obligations -> finance/contract-management/obligations/.agents/skills
```

Aucun `SKILL.md` n'est copié : il n'existe qu'un seul fichier sur disque, et
`git status` ne voit rien (le dossier est gitignored). `--all` lie toutes les
branches d'un coup, au prix du cloisonnement métier ; `--clear` le vide. Le
choix par défaut est la branche, pour reproduire exactement ce que Pi voit.

Une alternative existe sans lien : `skills.external_dirs` dans le `config.yaml`
de Hermes accepte des répertoires de skills supplémentaires. Elle est
volontairement écartée ici : la configuration est globale au profil, donc les
skills métier de `paul` seraient exposés dans **toutes** les sessions Hermes,
y compris hors du dépôt.

## 7. `create-use-case`

`create-use-case` est un **skill commun**
(`paul/.agents/skills/create-use-case/`) : ni repo Git séparé, ni workspace
propre, ni domaine `authoring/`. Il est disponible partout dans `paul`.

Convention d'usage : lancer le harness depuis le dossier parent voulu.

```bash
cd paul/finance/contract-management
# « crée un use case obligations »   ->   ./obligations/
```

Son état de travail est temporaire et vit uniquement dans
`paul/.create-use-case/<slug>/` (gitignored). Il n'est jamais copié dans le cas
d'usage généré et il est supprimé après une génération réussie.

`process-automation-bootstrap` n'est pas réintroduit.

## 8. Publication Git

| Repo | Contenu | Visibilité typique |
|---|---|---|
| `paul` | toute la logique agentique, aucun document métier | large |
| `workspace-<slug>` | contrats, CV, données, sorties, ground truth | **privé**, équipe dédiée |

Voir `publish-github.ps1`.

## 9. Windows

`git config --global core.longpaths true` reste recommandé. Avec le modèle
monorepo, les chemins restent courts : il n'y a plus de `.git/modules`
imbriqués.
