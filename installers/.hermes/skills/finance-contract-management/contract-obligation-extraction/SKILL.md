---
name: contract-obligation-extraction
description: "Méthode d'extraction des obligations contractuelles d'un corpus de documents (contrat + annexes PDF/XLSX) : classification par partie, déclencheurs, échéances, conflits, ambiguïtés, traçabilité source. À utiliser pour construire un registre d'obligations traçable."
---

# Contract Obligation Extraction

Méthodologie de lecture d'un corpus contractuel et d'extraction d'obligations
traçables. Ne contient aucune donnée de projet : les entrées (documents, parties,
règles de préséance) proviennent du corpus lui-même.

## 1. Avant d'extraire : le référentiel

1. Lire les **définitions** du contrat (abréviations, unités de temps : jours
   ouvrés, mois contractuels, jalons).
2. Lire la clause d'**ordre de préséance** des documents. C'est la règle de
   résolution des conflits ; la consigner avant toute extraction.
3. Identifier les **parties** et leurs acronymes.

Sans ces trois éléments, noter le manquement et poursuivre avec prudence
(confiance réduite), sans inventer de règle.

## 2. Unité d'extraction

Une **obligation** = une exigence d'action (ou d'abstention) imputable à une
partie, supportée par une source. Critères :

- elle désigne une action vérifiable (fournir, notifier, maintenir, organiser,
  confirmer, conserver, soumettre à approbation…) ;
- elle est imputable : Titulaire, Autorité Contractante, ou conjointe ;
- elle est supportée par au moins une source du corpus.

Exclure du registre : descriptions de contexte, objectifs non actionnables,
règles de procédure interne d'un document (à consigner comme « règle » si elles
conditionnent d'autres obligations).

## 3. Champs obligatoires par obligation

| Champ | Règle |
|-------|-------|
| `party` | `TITULAIRE` / `AC` / `CONJOINTE`. Ne jamais déduire la partie du seul fait du document : se fonder sur le texte. |
| `obligation` | Action reformulée fidèlement, à l'infinitif, sans ajouter de contrainte. |
| `category` | Ex. : `livrable`, `revue`, `fourniture-AC`, `gouvernance`, `qualification`, `soutien`, `formation`, `cybersecurite`, `configuration`, `essai`, `autre`. |
| `trigger` | Événement déclencheur (jalon, réception, identification d'un risque, dépôt, revue…). |
| `deadline` | Conserver la **forme contractuelle** : « 10 JO avant PDR », « M5 », « 45 jours calendaires après DE », « mensuel M6→CDR ». Ne pas convertir en date exacte si le calcul exige un calendrier non disponible (jours fériés). |
| `deliverable` | Livrable ou preuve attendue (réf. CDRL, format, index…). |
| `source_doc` | Document du corpus. |
| `source_locator` | Section/§, feuille, ligne ou ID (ex. : `§4.2`, `Annexe B!CDRL-014`, `Annexe C!GFE-GFI!GFE-02`). |
| `confidence` | `HAUTE` : texte explicite. `MOYENNE` : obligation déduite d'une référence croisée (ex. « selon Annexe A §A5 »). `BASSE` : interprétation — l'expliquer dans `notes`. |

## 4. Règles de lecture

- **Explicite ET conditionnelle** : « tout X doit être notifié dans les N JO »
  est une obligation conditionnelle ; le déclencheur est la condition.
- **Périodicités** : mensuel, trimestriel, « à chaque revue », « pendant toute la
  durée » — à consigner telles quelles.
- **Cible vs effective** : un jalon « cible » (acceptation cible, date de
  planification) n'est pas une date effective. Conserver le déclencheur contractuel
  et marquer la cible comme telle (`kind=CIBLE` dans les jalons).
- **JO vs jours calendaires** : ne jamais mélanger. Un délai en JO dépend d'un
  calendrier de jours fériés ; s'il est absent du corpus, le signaler comme
  information manquante.
- **Silence = défaut** : « à défaut, réputé accepté » est une règle à consigner
  dans l'obligation concernée.

## 5. Conflits

Un **conflit** = deux sources imposent des règles incompatibles sur le même objet
(délai différent, partie différente, contenu différent).

1. Identifier les deux sources et le point exact de divergence.
2. Appliquer l'ordre de préséance s'il tranche.
3. **Consigner le conflit dans tous les cas** (même tranché) : description,
   sources, préséance appliquée, règle retenue.
4. Si la préséance ne tranche pas : statut `AMBIGUE`, soumettre à validation
   humaine, ne pas choisir.

Une divergence de détail résolvable sans contradiction n'est pas un conflit
(consigner comme note si utile).

## 6. Ambiguïtés et manques

- **Ambiguïté** : plusieurs lectures raisonnables (ex. : deux livrables distincts
  qui pourraient s'appliquer à la même revue). Lister les lectures possibles.
- **Manque** : information attendue mais absente (calendrier fériés, référence
  non résolue). Conséquence à énoncer (ex. : « date exacte du délai en JO non
  calculable »).
- Ne jamais combler par connaissance métier externe.

## 7. Dédoublonnage

- Une obligation = une ligne. Si deux sources disent la même chose : une ligne,
  sources multiples dans `source_doc`/`source_locator`.
- Si une source renvoie à une autre (« selon Annexe A §A5 ») : une seule ligne,
  référence croisée notée, confiance `MOYENNE`.
- Si deux sources divergent : une ligne avec la règle retenue + entrée `conflicts`.

## 8. Contrôle qualité minimal avant restitution

- Aucune obligation sans `source_doc` + `source_locator`.
- Chaque `party` justifiée par le texte.
- Chaque conflit connu du corpus consigné.
- Chaque délai en JO non converti en date exacte.
- Comptage par partie et par catégorie produit (base de la synthèse).
