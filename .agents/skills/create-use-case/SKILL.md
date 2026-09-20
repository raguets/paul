---
name: create-use-case
description: Transforme une description plus ou moins complète de cas d'usage (USE_CASE.md, PROCESS_AUTOMATION.md, notes, documents, conversation) en cas d'usage exploitable dans le monorepo `paul` - un dossier portant son nom fonctionnel sous un dossier métier, avec TASK.md, les skills spécifiques réellement nécessaires et, si des données persistent, un repo Git indépendant workspace-<slug> imbriqué. Évalue la readiness R1-R10, conduit la discovery avec le skill grill-me, choisit l'architecture minimale, appelle scripts/scaffold.py puis génère TASK, spécifications et skills justifiés. Guidant par défaut, jamais bloquant - supporte "génère maintenant" et "crée juste l'arborescence". Remplace process-automation-bootstrap.
---

# Create Use Case

## 0. Mission

Transformer un besoin, éventuellement incomplet, en un cas d'usage minimal,
traçable, reprenable et documenté, directement dans le monorepo `paul`.

Ce skill est à la fois : guide de discovery, contrôleur de readiness,
concepteur d'architecture minimale, générateur de structure, générateur
éventuel de skills, et scaffolder direct pour un utilisateur expérimenté.

Il **absorbe et remplace** `process-automation-bootstrap` (V3). Il n'y a
qu'un seul système : ne jamais déléguer à l'ancien bootstrap.

Règle impérative :

```text
User intent overrides readiness gating.
```

La readiness est un conseil de qualité, pas une interdiction. Si l'utilisateur
ordonne la génération, générer ce qui peut l'être **sans inventer**. Ne jamais
répondre « il me manque R5 et R8, je ne peux pas ».

Documents de référence (lire au besoin, chemins relatifs à ce skill) :

| Fichier | Contenu |
|---|---|
| `references/READINESS_MODEL.md` | R1-R10, statuts, Definition of Ready, format de `READINESS.md` |
| `references/PROJECT_LAYOUTS.md` | arborescence d'un cas d'usage, placement des skills, workspaces, harnesses |
| `references/SOURCE_LIFECYCLE.md` | gestion des sources qui évoluent entre deux runs |
| `scripts/scaffold.py` | matérialise les décisions (dossier, TASK.md, skills, workspace, adaptateur Hermes) |
| `templates/` | `TASK.md`, `USE_CASE.md`, état `state/` |

---

## 1. Contexte d'exécution

Le monorepo `paul` contient toute la logique agentique. La hiérarchie métier
est exprimée par de simples dossiers ; un cas d'usage est un dossier portant
son **nom fonctionnel** :

```text
paul/
├── .agents/skills/                    # skills communs (dont ce skill)
└── finance/
    └── contract-management/
        ├── .agents/skills/            # skills du sous-domaine
        └── obligations/               # cas d'usage
```

Ce skill est disponible partout dans `paul`. Il n'a ni repo propre, ni
workspace, ni dossier `authoring/`.

`PAUL_ROOT` = racine du monorepo (le premier ancêtre contenant `.git` au-dessus
du répertoire courant ; le `.git` d'un workspace est toujours *en dessous* d'un
cas d'usage, jamais au-dessus).

### Où créer le cas d'usage

**Convention principale : le répertoire courant est le dossier parent.**
L'utilisateur lance le harness depuis le dossier métier voulu :

```bash
cd paul/finance/contract-management
# « crée un use case obligations »   ->   ./obligations/
```

Si l'utilisateur indique explicitement la destination (« crée le use case
obligations sous finance/contract-management »), utiliser ce chemin, résolu
depuis `PAUL_ROOT`.

Ne jamais déduire un dossier parent « le plus profond possible » : un cas
d'usage peut être rattaché à n'importe quel niveau, y compris directement à
`PAUL_ROOT` ou à un domaine qui a des sous-domaines. Les niveaux
domaine/sous-domaine sont facultatifs ; ne pas forcer une profondeur uniforme.
Si le dossier métier voulu n'existe pas encore, le créer (un simple dossier,
sans README ni skill vide).

---

## 2. État interne et reprise

L'état de travail de `create-use-case` est **interne, temporaire et unique** :

```text
PAUL_ROOT/.create-use-case/<slug>/
├── READINESS.md             # vue canonique : champs d'état + R1-R10
├── ASSUMPTIONS.md           # hypothèses qui ne sont pas des décisions humaines
├── OPEN_QUESTIONS.md        # lacunes ouvertes (réf. R*), TODO différés
├── PROMOTION_CANDIDATES.md  # LOCAL / *_CANDIDATE, destinations proposées
├── GENERATED.md             # obligatoire après toute génération
└── interview.md             # capture grill-me, si utilisée
```

Ce dossier est gitignored (`/.create-use-case/` dans `paul/.gitignore`).

Règles absolues :

- ne **jamais** créer `<use-case>/.create-use-case/` ;
- ne **jamais** recopier cet état dans le cas d'usage généré ;
- **supprimer** `PAUL_ROOT/.create-use-case/<slug>/` après une génération
  réussie (§9, dernière étape) ;
- aucun de ces fichiers ne doit être nécessaire pour exécuter le cas d'usage.

### Reprise après interruption — à faire en premier

1. lister `PAUL_ROOT/.create-use-case/` ; s'il contient un slug en cours, lire
   son `READINESS.md` ;
2. inspecter `CREATE_PHASE` ;
3. reprendre à `NEXT_ACTION` ;
4. ne jamais régénérer ce qui est déjà terminé (voir `GENERATED.md`).

| `CREATE_PHASE` | Action |
|---|---|
| `ASSESSMENT` | continuer l'évaluation R1-R10 |
| `INTERVIEW` | relire `interview.md` ; si des questions restent ouvertes, reprendre l'entretien **sans reposer les questions déjà répondues** ; sinon réévaluer R1-R10 |
| `GENERATION` | reprendre la génération à partir de `NEXT_ACTION` et de `GENERATED.md` |
| `VALIDATION` | reprendre les vérifications finales (§12) |
| `COMPLETE` | état résiduel d'une session non nettoyée : vérifier le cas d'usage puis supprimer le dossier d'état |

Si l'utilisateur décrit un **nouveau** cas d'usage alors qu'une session
précédente est encore présente et non terminée, demander s'il faut la
reprendre ou l'abandonner (supprimer son dossier).

### Champs de `READINESS.md`

```text
CREATE_PHASE: ASSESSMENT | INTERVIEW | GENERATION | VALIDATION | COMPLETE
GENERATION_MODE: DISCOVERY | COMPLETE | GENERATE_NOW | SCAFFOLD_ONLY
RESUME_AFTER_INTERVIEW: true | false
NEXT_ACTION: <texte>
USE_CASE_READY: YES | NO
GENERATION_FORCED: true | false
USE_CASE_NAME: <slug>
USE_CASE_PATH: <chemin du cas d'usage, relatif à PAUL_ROOT>
WORKSPACE_NEEDED: YES | NO | UNKNOWN
```

Puis le tableau R1-R10 (`references/READINESS_MODEL.md`).

Mettre à jour `READINESS.md` à chaque changement de phase, **avant** l'action
correspondante.

### Garde-fou de reprise après entretien

Si `CREATE_PHASE: INTERVIEW` et `RESUME_AFTER_INTERVIEW: true` alors que
`grill-me` n'attend plus de réponse, reprendre immédiatement. Si la reprise
n'a pas eu lieu (nouvelle conversation, harness qui s'arrête), afficher :

```text
L'entretien est terminé mais create-use-case n'a pas encore repris.
Demande : « Poursuis create-use-case. »
Je relirai .create-use-case/<slug>/READINESS.md et reprendrai à NEXT_ACTION.
```

Ne pas afficher ce message tant qu'une question attend une réponse.

---

## 3. Entrées

Partir de n'importe quelle combinaison de :

```text
USE_CASE.md · PROCESS_AUTOMATION.md · documents existants · notes utilisateur ·
fichiers métier · dossier déjà partiellement construit · conversation courante ·
capture Grill Me existante · état .create-use-case/<slug>/
```

Lire intégralement `USE_CASE.md` / `PROCESS_AUTOMATION.md` s'ils existent
(`templates/USE_CASE.md` est le canevas proposé à l'utilisateur).

Ne **jamais** redemander une information déjà clairement présente dans ces
sources. Ne pas inventer le fonctionnement métier à partir de connaissances
externes.

---

## 4. Modes de génération

Détecter le mode depuis l'instruction de l'utilisateur, à tout moment.

### `DISCOVERY` (défaut)

1. inspecter l'existant ;
2. évaluer R1-R10 ;
3. identifier les gaps **réellement bloquants** ;
4. utiliser `grill-me` pour les résoudre (§5) ;
5. réévaluer ;
6. continuer jusqu'à readiness suffisante ou ordre contraire.

Si R1-R10 sont déjà `CONFIRMED` ou `N/A` : **ne pas lancer grill-me** ;
passer directement en `COMPLETE`.

### `COMPLETE`

Tous les critères nécessaires sont `CONFIRMED` ou `N/A` (Definition of Ready,
`references/READINESS_MODEL.md`). Générer l'architecture minimale complète.
Ne pas demander une seconde confirmation si l'utilisateur a déjà demandé de
générer dès que prêt.

### `GENERATE_NOW`

Déclencheurs typiques : « génère maintenant », « arrête les questions »,
« fais avec ce qu'on a », « crée le projet avec ce que tu sais »,
« on complétera plus tard », « je préfère écrire les skills moi-même ». Alors :

1. arrêter immédiatement l'interrogatoire (y compris au milieu de grill-me) ;
2. ne pas exiger la Definition of Ready ;
3. passer à `TODO` les gaps **volontairement différés** (ne jamais convertir
   automatiquement `UNKNOWN` en `TODO` hors de ce cas) ;
4. générer uniquement ce qui est justifié par les informations connues ;
5. ne jamais inventer la logique métier manquante ; omettre les skills dont
   l'objectif reste flou ; n'ajouter des `TODO` que lorsqu'ils portent une
   information utile ;
6. enregistrer les éléments non résolus dans `OPEN_QUESTIONS.md` ;
7. `GENERATION_FORCED: true` et indiquer dans `GENERATED.md` que la
   génération a été forcée.

### `SCAFFOLD_ONLY`

Déclencheurs typiques : « crée juste l'arborescence », « pas de skill local »,
« je remplirai les fichiers moi-même ». Alors :

- ne poser aucune question qui n'est pas indispensable au scaffold (nom,
  dossier parent, besoin d'un workspace si ambigus) ;
- créer uniquement la structure demandée ;
- ne concevoir aucune logique métier non demandée ;
- ne créer aucun skill (sauf placeholders explicitement demandés).

---

## 5. Discovery avec `grill-me`

Raisonner en capacité, pas en commande :

```text
Use the grill-me skill to resolve the remaining blocking readiness gaps.
```

Aucune commande `/grill-me` ni extension de harness n'est requise.

Protocole :

1. remplir R1-R10 avec l'existant ;
2. choisir uniquement les gaps à clarifier, classés par impact ;
3. écrire dans `READINESS.md` :
   ```text
   CREATE_PHASE: INTERVIEW
   RESUME_AFTER_INTERVIEW: true
   NEXT_ACTION: REASSESS_READINESS_AND_GENERATE
   USE_CASE_READY: NO
   ```
4. appliquer le skill `grill-me` en mode appelé, avec :
   - capture : `PAUL_ROOT/.create-use-case/<slug>/interview.md` ;
   - liste des gaps (ids R*) et ce qui est déjà établi ;
5. grill-me pose **une question à la fois**, avec une recommandation, et
   persiste chaque réponse avant la suivante ;
6. dès que les gaps sont résolus, reprendre **dans le même tour** : relire
   `READINESS.md`, réévaluer R1-R10, poursuivre. La fin de l'entretien n'est
   pas la fin de la mission ; ne pas attendre « continue ».

Si l'utilisateur dit « génère maintenant » pendant l'entretien : arrêter,
sauvegarder la capture (questions restantes `DEFERRED`), revenir ici et
passer en `GENERATE_NOW`.

Le dossier parent (§1) et le besoin d'un workspace (§7) peuvent faire partie
des gaps.

---

## 6. Nommage

`USE_CASE_NAME` est un slug kebab-case **court et fonctionnel**, sans préfixe
et sans les noms des parents :

```text
obligations          contract-review          monthly-close
supplier-onboarding  ticket-triage
```

Jamais `automation-obligations`, `agent-obligations`,
`finance-contract-management-obligations`. Le rattachement métier est porté par
l'emplacement du dossier, pas par le nom : déplacer un cas d'usage dans une
autre branche ne le renomme pas.

Vérifier que le dossier n'existe pas déjà dans le parent choisi.

---

## 7. Architecture minimale d'un cas d'usage

Il n'existe **plus** deux architectures distinctes « tâche simple » et
« automatisation ». Un seul modèle, dont on ne crée que ce qui sert :

```text
<use-case>/
├── TASK.md                      # toujours : point d'entrée canonique
├── <spécifications utiles>      # AUTOMATION_SPEC.md, USE_CASE.md, AGENTS.md… si utiles
├── .agents/skills/              # seulement si un skill spécifique est nécessaire
│   └── <skill>/SKILL.md
├── scripts/                     # seulement si des scripts propres sont nécessaires
└── workspace-<slug>/            # seulement si des données persistent (repo Git indépendant)
```

Une tâche simple est donc :

```text
contract-summary/
├── TASK.md
└── workspace-contract-summary/
```

La présence ou l'absence de `.agents/skills` ne change pas le type
d'architecture. **Pas de README** dans le cas d'usage ni dans les niveaux
métier intermédiaires : la documentation opérationnelle est portée par
`TASK.md` et, si nécessaire, de vraies spécifications.

### Placement des skills — réutilisation avant création

Avant de créer un skill, vérifier dans cet ordre :

1. les skills du cas d'usage lui-même ;
2. les skills des dossiers métier parents (`<domaine>/.agents/skills`,
   `<sous-domaine>/.agents/skills`) ;
3. les skills communs (`PAUL_ROOT/.agents/skills`) ;
4. les outils déjà exposés par le harness courant.

L'héritage est **structurel** : un cas d'usage voit les `.agents/skills` de
toute sa chaîne de dossiers. Il n'y a ni `_deps`, ni submodule, ni copie de
`SKILL.md`.

Un nouveau skill commence toujours `LOCAL`, dans le cas d'usage. Ne jamais
écrire directement dans les `.agents/skills` d'un niveau parent sans accord
explicite : proposer la promotion (§10).

Ne créer ni skill, ni script, ni workspace vide juste pour satisfaire un
template.

### Agents

Préférer :

```text
1 agent principal + skills existants + quelques skills locaux + outils runtime
+ stockage persistant si nécessaire
```

L'agent principal est défini par le `TASK.md` du cas d'usage. Des règles
durables peuvent vivre dans un `AGENTS.md` du cas d'usage, référencé
explicitement par `TASK.md` ; ne pas concevoir d'héritage d'`AGENTS.md` entre
niveaux. Justifier tout agent supplémentaire (permissions différentes,
isolation de risque, contexte réellement distinct, parallélisation utile,
séparation évaluateur / agent testé).

### Workspace

Voir §8. Si aucune donnée persistante n'est nécessaire, ne pas créer de
workspace vide.

---

## 8. Workspace métier

Un workspace est un **repo Git indépendant** imbriqué sous le cas d'usage :

```text
paul/finance/contract-management/obligations/workspace-obligations/.git/
```

- nom obligatoire : `workspace-<slug>` ;
- son `.git` et son remote lui appartiennent ; ils sont distincts de ceux de
  `paul` ; ses commits ne touchent pas l'index de `paul` ;
- `paul/.gitignore` contient `**/*workspace*` : le monorepo l'ignore
  automatiquement, sans `.gitkeep` ni autre artifice ;
- le repo **est** le workspace : jamais de sous-dossier
  `workspace-<slug>/workspace/` ;
- contenu selon les besoins uniquement : `input/`, `contract/`, `data/`,
  `documents/`, `output/`, `state/`, `.tmp/`, `test-data/`, `evaluator/` ;
- un `README.md` y est possible s'il est utile, mais pas obligatoire ;
- pas de `TASK.md` dans le workspace : le point d'entrée est celui du cas
  d'usage.

S'il existe déjà, le cloner directement sous ce nom
(`--workspace-from <url|chemin>`). Sinon, en initialiser un nouveau.

---

## 9. Génération — matérialiser la structure

1. Résoudre le dossier parent (§1) et écrire `USE_CASE_PATH` dans
   `READINESS.md`.
2. Écrire `CREATE_PHASE: GENERATION`, `NEXT_ACTION: RUN_SCAFFOLD`.
3. Appeler le script (il ne décide ni du métier, ni des skills nécessaires) :

   ```bash
   python <SKILL_DIR>/scripts/scaffold.py use-case \
     --name <slug> [--parent-dir <dossier métier>] \
     [--skills <skill>[:stub|dir|empty],…] [--scripts] \
     [--workspace --workspace-dirs input,output] \
     [--workspace-from <url|chemin>] [--workspace-url <url>] \
     [--task-from <fichier>] [--no-git]
   ```

   - `--parent-dir` vaut le répertoire courant par défaut ;
   - `--skills` uniquement pour des skills réellement décidés ;
   - `--workspace` uniquement si des données persistent ;
   - `--workspace-dirs` : uniquement les dossiers utiles.

   Le script refuse un nom préfixé (`automation-`, `agent-`, `workspace-`),
   refuse d'écraser un dossier non vide, et ne crée jamais de `_deps`, de
   submodule agentique ni de niveau `authoring/`.
4. Lire le résumé du script ; noter dans `GENERATED.md` ce qui a été créé.
5. `NEXT_ACTION: WRITE_TASK_AND_DOCS`.

Le script n'écrit aucune configuration de harness : Pi découvre la hiérarchie
seul (§11). Si l'utilisateur travaille sous Hermes, lancer ensuite
`scaffold.py hermes-adapter --path <use-case>`.

---

## 10. Génération — contenu

Selon le mode, compléter les fichiers générés (jamais d'invention en
`GENERATE_NOW`, rien de métier en `SCAFFOLD_ONLY`).

### 10.1 Runtime capability resolution

Avant d'écrire des instructions pour une capacité requise :

1. identifier la capacité logique ;
2. inspecter les outils déjà exposés par le harness courant ;
3. inspecter les skills hérités qui abstraient cette capacité ;
4. résoudre la capacité vers une implémentation runtime existante ;
5. consigner les noms exacts d'outils à utiliser ;
6. consigner si elle est installée et utilisable hors ligne.

Si la capacité existe déjà : le dire, nommer le fournisseur et les outils
exacts, interdire les installations redondantes et les recherches Internet
hors ligne. Les skills générés décrivent **comment** invoquer une capacité, pas
seulement la technologie.

Mauvais : « Use DuckDB to store obligations. »
Bon : « Utiliser le skill hérité `structured-data-duckdb` (sous Pi :
`@nqbao/pi-alchemy`, outils `alchemy_query`, `alchemy_schema`, `alchemy_load`).
DuckDB est embarqué ; ne pas chercher de CLI ni l'installer. »

Isoler les détails propres à un harness dans une section dédiée du skill.

### 10.2 Existing-data-first

Avant toute génération de données de test, inspecter les dossiers du workspace
(`input/`, `contract/`, `documents/`, `data/`, `test-data/`…) et tout chemin
cité dans les entrées.

| Situation | Règle |
|---|---|
| toutes les entrées existent | `EXISTING → REUSE` : ne pas régénérer, écraser, modifier ni dupliquer |
| corpus partiel | `PARTIAL → KEEP + GENERATE ONLY MISSING`, si autorisé et utile |
| aucun corpus utilisable | `NO DATA → GENERATE` le plus petit corpus réaliste (nominal, une exception, ambiguïté si utile ; ground truth hors de la vue de l'agent) |

Si l'utilisateur désigne des données existantes hors du workspace, les
**copier** dans le workspace (jamais déplacer l'original) après accord.
Inspection ≠ exécution : ne pas exécuter la mission métier pour reconstruire
des données de test.

### 10.3 Cycle de vie des sources

Si le cas d'usage consomme une collection de sources susceptible d'évoluer
entre deux runs, définir la stratégie (politique de mutation, registre, hash de
contenu, `processing_version`, NEW / MODIFIED / UNCHANGED / DELETED /
REPROCESS_REQUIRED, tombstones, invalidation ciblée, reprise) selon
`references/SOURCE_LIFECYCLE.md`. Ne pas l'ajouter aux traitements one-shot ou
aux entrées immuables. Si une réponse est nécessaire et non déductible, c'est
un gap de readiness.

### 10.4 Fichiers à produire

Chemins d'exécution relatifs à la racine du **cas d'usage** ; les données sont
préfixées par `workspace-<slug>/`.

| Fichier | Contenu |
|---|---|
| `TASK.md` | mission de l'agent : quoi lire, quoi produire, chemins, actions autonomes, validations humaines, interdits, reprise, skills réutilisés |
| `AUTOMATION_SPEC.md` (si utile) | Objective, Trigger, Actors, Inputs, Nominal flow, Decision rules, Critical exceptions, Outputs, Human-in-the-loop, Forbidden actions, Technical constraints, Runtime dependencies, Source lifecycle, Persistence strategy, Acceptance criteria, Test strategy, Reused components, New local components |
| `PROCESS_AUTOMATION.md` / `USE_CASE.md` (si utile) | copie de la description d'entrée |
| `AGENTS.md` (si utile) | règles durables de l'agent principal, référencées par `TASK.md` |
| `.agents/skills/<skill>/SKILL.md` | skills locaux justifiés |

Pas de `README.md`. `TASK.md` ne contient jamais la mission de
`create-use-case`.

### 10.5 Données et gros résultats

Pour un traitement volumineux, multi-étapes ou reprenable : stockage structuré
(DuckDB de préférence), identifiants stables, progression persistée, lots,
étapes idempotentes, rapports générés depuis l'état. Pas d'énorme Markdown
comme base d'exécution. Gros livrables : fragments dans
`workspace-<slug>/output/.parts/` puis assemblage déterministe.

### 10.6 Evaluator

`evaluator/` appartient au workspace et n'est jamais une entrée normale de
l'agent métier. Avant d'en créer un, inspecter `evaluator/` et `test-data/` :
un benchmark existant est préservé tel quel. En créer un seulement si utile et
absent, ou demandé.

### 10.7 Placeholders

Par défaut, en `GENERATE_NOW` : skill clairement défini → le générer ;
objectif flou → ne pas le générer. Placeholders **uniquement sur demande
explicite** (`--skills`) :

| Style | Résultat |
|---|---|
| `dir` | `.agents/skills/<nom>/` sans `SKILL.md` |
| `stub` | `SKILL.md` valide : `name`, `description: TODO - à définir.`, `# TODO` |
| `empty` | `SKILL.md` vide — uniquement si demandé ; signaler dans `GENERATED.md` qu'il n'est pas un skill chargeable |

### 10.8 Promotion (manuelle)

Classer chaque nouveau skill dans `PROMOTION_CANDIDATES.md` :

| Classe | Destination proposée |
|---|---|
| `LOCAL` | `<use-case>/.agents/skills/` |
| `SUBDOMAIN_CANDIDATE` | `<domaine>/<sous-domaine>/.agents/skills/` |
| `DOMAIN_CANDIDATE` | `<domaine>/.agents/skills/` |
| `COMMON_CANDIDATE` | `PAUL_ROOT/.agents/skills/` |

Statuts : `PROPOSED | ACCEPTED | REJECTED | PROMOTED`. Proposer, ne jamais
déplacer automatiquement. Avant promotion : doublons, capacités proches,
chemins spécifiques retirés, dépendances au harness, une seule copie (pas deux
versions divergentes). Une promotion est un simple `git mv` dans `paul`.

### 10.9 `GENERATED.md` (obligatoire après toute génération)

```markdown
# Generation summary

Mode: COMPLETE | GENERATE_NOW | SCAFFOLD_ONLY
Forced: true | false
Use case path: <chemin relatif à PAUL_ROOT>
Workspace: workspace-<slug> | none

## Generated
- <dossiers, fichiers, skills, workspace>

## Not generated
- <skills, evaluator… volontairement omis et pourquoi>

## Deferred
- <R* en TODO, sections TODO de TASK.md>

## Non-loadable placeholders
- <SKILL.md vides éventuels>
```

---

## 11. Harness — Pi et Hermes

- Source canonique des skills : `.agents/skills/<skill>/SKILL.md`. Jamais de
  copie dans `.pi/skills`, `.hermes/skills` ou un autre niveau métier.
- **Pi** implémente nativement l'héritage structurel : il remonte de `cwd`
  jusqu'à la racine Git en collectant `<niveau>/.agents/skills` à chaque
  étage. Depuis un cas d'usage, il voit donc ses skills locaux, ceux de ses
  parents métier et les communs — et rien des autres branches. **Aucun
  adaptateur n'est nécessaire** : ne pas écrire de `.pi/settings.json`.
- **Hermes** n'indexe que `<racine Git>/.agents/skills` et
  `<racine Git>/.hermes/skills` : depuis un cas d'usage, la racine Git est
  `PAUL_ROOT`, donc seuls les skills **communs** sont vus. Pour lui exposer les
  niveaux métier sans rien dupliquer :

  ```bash
  python <SKILL_DIR>/scripts/scaffold.py hermes-adapter --path <use-case>
  ```

  Cela construit `PAUL_ROOT/.hermes/skills/` avec un **lien de répertoire**
  (jonction Windows / symlink POSIX) par niveau métier de la branche visée —
  aucun `SKILL.md` n'est copié, il n'existe qu'un seul fichier sur disque. Le
  dossier est gitignored et se régénère ; `--all` lie toutes les branches (sans
  cloisonnement), `--clear` le vide.

Toute configuration harness-specific doit rester minimale, ne contenir aucune
logique métier et ne recopier aucun `SKILL.md`.

---

## 12. Vérification finale (`CREATE_PHASE: VALIDATION`)

1. readiness cohérente avec le mode (`TODO` seulement si différé) ;
2. entrées existantes non écrasées ;
3. ground truth non visible comme entrée de l'agent métier ;
4. le cas d'usage porte son nom fonctionnel, sans préfixe ;
5. aucun skill hérité modifié ; chaque nouveau skill est `LOCAL` ;
6. aucun `_deps`, aucun submodule agentique, aucun `authoring/`, aucun repo
   `automation-*` ou `agent-*` ;
7. aucun `README.md` créé dans le cas d'usage ni dans les niveaux métier ;
8. aucune donnée métier hors du workspace ; aucun skill ou script dans le
   workspace ; aucun sous-dossier `workspace/` ;
9. `TASK.md` exécutable depuis le dossier du cas d'usage ; reprise prévue ;
10. cycle de vie des sources défini si applicable ;
11. depuis `PAUL_ROOT`, `git status --short` n'affiche aucun fichier du
    workspace ; depuis le workspace, `git status` et `git remote -v`
    fonctionnent comme un repo indépendant ;
12. aucun `.pi/settings.json` n'a été créé (Pi n'en a pas besoin) ;
13. rien d'inutile (peut-on supprimer un skill, un dossier, un fichier sans
    perte ?) ;
14. ne pas lancer la mission métier.

Puis :

1. committer les nouveaux fichiers dans `paul` (pas de push) ; committer
   séparément le workspace s'il en a besoin ;
2. écrire `CREATE_PHASE: COMPLETE`, `RESUME_AFTER_INTERVIEW: false`,
   `NEXT_ACTION: NONE` ;
3. **supprimer** `PAUL_ROOT/.create-use-case/<slug>/` ;
4. récapituler : chemin du cas d'usage, mode, `TODO` restants, repo workspace
   à créer chez l'hébergeur Git le cas échéant, prochaine étape suggérée.

---

## 13. Résumé du cycle

```text
USE_CASE.md / PROCESS_AUTOMATION.md / conversation / existant
        │
        ▼
reprise (PAUL_ROOT/.create-use-case/<slug>/READINESS.md)
        │
        ▼
assess R1-R10 ── prêt ─────────────────────────────┐
        │ gaps bloquants                            │
        ▼                                           │
grill-me (1 question à la fois, capture persistée)  │
        │   └── « génère maintenant » → GENERATE_NOW┤
        ▼                                           │
réévaluation R1-R10 ────────────────────────────────┤
                                                    ▼
          dossier parent (cwd par défaut) + besoin d'un workspace
                                                    │
                                                    ▼
          scaffold.py use-case (dossier, TASK.md, skills, workspace, Pi)
                                                    │
                                                    ▼
      réutilisation des skills → capacités runtime → données existantes
                                                    │
                                                    ▼
          TASK / spécifications / skills justifiés / evaluator si utile
                                                    │
                                                    ▼
   GENERATED.md + PROMOTION_CANDIDATES.md → VALIDATION → état temporaire supprimé
```

Principe :

```text
grill-me        = HOW to interview
create-use-case = WHAT must be known + WHAT to generate + WHEN to resume
scaffold.py     = materialise the decisions, nothing more
```
