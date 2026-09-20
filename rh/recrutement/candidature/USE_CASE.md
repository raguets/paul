# USE_CASE — candidature

**Nom** : candidature
**Emplacement** : `paul/rh/recrutement/candidature/`
**Données** : repo Git indépendant imbriqué `workspace-candidature/`
**Date** : 2026-09-19

## Objectif

Permettre à un recruteur d'analyser en détail l'adéquation d'une candidature à
une offre d'emploi. Le résultat est une **aide à l'analyse** destinée à un
recruteur humain : la décision de poursuivre ou non une candidature reste
entièrement humaine. L'automatisation ne doit **ni accepter ni rejeter**
automatiquement un candidat, et ne fournit pas de score global unique en
remplacement de l'analyse.

## Déclencheur et mode d'utilisation

Manuel. Le recruteur dépose dans `workspace-candidature/input/` :
- une **offre d'emploi** ;
- **un ou plusieurs CV** (candidats à analyser).

Documents principalement en **PDF ou DOCX**. Le recruteur lance ensuite la
tâche (`go` / `exécute TASK.md`) depuis le dossier du cas d'usage
`paul/rh/recrutement/candidature`.

## Comportement attendu

Pour **chaque candidat**, comparer **uniquement les informations effectivement
présentes dans le CV** aux exigences et attentes de l'offre.

Le résultat, dans `workspace-candidature/output/`, est une analyse
**structurée et exploitable** par
le recruteur, permettant de comprendre rapidement pourquoi un élément est
considéré comme correspondant ou non (pas seulement un verdict) :

- les **critères identifiés dans l'offre** (exigés / attendus), chacun avec
  l'extrait de l'offre qui le justifie ;
- les **éléments du CV qui correspondent**, avec les preuves (passages du CV) ;
- les **correspondances partielles**, avec l'écart précis ;
- les **écarts** (non-correspondances) ;
- les **critères pour lesquels le CV ne fournit pas suffisamment
  d'information** ;
- les **preuves / passages du CV** cités à l'appui de chaque constat.

## Règles métier critiques

1. **Absence d'information ≠ non-correspondance.** Les deux états sont
   distincts et doivent être étiquetés explicitement.
2. **Jamais de déduction** de compétences, expériences ou caractéristiques qui
   ne sont pas démontrées par le CV (pas d'inférence, pas d'hypothèse
   présentée comme un fait).
3. Les **compétences ou expériences transférables** peuvent être identifiées,
   mais doivent être **présentées comme telles** (libellé explicite) avec
   l'explication du rapprochement effectué.
4. Aucune décision de recrutement : pas d'acceptation, pas de rejet, pas de
   notation globale substituée à l'analyse.

## Contraintes

- **Local / offline** : fonctionne sur les documents présents dans
  `workspace-candidature/`, sans ATS ni autre système RH externe.
- Les entrées sont **en lecture seule** ; `workspace-candidature/.tmp/` pour
  les fichiers temporaires ; `workspace-candidature/evaluator/` n'est jamais
  une entrée de l'agent métier.

## Sorties

Un rapport **Markdown par candidat** dans
`workspace-candidature/output/<candidat>.md`, avec la structure détaillée dans
`AUTOMATION_SPEC.md`.

## Critères d'acceptation

Voir `workspace-candidature/evaluator/ACCEPTANCE.md` :
structure du rapport complète par candidat ; distinction explicite
absence/non-correspondance ; chaque constat appuyé par un extrait du CV ou de
l'offre ; aucun fait non démontré présenté comme avéré ; compétences
transférables étiquetées comme telles ; aucune décision de recrutement.

## Scénario de test

Corpus réel fourni par le recruteur : il dépose lui-même une offre et des CV
d'exemple dans `workspace-candidature/input/`, puis vérifie le rapport selon
`workspace-candidature/evaluator/ACCEPTANCE.md`.
