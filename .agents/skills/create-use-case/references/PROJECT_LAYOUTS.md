# Project layouts — monorepo `paul`

## Principes

- Un seul repo Git principal, `paul`, pour toute la logique agentique.
- La hiérarchie métier est exprimée **par les dossiers**. Les niveaux
  domaine/sous-domaine sont facultatifs : ne pas forcer une profondeur
  uniforme.
- Un cas d'usage est un dossier portant son **nom fonctionnel**
  (`obligations`, pas `automation-obligations`).
- Un seul modèle de cas d'usage : aucune distinction structurelle entre
  « tâche simple » et « automatisation ». Ne créer que ce qui sert.
- Héritage **structurel** des skills : un cas d'usage voit les `.agents/skills`
  de toute sa chaîne de dossiers. Aucun `_deps`, aucun submodule agentique,
  aucune copie de `SKILL.md`, aucun niveau `authoring/`.
- Les données persistantes vivent dans un repo Git **indépendant**
  `workspace-<slug>` imbriqué sous le cas d'usage.
- **Pas de README** dans les niveaux métier intermédiaires ni dans les cas
  d'usage. Seul `paul/README.md` existe par défaut.

## Arborescence de référence

```text
paul/
├── .git/
├── .gitignore                            # **/*workspace*  +  /.create-use-case/
├── README.md
├── .create-use-case/                     # temporaire, gitignored
│
├── .agents/
│   └── skills/                           # skills communs
│       ├── create-use-case/
│       ├── grill-me/
│       ├── start-use-case/
│       ├── structured-data-duckdb/
│       └── document-processing/
│
└── finance/                              # domaine (facultatif)
    ├── .agents/skills/                   # skills Finance, seulement s'il en existe
    └── contract-management/              # sous-domaine (facultatif)
        ├── .agents/skills/
        │   └── contract-obligation-extraction/SKILL.md
        └── obligations/                  # cas d'usage
            ├── TASK.md
            ├── AGENTS.md                 # si utile
            ├── AUTOMATION_SPEC.md        # si utile
            ├── PROCESS_AUTOMATION.md     # si utile
            ├── .agents/skills/
            │   └── obligation-register-duckdb/SKILL.md
            ├── scripts/                  # si utile
            ├── .pi/settings.json         # généré
            └── workspace-obligations/    # repo Git indépendant
                └── .git/
```

Chemins valides, à profondeurs différentes :

```text
paul/finance/contract-management/obligations/
paul/finance/monthly-close/
paul/customer-service/ticket-triage/
```

## Cas d'usage minimal

```text
contract-summary/
├── TASK.md
└── workspace-contract-summary/
    └── .git/
```

La présence ou l'absence de `.agents/skills` ne change pas le type
d'architecture.

## Placement des skills

| Portée | Emplacement |
|---|---|
| spécifique à un cas d'usage | `<use-case>/.agents/skills/<skill>/SKILL.md` |
| réutilisable dans un sous-domaine | `<domaine>/<sous-domaine>/.agents/skills/` |
| réutilisable dans un domaine | `<domaine>/.agents/skills/` |
| réutilisable partout | `paul/.agents/skills/` |

Ordre de recherche avant de créer un skill : cas d'usage → parents métier →
communs → outils du harness. Un nouveau skill commence `LOCAL` ; la promotion
est un `git mv` manuel, jamais automatique.

Ne pas créer un `.agents/skills/` vide ni un README pour « tenir » un niveau
métier : un dossier métier sans skill est simplement un dossier.

## Workspace

```text
workspace-<slug>/
├── .git/            # son propre repo, son propre remote
├── input/           # ou contract/, documents/…
├── data/
├── output/
├── state/
├── .tmp/
├── test-data/
└── evaluator/       # jamais une entrée de l'agent métier
```

Tous ces dossiers sont optionnels. Le repo **est** le workspace : jamais de
sous-dossier `workspace-<slug>/workspace/`. Pas de `TASK.md` dans le
workspace : le point d'entrée est celui du cas d'usage.

Le monorepo ignore les workspaces via `**/*workspace*` ; pas de `.gitkeep`
comme mécanisme de séparation Git. Les commits du workspace ne modifient pas
l'index de `paul`, et inversement.

## Point de lancement

Le harness se lance depuis le **dossier du cas d'usage** :

```bash
cd paul/finance/contract-management/obligations
pi        # ou hermes, opencode…
```

Le `.git` du workspace est *en dessous* de ce répertoire : il ne perturbe pas
la recherche ascendante de la racine de projet.

`TASK.md` référence le workspace par chemins relatifs
(`workspace-obligations/input/`…), sans chemin absolu ni variable
d'environnement.

## Fichiers temporaires

`workspace-<slug>/.tmp/` ; jamais `/tmp` ni `%TEMP%`.

## Harnesses

| Harness | Découverte depuis le dossier du cas d'usage |
|---|---|
| Pi | `<cwd>/.agents/skills` automatiquement ; les niveaux métier au-dessus sont listés dans `<use-case>/.pi/settings.json` (généré par `scaffold.py`, aucune copie) |
| Hermes | `<racine Git>/.agents/skills/**`, soit les skills **communs** de `paul` ; les niveaux intermédiaires et locaux ne sont pas vus — limite connue, traitée séparément, jamais contournée en dupliquant un `SKILL.md` |
