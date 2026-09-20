# PAUL — Personal Assistant for Universal Labor

Monorepo de PAUL : toute la logique agentique — skills communs, skills métier
et cas d'usage — dans un seul repo Git. La hiérarchie métier est exprimée
directement par les dossiers.

```text
paul/
├── .agents/skills/                       # skills communs
├── finance/contract-management/
│   ├── .agents/skills/                   # skills du sous-domaine
│   └── obligations/                      # cas d'usage
│       ├── TASK.md
│       └── workspace-obligations/        # repo Git indépendant (données)
└── rh/recrutement/
    └── candidature/                      # cas d'usage
        ├── TASK.md
        └── workspace-candidature/        # repo Git indépendant (données)
```

Voir [ARCHITECTURE.md](ARCHITECTURE.md) pour le détail.

## Lancer un cas d'usage

Depuis le dossier du cas d'usage :

```bash
cd finance/contract-management/obligations
pi                     # ou hermes, opencode…
```

Puis `go` comme première instruction, ou `exécute TASK.md`. Le point d'entrée
est le `TASK.md` du dossier ; les données vivent dans le repo imbriqué
`workspace-<slug>/`.

Pi hérite tout seul des skills des niveaux métier supérieurs. Hermes ne scanne
que la racine du dépôt : lui exposer les niveaux métier demande une fois

```bash
python .agents/skills/create-use-case/scripts/scaffold.py \
       hermes-adapter --path finance/contract-management/obligations
hermes skills trust
```

(liens de répertoire gitignorés, aucune copie de skill — voir
[ARCHITECTURE.md](ARCHITECTURE.md) §6).

## Créer un cas d'usage

Depuis le dossier métier qui doit l'accueillir :

```bash
cd finance/contract-management
pi
# « crée un use case contract-review »   ->   ./contract-review/
```

Le skill commun `create-use-case` mène la discovery (avec `grill-me`), choisit
l'architecture minimale et génère le cas d'usage. « génère maintenant » arrête
les questions ; « crée juste l'arborescence » se limite au scaffold.

## Workspaces

Les données métier d'un cas d'usage vivent dans un repo Git **indépendant**
`workspace-<slug>/`, imbriqué sous le cas d'usage et ignoré par ce repo
(`**/*workspace*`). Ses droits peuvent être plus restrictifs.

```bash
git clone https://github.com/<org>/paul.git
cd paul/finance/contract-management/obligations
git clone https://github.com/<org>/workspace-obligations.git   # si autorisé
```

Sous Windows : `git config --global core.longpaths true`.

## Outillage

| Fichier | Rôle |
|---|---|
| `ARCHITECTURE.md` | hiérarchie métier, cas d'usage, skills, workspaces — référence |
| `verify.sh` | tests structurels du monorepo (`bash verify.sh`) |
| `harness-check/` | sondes de découverte des skills Pi / Hermes, utilisées par `verify.sh` |
| `tests/` | scénarios fonctionnels de `create-use-case` et `start-use-case` |
| `publish-github.ps1` | crée et pousse `paul` et les workspaces |
| `docs/MIGRATION_MONOREPO.md` | retour au monorepo : mapping, suppressions, archive des anciens repos |
| `docs/spec-refactoring-paul-v1.4.md` | spécification appliquée |
| `docs/legacy/` | rapports des migrations précédentes |
