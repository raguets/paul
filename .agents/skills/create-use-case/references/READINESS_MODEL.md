# Readiness model R1-R10

## Dimensions

| ID | Dimension |
|---|---|
| R1 | Objectif métier et résultat attendu |
| R2 | Déclencheur ou mode d'utilisation |
| R3 | Acteurs et responsabilités |
| R4 | Entrées, formats et sources |
| R5 | Processus ou tâche nominale |
| R6 | Règles de décision et exceptions critiques |
| R7 | Sorties attendues |
| R8 | Validations humaines et actions interdites |
| R9 | Contraintes techniques, permissions et données |
| R10 | Critères d'acceptation et scénario de test |

Pour un cas d'usage léger, certaines dimensions peuvent être `N/A`
(justifier). Le dossier métier parent et le besoin d'un repo
`workspace-<slug>` ne sont pas des dimensions R mais peuvent être des gaps à
clarifier.

## Statuts

| Statut | Sens |
|---|---|
| `UNKNOWN` | aucune information |
| `PARTIAL` | information incomplète ou non validée |
| `CONFIRMED` | établi par une source (fichier, décision utilisateur, capture grill-me) |
| `N/A` | sans objet, justifié |
| `TODO` | laissé incomplet **volontairement** : l'utilisateur a décidé de générer avant la fin de la discovery |

- Ne jamais marquer `CONFIRMED` une dimension reposant sur une supposition non
  validée (la consigner dans `ASSUMPTIONS.md`).
- Ne jamais convertir automatiquement `UNKNOWN` en `TODO` : cela ne se produit
  que lors d'une génération anticipée (`GENERATE_NOW`), pour les gaps
  différés.

## Colonnes par dimension

`Status`, `Evidence`, `Blocking gap`, `Source`.

Sources possibles : `USE_CASE.md`, `PROCESS_AUTOMATION.md`, `existing file/data`,
`grill-me capture`, `user instruction`.

## Definition of Ready (mode `COMPLETE`)

```text
R1..R10 = CONFIRMED ou N/A
aucune contradiction bloquante ouverte
aucune entrée obligatoire non résolue sans stratégie
aucune action interdite ambiguë
un scénario de test existe ou est N/A de façon justifiée
USE_CASE_PATH et WORKSPACE_NEEDED déterminés
```

Quand elle est atteinte :

```text
USE_CASE_READY: YES
CREATE_PHASE: GENERATION
RESUME_AFTER_INTERVIEW: false
NEXT_ACTION: RUN_SCAFFOLD
```

En `GENERATE_NOW` / `SCAFFOLD_ONLY`, la Definition of Ready n'est pas exigée
(`USE_CASE_READY: NO` possible, `GENERATION_FORCED: true` pour `GENERATE_NOW`).

## Format de `READINESS.md`

```markdown
# Readiness — <slug>

CREATE_PHASE: ASSESSMENT
GENERATION_MODE: DISCOVERY
RESUME_AFTER_INTERVIEW: false
NEXT_ACTION: ASSESS_READINESS
USE_CASE_READY: NO
GENERATION_FORCED: false
USE_CASE_NAME: <slug>
USE_CASE_PATH: <chemin du cas d'usage, relatif à PAUL_ROOT>
WORKSPACE_NEEDED: YES | NO | UNKNOWN

| ID | Dimension | Status | Evidence | Blocking gap | Source |
|---|---|---|---|---|---|
| R1 | Objectif métier et résultat attendu | … | … | … | … |
…
```

## Valeurs usuelles de `NEXT_ACTION`

`ASSESS_READINESS`, `REASSESS_READINESS_AND_GENERATE`, `RUN_SCAFFOLD`,
`WRITE_TASK_AND_DOCS`, `WRITE_LOCAL_SKILLS`, `WRITE_EVALUATOR`,
`FINAL_VALIDATION`, `CLEANUP_STATE`, `NONE`. Un texte libre plus précis est
accepté.

## Emplacement de l'état

`PAUL_ROOT/.create-use-case/<slug>/` uniquement, gitignored, supprimé après
une génération réussie. Jamais `<use-case>/.create-use-case/`.

## Correspondance avec l'ancien `.bootstrap/`

| `.bootstrap` (process-automation-bootstrap) | `.create-use-case` |
|---|---|
| `BOOTSTRAP_PHASE` | `CREATE_PHASE` |
| `AUTOMATION_READY` | `USE_CASE_READY` |
| `RESUME_AFTER_INTERVIEW`, `NEXT_ACTION` | inchangés |
| — | `GENERATION_MODE`, `GENERATION_FORCED`, `USE_CASE_NAME`, `USE_CASE_PATH`, `WORKSPACE_NEEDED` |
