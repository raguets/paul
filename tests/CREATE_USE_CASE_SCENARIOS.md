# create-use-case — scénarios de test fonctionnels

À exécuter depuis un clone de `paul`, avec un agent (Pi ou Hermes) et **aucune
donnée confidentielle**. Les parties marquées *(automatisé)* sont couvertes par
`verify.sh`.

Pour chaque scénario, vérifier `paul/.create-use-case/<slug>/READINESS.md`,
`GENERATED.md` et le cas d'usage généré.

## CU1 — génération depuis le parent courant

Depuis `paul/finance/contract-management`, demander :

```text
crée un use case test-case
```

Attendu :

- le cas d'usage est créé dans le répertoire courant :
  `paul/finance/contract-management/test-case/` ;
- le dossier porte son nom fonctionnel, sans préfixe ;
- aucun repo `automation-*` ni `agent-*` n'est créé.

*(automatisé : `scaffold.py use-case --name test-case`)*

## CU2 — état temporaire

Pendant la création, `paul/.create-use-case/test-case/` peut exister
(`READINESS.md`, `ASSUMPTIONS.md`, `OPEN_QUESTIONS.md`,
`PROMOTION_CANDIDATES.md`, `GENERATED.md`, `interview.md`).

Attendu :

- ce dossier est gitignored (`git status --short` ne l'affiche pas) ;
- après une génération réussie, il est **supprimé**.

## CU3 — aucune pollution du cas d'usage

Attendu : le résultat ne contient jamais `test-case/.create-use-case/`, et
aucun fichier d'état n'est nécessaire pour exécuter le cas d'usage.

*(automatisé)*

## CU4 — pas de skill inutile

Si aucun skill spécifique n'est nécessaire, `test-case/.agents/skills/` n'est
pas créé. Avant de créer un skill, `create-use-case` inspecte ceux du cas
d'usage, des dossiers métier parents et les communs.

*(automatisé)*

## CU5 — workspace optionnel

- Aucune donnée persistante → aucun `workspace-test-case/`.
- Données persistantes → `workspace-test-case/` est un repo Git **indépendant**
  sous le cas d'usage, ignoré par `paul` (`**/*workspace*`), sans sous-dossier
  `workspace/`, et ses commits ne touchent pas l'index de `paul`.

*(automatisé)*

## CU6 — `GENERATE_NOW`

Pendant l'entretien, répondre :

```text
génère maintenant
```

Attendu :

- l'entretien s'arrête immédiatement (questions restantes `DEFERRED`) ;
- les gaps volontairement différés passent à `TODO` (les autres `UNKNOWN` ne
  sont pas convertis silencieusement) ;
- génération minimale valide, sans invention de la logique manquante : pas de
  règle métier fabriquée, skills à l'objectif flou omis ;
- `GENERATION_MODE: GENERATE_NOW`, `GENERATION_FORCED: true` ;
- `OPEN_QUESTIONS.md` liste les points non résolus.

## A — demande complète

Entrée : `USE_CASE.md` entièrement rempli (objectif, déclencheur, acteurs,
entrées, étapes, règles, sorties, validations humaines, contraintes, critères
d'acceptation).

Attendu : aucun entretien grill-me ; R1-R10 `CONFIRMED` / `N/A` avec evidence ;
`USE_CASE_PATH` et `WORKSPACE_NEEDED` déterminés et justifiés ; scaffold puis
génération ; `GENERATION_MODE: COMPLETE`, `GENERATION_FORCED: false` ;
`GENERATED.md` présent ; `CREATE_PHASE: COMPLETE` ; état temporaire supprimé.

## B — demande incomplète

Entrée : une phrase (« Je veux suivre les échéances de mes contrats
fournisseurs. »).

Attendu :

- grill-me pose **une question à la fois**, avec une recommandation ;
- `interview.md` est mis à jour après **chaque** réponse ;
- interrompre la conversation, en démarrer une nouvelle et dire « Poursuis
  create-use-case » : l'entretien reprend et **aucune question déjà répondue
  n'est reposée** ;
- une fois les gaps résolus, `create-use-case` réévalue R1-R10 et poursuit sans
  attendre « continue ».

## D — `SCAFFOLD_ONLY`

Entrée : « Crée simplement l'arborescence. Pas de skill local. »

Attendu : aucune question superflue ; dossier, `TASK.md` et workspace si
demandé ; aucun skill ; `GENERATION_MODE: SCAFFOLD_ONLY`.

*(automatisé : `scaffold.py use-case --name scenario-d` → aucun `SKILL.md`)*

## E — cas d'usage rattaché directement à un domaine

Entrée : « Chaque mois, relire le rapport financier mensuel déposé et en
produire une synthèse. » Depuis `paul/finance`.

Attendu : `paul/finance/monthly-review/` — un domaine peut recevoir
directement un cas d'usage même s'il a des sous-domaines ; le cas d'usage
hérite de `finance/.agents/skills` et des skills communs, **pas** de
`contract-management/.agents/skills`.

## F — destination explicite

Depuis la racine de `paul` : « crée le use case contract-review sous
finance/contract-management ».

Attendu : `paul/finance/contract-management/contract-review/`.

## G — nom interdit

Demander un cas d'usage nommé `automation-obligations`.

Attendu : le nom est refusé ou corrigé en `obligations` ; aucun dossier préfixé
n'est créé.

*(automatisé)*
