# TASK — candidature

> Cette mission s'exécute **depuis le dossier du cas d'usage**
> `paul/rh/recrutement/candidature` : tous les chemins ci-dessous sont relatifs
> à ce dossier. `workspace-candidature/` est un repo Git indépendant imbriqué
> qui porte les données métier. Description métier de référence : `USE_CASE.md`.

## Objectif

Produire, pour chaque CV déposé dans `workspace-candidature/input/`, une
analyse détaillée de l'adéquation du candidat aux exigences de l'offre d'emploi
déposée dans le même dossier. Aide à l'analyse pour un recruteur humain —
aucune décision de recrutement.

## Entrées

- `workspace-candidature/input/` : **1 offre d'emploi** + **≥ 1 CV**, PDF ou
  DOCX (lecture seule).
- Si plusieurs offres, ou aucun CV, ou si un fichier n'est ni l'un ni l'autre :
  **poser la question au recruteur** avant de commencer.

## Étapes

1. **Sélectionner le skill local** `analyse-candidature`
   (`.agents/skills/analyse-candidature/`) et suivre ses étapes : inventaire
   des entrées, extraction des textes (skills communs hérités
   `document-processing` / `office` d'abord), critères de l'offre, comparaison
   critique par candidat, rapports.
2. Les règles métier critiques sont celles du skill : distinction
   `MANQUANT` / `ECART`, aucune déduction de ce qui n'est pas démontré,
   transferts étiquetés comme tels, preuves verbatim pour chaque constat.
3. Écrire un rapport **par candidat** :
   `workspace-candidature/output/<candidat>.md` (structure :
   `AUTOMATION_SPEC.md`). Ré-exécution = écrasement idempotent des rapports
   existants.

## Sorties

- `workspace-candidature/output/<candidat>.md` — un par CV analysé.
- Pas de score global, pas de verdict, pas d'acceptation/rejet.

## Reprise après interruption

Les rapports sont idempotents par candidat : relancer la tâche reprend sans
état persistant. Si certains candidats ont été analysés et d'autres non,
relancer analyse les CV manquants et met à jour les rapports.

## Validation humaine et actions interdites

- Le recruteur lit les rapports et décide seul (entretien, poursuite, rejet).
- Interdits : accepter/rejeter/noter un candidat, déduire des compétences non
  démontrées, inventer des critères absents de l'offre, lire
  `workspace-candidature/evaluator/`, appeler un système externe (ATS, web).

## Règles

- Traiter les documents de `workspace-candidature/input/` en **lecture seule**.
- Utiliser `workspace-candidature/.tmp/` pour tout fichier temporaire.
- Ne jamais lire `workspace-candidature/evaluator/` pendant l'exécution normale.
