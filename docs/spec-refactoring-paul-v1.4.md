# Spécification de refactoring vers le monorepo `paul`

Version : 1.4  
Statut : cible architecturale finale depuis l'état refactoré actuel  
Destinataire : Claude / agent de refactoring

---

# 1. Objectif

Refactorer l'état actuel vers une architecture simple :

- un seul repo Git principal nommé `paul` pour toute la logique agentique ;
- hiérarchie métier exprimée directement par les dossiers ;
- `.agents/skills` possibles à plusieurs niveaux ;
- aucun submodule pour l'héritage des skills ;
- aucun `_deps` ;
- un cas d'usage porte directement son nom fonctionnel, par exemple `obligations` ;
- les données/documents/résultats persistants sont dans un repo Git séparé `workspace-<use-case>` placé sous le use case ;
- tous les workspaces imbriqués sont ignorés par Git depuis la racine de `paul` ;
- `create-use-case`, `grill-me` et `start-use-case` sont des skills communs ;
- aucun niveau `authoring/` ;
- aucun repo `automation-*` ;
- aucun repo `agent-*` par domaine ;
- aucune distinction structurelle entre tâche simple et automatisation ;
- pas de README dans les niveaux intermédiaires.

La migration doit partir de l'état actuel déjà refactoré. Ne pas repartir de zéro depuis l'ancien monorepo historique. Ne pas réintroduire l'ancien `process-automation-bootstrap`.

---

# 2. Repo principal

Le monorepo principal doit s'appeler :

```text
paul
```

Structure racine :

```text
paul/
├── .git/
├── .gitignore
├── README.md
├── .create-use-case/              # temporaire, gitignored
├── .agents/
│   └── skills/
└── <domaines-et-use-cases>/
```

`.create-use-case/` est de la mécanique interne temporaire. Il peut être absent lorsqu'aucune création n'est en cours.

---

# 3. README

Conserver uniquement le README principal par défaut :

```text
paul/README.md
```

Supprimer les README ajoutés seulement pour documenter des niveaux intermédiaires. Ne pas créer par défaut :

```text
finance/README.md
finance/contract-management/README.md
finance/contract-management/obligations/README.md
```

Un repo workspace peut avoir son propre README si c'est utile, mais ce n'est pas obligatoire.

La documentation opérationnelle d'un use case doit être principalement portée par `TASK.md` et, si nécessaire, de vrais fichiers de spécification.

---

# 4. Hiérarchie métier

La hiérarchie métier est exprimée par les dossiers :

```text
paul/
└── finance/
    └── contract-management/
        └── obligations/
```

Les niveaux domaine/sous-domaine sont facultatifs. Ne pas forcer une profondeur uniforme.

Exemples valides :

```text
paul/finance/contract-management/obligations/
paul/finance/monthly-close/
paul/customer-service/ticket-triage/
```

---

# 5. Convention des skills

La source canonique reste :

```text
.agents/skills/<skill-name>/SKILL.md
```

Des skills peuvent être présents aux différents niveaux :

```text
paul/
├── .agents/skills/                              # communs
└── finance/
    ├── .agents/skills/                          # Finance
    └── contract-management/
        ├── .agents/skills/                      # Contract Management
        └── obligations/
            └── .agents/skills/                  # Obligations
```

Ne pas dupliquer les skills pour les harnesses.

---

# 6. Suppression de `_deps` et des submodules agentiques

Supprimer toutes les structures :

```text
.agents/skills/_deps/
```

Ne plus utiliser de submodules pour `common`, `finance`, `contract-management`, une automation ou l'authoring.

L'héritage devient structurel :

```text
paul/.agents/skills
        ↓
finance/.agents/skills
        ↓
contract-management/.agents/skills
        ↓
obligations/.agents/skills
```

Les anciens repos tels que :

```text
agent-common
agent-authoring
agent-finance
agent-finance-contract-management
automation-create-use-case
automation-finance-contract-management-obligations
```

doivent être consolidés dans `paul`. Ne les archiver qu'après validation.

---

# 7. Nommage des cas d'usage

Nom correct :

```text
obligations/
```

Nom incorrect :

```text
automation-obligations/
```

Même règle pour tous les cas d'usage :

```text
contract-review/
monthly-close/
supplier-onboarding/
ticket-triage/
```

---

# 8. Modèle unique de use case

Il n'existe plus deux architectures distinctes « tâche simple » et « automatisation ».

Structure maximale :

```text
<use-case>/
├── TASK.md
├── <spécifications utiles>
├── .agents/
│   └── skills/
│       └── <skills-spécifiques>/
│           └── SKILL.md
├── scripts/
│   └── ...
└── workspace-<use-case>/
    └── .git/
```

Ne créer que les éléments réellement nécessaires.

Une tâche simple peut être :

```text
contract-summary/
├── TASK.md
└── workspace-contract-summary/
    └── .git/
```

Un use case avec une capacité spécifique peut être :

```text
obligations/
├── TASK.md
├── .agents/
│   └── skills/
│       └── obligation-register-duckdb/
│           └── SKILL.md
├── scripts/
└── workspace-obligations/
    └── .git/
```

La présence ou l'absence de `.agents/skills` ne change pas le type d'architecture.

---

# 9. Workspaces métier

Chaque workspace métier est un repo Git indépendant, nommé :

```text
workspace-<use-case>
```

Exemple :

```text
paul/
└── finance/
    └── contract-management/
        └── obligations/
            └── workspace-obligations/
                └── .git/
```

Le `.git` du workspace appartient au workspace, pas à `paul`. Son remote Git est distinct de celui de `paul`.

---

# 10. `.gitignore` racine

À la racine de `paul`, ajouter :

```gitignore
# Independent business workspace repositories
**/*workspace*

# Internal transient state for create-use-case
/.create-use-case/
```

La règle `**/*workspace*` est volontairement large, conformément à la convention retenue.

Ne pas utiliser `.gitkeep` comme mécanisme de séparation Git.

---

# 11. Contenu des workspaces

Un workspace peut contenir, selon les besoins :

```text
workspace-obligations/
├── .git/
├── input/
├── contract/
├── data/
├── documents/
├── output/
├── state/
├── .tmp/
├── test-data/
└── evaluator/
```

Tous ces dossiers sont optionnels. Ne créer que ceux qui servent réellement.

Le repo lui-même est le workspace. Ne jamais créer :

```text
workspace-obligations/workspace/
```

---

# 12. Point de lancement des harnesses

Lancer le harness depuis le dossier agentique du use case :

```bash
cd paul/finance/contract-management/obligations
```

Puis `pi`, `hermes`, `opencode`, etc.

Ne pas prendre comme convention :

```bash
cd workspace-obligations
```

Le `.git` du workspace est en dessous du cwd du use case et ne doit donc pas modifier la recherche ascendante depuis le dossier du use case.

---

# 13. Chemins vers le workspace

`TASK.md` référence le workspace par chemins relatifs :

```text
workspace-obligations/input/
workspace-obligations/contract/
workspace-obligations/output/
workspace-obligations/state/
```

Pas de chemin absolu et pas de variable d'environnement nécessaire pour localiser le workspace.

---

# 14. Skills communs

Les capacités communes vivent directement sous :

```text
paul/.agents/skills/
```

Inclure notamment :

```text
create-use-case/
grill-me/
start-use-case/
structured-data-duckdb/
```

Structure :

```text
paul/
└── .agents/
    └── skills/
        ├── create-use-case/
        │   ├── SKILL.md
        │   ├── scripts/
        │   │   └── scaffold.py
        │   └── templates/              # optionnel
        ├── grill-me/
        │   └── SKILL.md
        ├── start-use-case/
        │   └── SKILL.md
        └── structured-data-duckdb/
            └── SKILL.md
```

Ne pas créer de branche `authoring/`.

---

# 15. `create-use-case`

`create-use-case` devient un skill commun :

```text
paul/.agents/skills/create-use-case/SKILL.md
```

Il ne possède :

- ni repo Git séparé ;
- ni workspace propre ;
- ni domaine `authoring/`.

Il est disponible partout dans `paul`.

---

# 16. Utilisation de `create-use-case`

La convention principale : lancer le harness depuis le répertoire parent dans lequel créer le nouveau use case.

Exemple :

```bash
cd paul/finance/contract-management
```

Puis demander :

```text
crée un use case obligations
```

Résultat :

```text
./obligations/
```

Donc :

```text
paul/finance/contract-management/obligations/
```

Le répertoire courant est le parent par défaut.

Si la destination est explicitement indiquée, `create-use-case` peut aussi être invoqué depuis ailleurs, par exemple depuis la racine :

```text
crée le use case obligations sous finance/contract-management
```

---

# 17. État interne de `create-use-case`

L'état de travail de `create-use-case` est interne et temporaire.

Ne jamais créer durablement :

```text
obligations/.create-use-case/
```

Le seul emplacement temporaire autorisé est :

```text
paul/.create-use-case/
```

Exemple pendant la création :

```text
paul/
└── .create-use-case/
    └── obligations/
        ├── READINESS.md
        ├── ASSUMPTIONS.md
        ├── OPEN_QUESTIONS.md
        ├── PROMOTION_CANDIDATES.md
        ├── GENERATED.md
        └── interview.md
```

Ce dossier est gitignored.

Cycle de vie :

1. créer `paul/.create-use-case/<slug>/` pendant le travail ;
2. y conserver l'état nécessaire à la reprise ;
3. générer le use case final ;
4. après génération réussie, supprimer cet état temporaire.

Aucun de ces fichiers ne doit être nécessaire pour exécuter le use case généré.

---

# 18. Préserver les améliorations de `create-use-case`

Ne pas revenir à `process-automation-bootstrap`.

Conserver :

- existing-data-first ;
- reuse-before-creation ;
- architecture minimale ;
- interview guidée avec `grill-me` ;
- possibilité de reprendre une création interrompue tant que l'état temporaire existe ;
- génération sans invention de logique manquante.

Avant de créer un nouveau skill, vérifier d'abord les skills du use case, du parent métier et les skills communs.

Ne pas créer de skill, agent, script ou workspace vide juste pour satisfaire un template.

---

# 19. Modes de `create-use-case`

Conserver :

```text
DISCOVERY
COMPLETE
GENERATE_NOW
SCAFFOLD_ONLY
```

## DISCOVERY

- inspecter l'existant ;
- évaluer le readiness ;
- utiliser `grill-me` si nécessaire ;
- clarifier les points importants.

## COMPLETE

Lorsque les informations sont suffisantes : générer le use case complet avec uniquement les artefacts nécessaires.

## GENERATE_NOW

Si l'utilisateur dit par exemple :

```text
génère maintenant
arrête les questions
fais avec ce qu'on a
```

alors :

- arrêter immédiatement l'interview ;
- générer avec les informations disponibles ;
- ne pas inventer la logique manquante ;
- omettre les skills inconnus ;
- ajouter des TODO seulement lorsqu'ils apportent une information utile.

## SCAFFOLD_ONLY

Créer uniquement la structure demandée, sans inventer de logique métier.

---

# 20. Readiness

Conserver conceptuellement :

```text
UNKNOWN
PARTIAL
CONFIRMED
N/A
TODO
```

Ces statuts servent seulement pendant la création et vivent dans :

```text
paul/.create-use-case/<slug>/
```

Ils ne doivent pas devenir une structure persistante obligatoire du use case final.

---

# 21. `grill-me`

Conserver :

```text
paul/.agents/skills/grill-me/SKILL.md
```

`create-use-case` peut l'utiliser pour l'interview.

Ne pas dépendre obligatoirement d'une commande Pi spécifique `/grill-me`.

---

# 22. `start-use-case`

Conserver :

```text
paul/.agents/skills/start-use-case/SKILL.md
```

Les formulations implicites (`go`, `vas-y`, `commence`, etc.) ne signifient « lancer le use case courant » que lorsqu'elles constituent la première instruction opérationnelle substantielle de la conversation.

Plus tard, elles suivent le contexte courant et ne doivent pas recharger automatiquement `TASK.md`.

Les demandes explicites restent valables à tout moment :

```text
exécute TASK.md
lance le use case obligations
reprends obligations
```

Le point d'entrée canonique est le `TASK.md` du dossier du use case.

Ne pas choisir implicitement un `TASK.md` situé sous :

```text
workspace-*/
.agents/
evaluator/
.git/
```

---

# 23. `scaffold.py`

Conserver un script déterministe sous :

```text
paul/.agents/skills/create-use-case/scripts/scaffold.py
```

Il peut :

- créer le dossier du use case ;
- créer `TASK.md` ;
- créer `.agents/skills/<skill>` si demandé ;
- créer `scripts/` si demandé ;
- créer un nouveau repo workspace ;
- cloner un workspace existant ;
- créer des templates.

Il ne doit pas :

- décider du métier ;
- décider seul des skills nécessaires ;
- inventer un workflow ;
- créer des `_deps` ;
- créer des submodules agentiques ;
- créer un repo `automation-*` ;
- créer un repo `agent-*` ;
- créer `authoring/`.

---

# 24. Création d'un workspace

Si un use case a besoin d'un workspace persistant, créer :

```text
workspace-<slug>
```

sous le use case.

Exemple :

```text
obligations/
└── workspace-obligations/
```

Initialiser son propre Git s'il est nouveau. S'il existe déjà, le cloner directement sous ce nom.

Le monorepo doit l'ignorer automatiquement.

Si aucune donnée persistante n'est nécessaire, ne pas créer de workspace vide.

---

# 25. Mapping de migration depuis l'état actuel

La migration doit utiliser l'état déjà produit par les refactorings précédents comme source de travail.

## `agent-common`

Migrer :

```text
agent-common/.agents/skills/*
```

vers :

```text
paul/.agents/skills/*
```

Ne pas restaurer `process-automation-bootstrap`.

## `agent-authoring`

Migrer ses skills utiles directement vers :

```text
paul/.agents/skills/
```

notamment `grill-me`.

Supprimer ensuite le besoin d'un niveau `authoring`.

## `automation-create-use-case`

Migrer son contenu utile vers :

```text
paul/.agents/skills/create-use-case/
```

Inclure `SKILL.md`, `scaffold.py`, templates utiles, tests utiles et logique de génération.

Ne pas conserver un repo/dossier `automation-create-use-case`.

## `workspace-create-use-case`

Ne pas conserver ce workspace dans l'architecture cible.

Récupérer seulement les éléments réellement utiles. Si `catalog.yaml` reste nécessaire, le placer par exemple sous :

```text
paul/.agents/skills/create-use-case/catalog.yaml
```

Ne pas créer de repo workspace pour `create-use-case`.

## `agent-finance`

Migrer ses skills vers :

```text
paul/finance/.agents/skills/
```

Si aucun skill Finance n'existe, ne pas créer artificiellement de README ou de dossiers vides.

## `agent-finance-contract-management`

Migrer ses skills vers :

```text
paul/finance/contract-management/.agents/skills/
```

`contract-obligation-extraction` reste à ce niveau s'il est générique à Contract Management.

## Obligations agentique

Migrer :

```text
automation-finance-contract-management-obligations/
```

vers :

```text
paul/finance/contract-management/obligations/
```

Migrer `TASK.md`, skills spécifiques, scripts et spécifications réellement utiles.

Supprimer `_deps`.

## Workspace Obligations

Conserver le repo workspace comme repo Git indépendant, de préférence nommé :

```text
workspace-obligations
```

Le placer sous :

```text
paul/finance/contract-management/obligations/workspace-obligations/
```

Conserver son `.git` et son remote propre. Ne pas intégrer son historique dans `paul`.

---

# 26. Arborescence finale cible

Arborescence de référence :

```text
paul/
├── .git/
├── .gitignore
├── README.md
│
├── .create-use-case/                         # temporaire, gitignored
│
├── .agents/
│   └── skills/
│       ├── create-use-case/
│       │   ├── SKILL.md
│       │   ├── catalog.yaml                  # seulement si utile
│       │   ├── scripts/
│       │   │   └── scaffold.py
│       │   └── templates/                    # optionnel
│       ├── grill-me/
│       │   └── SKILL.md
│       ├── start-use-case/
│       │   └── SKILL.md
│       ├── structured-data-duckdb/
│       │   └── SKILL.md
│       └── <autres-skills-communs>/
│           └── SKILL.md
│
└── finance/
    ├── .agents/
    │   └── skills/
    │       └── <skills-finance-si-necessaires>/
    │           └── SKILL.md
    │
    └── contract-management/
        ├── .agents/
        │   └── skills/
        │       └── contract-obligation-extraction/
        │           └── SKILL.md
        │
        └── obligations/
            ├── TASK.md
            ├── AUTOMATION_SPEC.md             # seulement si utile
            ├── PROCESS_AUTOMATION.md          # seulement si utile
            ├── .agents/
            │   └── skills/
            │       └── obligation-register-duckdb/
            │           └── SKILL.md
            ├── scripts/                       # seulement si utile
            │   └── ...
            └── workspace-obligations/         # repo Git indépendant
                ├── .git/
                ├── input/
                ├── contract/
                ├── data/
                ├── documents/
                ├── output/
                ├── state/
                ├── .tmp/
                ├── test-data/
                └── evaluator/
```

Ne pas créer les dossiers vides ou inutiles juste pour correspondre au diagramme.

---

# 27. Exemple de génération d'un nouveau use case

Depuis :

```bash
cd paul/finance/contract-management
```

Utilisateur :

```text
crée un use case contract-review
```

Pendant la création, `create-use-case` peut utiliser :

```text
paul/.create-use-case/contract-review/
```

Résultat minimal :

```text
paul/
└── finance/
    └── contract-management/
        └── contract-review/
            ├── TASK.md
            └── workspace-contract-review/
                └── .git/
```

Si un skill spécifique est nécessaire :

```text
contract-review/
├── TASK.md
├── .agents/
│   └── skills/
│       └── <skill>/
│           └── SKILL.md
└── workspace-contract-review/
```

Après génération réussie, supprimer :

```text
paul/.create-use-case/contract-review/
```

---

# 28. Git et workspaces imbriqués

Depuis la racine de `paul` :

```bash
git status --short
```

ne doit pas afficher les fichiers situés dans les `workspace-*`.

Depuis le repo workspace :

```bash
cd paul/finance/contract-management/obligations/workspace-obligations
git status
git remote -v
```

le workspace doit fonctionner comme repo Git indépendant.

Les commits du workspace ne doivent pas modifier l'index de `paul`, et inversement.

---

# 29. Portabilité des harnesses

La hiérarchie canonique reste celle du filesystem.

Pi/OpenCode peuvent exploiter directement la remontée des `.agents/skills` si leur comportement le permet.

Hermes/DeepSeek peuvent nécessiter une configuration supplémentaire pour exposer certains `.agents/skills` intermédiaires.

Ne pas changer l'architecture métier pour cette raison et ne pas dupliquer les skills.

Si une config harness-specific devient nécessaire :

- elle doit rester minimale ;
- elle ne contient aucune logique métier ;
- elle ne recopie aucun `SKILL.md` ;
- elle peut être traitée séparément du refactoring principal.

---

# 30. Tests structurels obligatoires

## Aucun `_deps`

```bash
find . -path '*/.agents/skills/_deps'
```

Attendu : aucun résultat.

## Aucun `authoring/`

Ne pas avoir :

```text
paul/authoring/
```

## Aucun repo `automation-*` dans la cible

Ne pas avoir :

```text
automation-obligations/
automation-create-use-case/
```

## Aucun workspace pour `create-use-case`

Ne pas avoir :

```text
workspace-create-use-case/
```

## Pas de README intermédiaires inutiles

Vérifier notamment l'absence par défaut de :

```text
finance/README.md
finance/contract-management/README.md
finance/contract-management/obligations/README.md
```

---

# 31. Tests `create-use-case`

## CU1 — génération depuis le parent courant

Depuis :

```text
paul/finance/contract-management
```

Demande :

```text
crée un use case test-case
```

Attendu :

```text
paul/finance/contract-management/test-case/
```

## CU2 — état temporaire

Pendant la création :

```text
paul/.create-use-case/test-case/
```

peut exister.

Après succès, il doit être supprimé.

## CU3 — aucune pollution du use case

Le résultat ne doit jamais contenir :

```text
test-case/.create-use-case/
```

## CU4 — pas de skill inutile

Si aucun skill spécifique n'est nécessaire, ne pas créer artificiellement :

```text
test-case/.agents/skills/
```

## CU5 — workspace optionnel

Si aucune donnée persistante n'est nécessaire, ne pas créer de workspace vide.

Si un workspace est nécessaire, `workspace-test-case/` doit être un repo Git indépendant.

## CU6 — GENERATE_NOW

Pendant l'interview :

```text
génère maintenant
```

Attendu : arrêt des questions et génération minimale valide sans invention des informations manquantes.

---

# 32. Tests `start-use-case`

## SU1 — premier message

Depuis :

```text
paul/finance/contract-management/obligations
```

Nouvelle conversation :

```text
go
```

Attendu : résolution de `obligations/TASK.md` et lancement du use case.

## SU2 — `go` plus tard

Dans une conversation déjà engagée :

```text
go
```

Attendu : suivre le contexte sans recharger automatiquement `TASK.md`.

## SU3 — lancement explicite

```text
lance le use case obligations
```

Attendu : lancement explicite possible à tout moment.

## SU4 — workspace non prioritaire

Même si `workspace-obligations/TASK.md` existe, le lancement implicite depuis `obligations/` doit prendre `obligations/TASK.md`.

---

# 33. Tests Obligations

Depuis :

```text
paul/finance/contract-management/obligations
```

vérifier la structure hiérarchique :

```text
paul/.agents/skills/
paul/finance/.agents/skills/                     # si présent
paul/finance/contract-management/.agents/skills/
paul/finance/contract-management/obligations/.agents/skills/
```

`contract-obligation-extraction` doit rester au niveau `contract-management`.

`obligation-register-duckdb` doit rester au niveau `obligations`.

Les données métier doivent rester dans `workspace-obligations/`.

---

# 34. Critères d'acceptation

## Repo principal

- [ ] Le repo principal s'appelle `paul`.
- [ ] Il contient toute la logique agentique.
- [ ] Il n'existe plus de chaîne de repos agentiques.
- [ ] Il n'existe plus de submodules d'héritage.
- [ ] Il n'existe plus de `_deps`.

## Hiérarchie

- [ ] Domaines et sous-domaines sont de simples dossiers.
- [ ] Les skills sont placés au bon niveau métier.
- [ ] Les use cases portent leur nom fonctionnel.
- [ ] `obligations` remplace `automation-obligations`.

## README

- [ ] `paul/README.md` existe.
- [ ] Les README intermédiaires inutiles sont supprimés.
- [ ] Aucun README n'est créé automatiquement pour chaque dossier métier.

## Workspaces

- [ ] `workspace-obligations` est sous `obligations`.
- [ ] Il possède son propre `.git`.
- [ ] Son remote est distinct de celui de `paul`.
- [ ] `paul/.gitignore` contient `**/*workspace*`.
- [ ] Le monorepo n'indexe pas le contenu des workspaces.
- [ ] Il n'existe pas de sous-dossier `workspace/` dans les repos `workspace-*`.

## Use cases

- [ ] Tâches simples et automatisations utilisent le même modèle.
- [ ] `.agents/skills` est absent quand aucun skill spécifique n'est nécessaire.
- [ ] Aucun repo `automation-*` n'est créé.

## Create Use Case

- [ ] `create-use-case` est un skill commun.
- [ ] Il vit sous `paul/.agents/skills/create-use-case/`.
- [ ] Il n'existe aucun `authoring/`.
- [ ] Il n'existe aucun `workspace-create-use-case`.
- [ ] Il génère par défaut dans le répertoire courant.
- [ ] Son état temporaire est sous `paul/.create-use-case/<slug>/`.
- [ ] Cet état est gitignored.
- [ ] Cet état n'est jamais copié dans le use case final.
- [ ] Cet état est supprimé après succès.
- [ ] `DISCOVERY`, `COMPLETE`, `GENERATE_NOW`, `SCAFFOLD_ONLY` sont conservés.
- [ ] `grill-me` reste disponible.
- [ ] `process-automation-bootstrap` n'est pas réintroduit.

## Start Use Case

- [ ] `start-use-case` est commun.
- [ ] Le lancement implicite s'applique seulement au début d'une conversation.
- [ ] Un `go` tardif ne redémarre pas automatiquement le use case.
- [ ] Le lancement explicite reste possible à tout moment.

---

# 35. Ordre de migration recommandé

1. inventorier l'état actuel ;
2. sauvegarder branches et SHAs importants ;
3. créer ou renommer le repo principal en `paul` ;
4. ajouter les règles `.gitignore` ;
5. migrer les skills communs ;
6. migrer `grill-me` ;
7. migrer `start-use-case` ;
8. convertir `create-use-case` en skill commun ;
9. supprimer le besoin de `authoring/` ;
10. migrer Finance ;
11. migrer Contract Management ;
12. migrer Obligations vers `finance/contract-management/obligations/` ;
13. positionner `workspace-obligations` sous `obligations/` ;
14. retirer tous les `_deps` ;
15. retirer les submodules agentiques ;
16. supprimer les README intermédiaires inutiles ;
17. adapter les chemins dans les `TASK.md` ;
18. adapter `scaffold.py` ;
19. adapter les tests ;
20. valider Git et les use cases ;
21. seulement après validation, archiver les anciens repos agentiques.

---

# 36. Résultat final de référence

```text
paul/
├── .git/
├── .gitignore
├── README.md
├── .create-use-case/                     # temporaire uniquement
│
├── .agents/
│   └── skills/
│       ├── create-use-case/
│       │   ├── SKILL.md
│       │   └── scripts/
│       │       └── scaffold.py
│       ├── grill-me/
│       │   └── SKILL.md
│       ├── start-use-case/
│       │   └── SKILL.md
│       ├── structured-data-duckdb/
│       │   └── SKILL.md
│       └── ...
│
└── finance/
    └── contract-management/
        ├── .agents/
        │   └── skills/
        │       └── contract-obligation-extraction/
        │           └── SKILL.md
        │
        └── obligations/
            ├── TASK.md
            ├── .agents/
            │   └── skills/
            │       └── obligation-register-duckdb/
            │           └── SKILL.md
            ├── scripts/
            │   └── ...
            └── workspace-obligations/
                ├── .git/
                ├── input/
                ├── contract/
                ├── data/
                ├── documents/
                ├── output/
                ├── state/
                ├── .tmp/
                ├── test-data/
                └── evaluator/
```

Ne pas créer les dossiers vides ou inutiles juste pour correspondre au diagramme.

---

# 37. Instruction finale à Claude

Appliquer cette spécification comme une migration de l'état actuel.

Priorités :

1. préserver le travail fonctionnel déjà réalisé ;
2. simplifier la structure ;
3. consolider toute la logique agentique dans `paul` ;
4. supprimer `_deps` et les submodules agentiques ;
5. utiliser les dossiers métier comme mécanisme d'organisation ;
6. nommer les use cases directement par leur fonction ;
7. conserver les workspaces comme repos Git indépendants imbriqués ;
8. ignorer globalement les workspaces depuis `paul` ;
9. convertir `create-use-case` en skill commun ;
10. ne pas conserver de workspace propre à `create-use-case` ;
11. ne pas conserver d'état `.create-use-case` dans les use cases générés ;
12. conserver les améliorations fonctionnelles de `create-use-case` ;
13. conserver `grill-me` ;
14. conserver `start-use-case` ;
15. ne pas réintroduire `process-automation-bootstrap` ;
16. supprimer les README intermédiaires inutiles ;
17. produire l'arborescence la plus simple possible.

En cas de conflit entre un artefact hérité des refactorings précédents et cette spécification, cette spécification définit la cible architecturale finale.
