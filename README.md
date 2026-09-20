# PAUL — Personal Assistant for Universal Labor

PAUL est un **espace de travail pour automatiser des processus métier avec des
agents**. On y décrit un processus une seule fois, en fichiers texte, et on
l'exécute avec le harness agentique de son choix — Pi, Hermes, OpenCode,
Claude Code… — sans rien réécrire.

Un processus automatisé s'appelle ici un **cas d'usage**. C'est un simple
dossier :

```text
finance/contract-management/obligations/
├── TASK.md                    # la mission : quoi lire, quoi produire, quand s'arrêter
├── AGENTS.md                  # les règles durables de l'agent (facultatif)
├── AUTOMATION_SPEC.md         # la spécification détaillée (facultatif)
├── .agents/skills/            # les savoir-faire propres à ce cas d'usage
└── workspace-obligations/     # les données : repo Git séparé, imbriqué ici
```

Rien d'autre n'est requis. Un cas d'usage léger peut se réduire à un `TASK.md`
et un dossier de données.

## Les trois idées

**1. Le métier est la hiérarchie.** Les domaines et sous-domaines sont des
dossiers ordinaires. `finance/contract-management/obligations` se lit comme une
organisation, pas comme une arborescence technique. Aucun niveau n'est
obligatoire : un cas d'usage peut vivre directement sous `finance/`, ou à la
racine.

**2. Les savoir-faire s'héritent par la position.** Un *skill* est un fichier
`SKILL.md` placé au niveau où il est réutilisable. Un cas d'usage voit
automatiquement les skills de toute sa chaîne de dossiers :

```text
paul/.agents/skills              lire un PDF, interroger du DuckDB, créer un cas d'usage…
        ↓
finance/.agents/skills           ce qui sert à toute la Finance
        ↓
…/contract-management/.agents/   extraire les obligations d'un contrat
        ↓
…/obligations/.agents/skills     le registre DuckDB propre à ce cas d'usage
```

Pas de dépendances à déclarer, pas de submodules, pas de copies : déplacer un
skill d'un niveau à l'autre, c'est un `git mv`. Et `obligations` ne voit rien
des skills de `rh/recrutement` — chaque branche reste cloisonnée.

**3. La logique et les données sont séparées.** Ce dépôt ne contient que de la
logique agentique : il se partage largement. Les contrats, CV, bases et
résultats vivent dans un repo Git **indépendant** `workspace-<slug>/`, imbriqué
sous son cas d'usage et ignoré ici. Ses droits d'accès lui sont propres : on
peut maintenir un processus sans accéder à ses données.

## Lancer un cas d'usage

Depuis le dossier du cas d'usage :

```bash
cd finance/contract-management/obligations
pi                     # ou hermes, opencode…
```

Puis `go` comme première instruction, ou `exécute TASK.md`. Le skill commun
`start-use-case` résout le point d'entrée et suit la mission ; les chemins de
`TASK.md` sont relatifs au dossier (`workspace-obligations/contract/`…).

## Créer un cas d'usage

Depuis le dossier métier qui doit l'accueillir :

```bash
cd finance/contract-management
pi
# « crée un use case contract-review »   ->   ./contract-review/
```

Le skill commun `create-use-case` mène l'entretien (avec `grill-me`), évalue ce
qui est réellement connu, choisit l'architecture **minimale** et ne génère que
ce qui sert — pas de skill vide, pas de workspace vide, pas de README de
façade. « génère maintenant » arrête les questions et produit ce qui est
justifiable sans rien inventer ; « crée juste l'arborescence » se limite au
squelette.

## Portabilité des harnesses

La hiérarchie canonique est celle du filesystem, et un skill n'existe qu'une
fois sur disque.

| Harness | Découverte des skills | À faire |
|---|---|---|
| **Pi** | remonte de `cwd` jusqu'à la racine du dépôt en collectant chaque `.agents/skills` | rien |
| **Hermes** | ne scanne que la racine du dépôt (`.agents/skills`, `.hermes/skills`) | générer l'adaptateur ci-dessous, puis `hermes skills trust` |

```bash
python .agents/skills/create-use-case/scripts/scaffold.py \
       hermes-adapter --path finance/contract-management/obligations
```

L'adaptateur crée des **liens de répertoire** vers les niveaux métier de la
branche, dans `/.hermes/` (gitignoré). Aucun `SKILL.md` n'est copié. À
régénérer si un niveau métier gagne des skills. Voir
[ARCHITECTURE.md](ARCHITECTURE.md) §6.

## Cas d'usage existants

| Cas d'usage | Emplacement | Ce qu'il fait |
|---|---|---|
| `obligations` | `finance/contract-management/` | construit un registre traçable des obligations d'un corpus contractuel, avec échéances, conflits et ambiguïtés |
| `candidature` | `rh/recrutement/` | analyse l'adéquation de CV à une offre d'emploi, preuve à l'appui, sans jamais décider à la place du recruteur |

Leurs workspaces sont des dépôts distincts : les cloner est un geste séparé, et
peut demander des droits que ce dépôt n'accorde pas.

```bash
git clone https://github.com/<org>/paul.git
cd paul/finance/contract-management/obligations
git clone https://github.com/<org>/workspace-obligations.git   # si autorisé
```

Sous Windows : `git config --global core.longpaths true`.

## Outillage

| Fichier | Rôle |
|---|---|
| `ARCHITECTURE.md` | hiérarchie métier, cas d'usage, skills, workspaces, harnesses — la référence |
| `verify.sh` | vérification structurelle du dépôt (`bash verify.sh`) |
| `harness-check/` | sondes de découverte des skills Pi / Hermes, utilisées par `verify.sh` |
| `tests/` | scénarios fonctionnels de `create-use-case` et `start-use-case` |
| `publish-github.ps1` | crée et pousse `paul` puis les workspaces imbriqués |
