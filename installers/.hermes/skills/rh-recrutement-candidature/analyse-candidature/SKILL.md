---
name: analyse-candidature
description: Analyse l'adéquation d'un ou plusieurs CV à une offre d'emploi, à partir des seuls documents déposés dans workspace-candidature/input/. Identifie les critères de l'offre, compare chaque CV critère par critère (CORRESPOND, PARTIEL, ECART, MANQUANT, TRANSFERT) avec une preuve verbatim, distingue absence d'information et non-correspondance, étiquette les compétences transférables, et écrit un rapport Markdown par candidat dans workspace-candidature/output/. Aide à l'analyse destinée à un recruteur humain, sans score global, sans verdict et sans décision de recrutement.
---

# Analyse de l'adéquation d'une candidature à une offre

Analyser, pour chaque CV déposé dans `workspace-candidature/input/`, l'adéquation du candidat aux
exigences d'une offre d'emploi, en s'appuyant **uniquement sur les
informations effectivement présentes** dans le CV, et produire un rapport
Markdown lisible par le recruteur.

## Quand l'utiliser

- Tâche `candidature` : `workspace-candidature/input/` contient une offre d'emploi + un ou
  plusieurs CV, et le recruteur veut une analyse d'adéquation par candidat.
- Ne pas l'utiliser pour un seul document, un sourcing de candidats, ou toute
  action de décision (accepter/rejeter) — l'analyse est une **aide à la
  décision humaine**, pas une décision.

## Prérequis

- `workspace-candidature/input/` contient au moins 1 offre et 1 CV (PDF ou DOCX).
- Exécution **offline** : seulement les fichiers locaux du repo imbriqué `workspace-candidature/`.
- L'extraction de texte s'appuie sur les skills hérités
  (`document-processing`, `office`) : extraction texte d'abord ; OCR ou
  inspection visuelle seulement si le texte manque (scan, tableau complexe).

## Étapes

### 1. Inventaire des entrées

Lister `workspace-candidature/input/`. Identifier quel fichier est **l'offre** (un seul ; sinon
demander) et quels fichiers sont des **CV** (un par candidat). Le nom de
candidat est déduit du CV (en-tête, nom du fichier) — sinon demander.

### 2. Extraction

Extraire le texte de l'offre et de chaque CV. Conserver les **extraits
verbatim** (passages exacts, pas de reformulation) : ils serviront de preuves.
Pour un CV scanné sans couche texte, passer en OCR/inspection visuelle.

### 3. Critères de l'offre

Extraire de l'offre la liste des critères, en deux natures :
- **exigés** (obligatoires / « requis » / « must ») ;
- **attendus** (souhaités / « atout » / « nice to have »).

Chaque critère doit citer l'extrait de l'offre qui le fonde. Critères
typiques : compétences, expériences, diplômes/formations, langues,
outils/logiciels, mobilités/disponibilités — mais uniquement ceux que l'offre
mentionne réellement.

### 4. Comparaison CV ↔ critères (par candidat)

Pour **chaque critère × chaque CV**, attribuer exactement UN statut :

| Statut | Signification | Preuve exigée |
|---|---|---|
| `CORRESPOND` | Le CV le démontre explicitement | extrait du CV |
| `PARTIEL` | Le CV le démontre partiellement | extrait du CV + écart précis |
| `ECART` | Le CV contredit ou est nettement sous le critère | extrait du CV + écart |
| `MANQUANT` | Le CV ne fournit **aucune** information exploitable sur ce critère | mentionner l'absence ; ne rien déduire |
| `TRANSFERT` | Compétence/expérience **transférable** : pas mentionnée à l'identique, mais un élément du CV permet un rapprochement explicite | extrait du CV + explication du rapprochement, **présenté comme tel** |

Règles non négociables :
1. **`MANQUANT` ≠ `ECART`.** Absence d'information n'est pas une
   non-correspondance. Jamais de mélange des deux.
2. **Aucune déduction.** Si le CV ne le démontre pas, ce n'est pas acquis.
   Pas d'inférence présentée comme fait (« a probablement géré… », « on peut
   supposer… ») — soit c'est prouvé, soit c'est `MANQUANT`.
3. **`TRANSFERT` est une hypothèse étiquetée** : toujours formuler comme
   « transfert possible de X vers Y, car … », jamais comme compétence
   acquise.
4. Chaque statut s'appuie sur des **extraits verbatim** du CV (ou, pour
   `MANQUANT`, sur la constatable absence d'élément en rapport).
5. Ne comparer que ce que le CV contient réellement ; ignorer ce qui n'y est
   pas, au lieu d'imaginer.

### 5. Rapport par candidat → `workspace-candidature/output/<candidat>.md`

Structure imposée (voir `AUTOMATION_SPEC.md`) :
1. **En-tête** : offre, CV analysé, date, rappel « aide à l'analyse — la
   décision de recrutement appartient au recruteur ».
2. **Lecture d'ensemble** : quelques lignes qualitatives (pas de score, pas
   de pourcentage, pas de verdict go/no-go).
3. **Tableau des critères** : un line par critère de l'offre — critère, nature
   (exigé/attendu), statut (les 5 statuts), preuve (extrait du CV ou
   mention d'absence), commentaire.
4. **Transferts identifiés** : liste des `TRANSFERT` avec le raisonnement.
5. **Ce que le CV ne permet pas d'évaluer** : regroupement des `MANQUANT`.
6. **Éléments à vérifier** (optionnel, neutre) : questions à poser en
   entretien, formulées comme suggestions au recruteur, jamais comme
   constats.

Écrire un fichier par candidat : `workspace-candidature/output/<candidat>.md` (slug du nom, ex.
`mari-.dupont.md`). Relancer la tâche **écrase** les rapports du même
candidat (idempotent).

### 6. Vérification avant de déclarer terminé

Par rapport :
- tout critère de l'offre a un statut par CV ;
- aucun statut n'est sans preuve (extrait ou mention d'absence) ;
- aucune inférence non étiquetée ; aucun verdict de recrutement ;
- les 5 statuts sont utilisés distinctement (aucun `MANQUANT` étiqueté
  `ECART`).

## Sorties

- `workspace-candidature/output/<candidat>.md` par CV analysé.
- Rien d'autre : pas de fichier intermédiaire persistant (`workspace-candidature/.tmp/` autorisés,
  à nettoyer).

## Interdits

- Accepter, rejeter, classer ou noter globalement un candidat.
- Déduire des compétences/expériences non démontrées par le CV.
- Inventer des critères que l'offre ne mentionne pas (on peut en signaler un
  éventuel « à clarifier dans l'offre », jamais l'appliquer comme exigence).
- Lire `workspace-candidature/evaluator/`.
- Tout appel à un système externe (ATS, web) : exécution 100 % locale.
