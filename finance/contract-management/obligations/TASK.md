# TASK — Mission : construire le registre des obligations contractuelles FNG-01

> Cette mission s'exécute **depuis le dossier du cas d'usage**
> `paul/finance/contract-management/obligations`. Les chemins
> `workspace-obligations/contract/`, `workspace-obligations/data/`,
> `workspace-obligations/output/` et `workspace-obligations/.tmp/` ci-dessous
> sont relatifs à ce dossier ; `workspace-obligations/` est un repo Git
> indépendant imbriqué, qui porte toutes les données métier.

## Contexte

Corpus contractuel fictif (programme de deux frégates FNG-01/FNG-02) dans
`workspace-obligations/contract/` : contrat principal (PDF), Annexe A
spécification technique (PDF), Annexe B livrables CDRL (XLSX), Annexe C
responsabilités et GFE/GFI (XLSX), Annexe D planning contractuel (XLSX).

Tu dois produire le registre des obligations contractuelles exploitable par un
Contract Manager, conforme aux règles d'`AGENTS.md` (dans ce dossier), à lire
avant de commencer. Fichiers temporaires : `workspace-obligations/.tmp/`
uniquement.

## Étape 0 — Reprise

1. Si `workspace-obligations/data/obligations.duckdb` existe, ouvrir DuckDB,
   lire `progress` et reprendre à la première étape non terminée. Sinon,
   initialiser la base (schéma du skill `obligation-register-duckdb`).
2. Ne jamais ré-extraire un document déjà `EXTRACTED` sans raison documentée.

## Étape 1 — Inventaire et ingestion

1. Lister `workspace-obligations/contract/` (5 documents attendus) ; remplir
   `documents`.
2. Lire le contrat principal : définitions (§1) et ordre de préséance (§2).
3. Charger les 3 XLSX dans DuckDB (skill `structured-data-duckdb`) ; vérifier
   un échantillon de chaque feuille.
4. Produire `workspace-obligations/output/data-ingestion-report.md`
   (fragments puis assemblage) : inventaire, formats, volumes, anomalies.
5. Marquer chaque document `INGESTED` dans `progress`.

## Étape 2 — Extraction des obligations (par lots, un document à la fois)

Pour chaque document (méthodologie du skill `contract-obligation-extraction`,
hérité du niveau `contract-management`) :
1. Extraire les obligations explicites ET conditionnelles.
2. Pour chacune : partie responsable, action, déclencheur, échéance/périodicité,
   livrable/preuve, source (document + localisateur), confiance.
3. Insérer dans `obligations` ; marquer `progress` = `EXTRACTED` pour le document.

Ordre recommandé : contrat principal → Annexe A → Annexe B → Annexe C → Annexe D.

## Étape 3 — Croisement planning

1. Charger les jalons dans `milestones` (marquer `CIBLE` pour A1/A2,
   `INDICATIF` pour les rappels GFE/GFI de l'Annexe D).
2. Rattacher à chaque obligation son échéance : date fixe, délai relatif
   (JO / jours calendaires avant/après événement), périodicité (Mx, mensuel,
   trimestriel). Ne pas convertir en date exacte un délai en JO.
3. Marquer `progress` = `CROSSED`.

## Étape 4 — Conflits, ambiguïtés, dédoublonnage

1. Détecter les contradictions entre documents (mêmes objets, règles divergentes) ;
   appliquer la préséance §2.1 ; consigner dans `conflicts` (statut `EN_CONFLIT`
   sur les obligations concernées).
2. Consigner les ambiguïtés (lectures multiples, cibles vs effectifs, JO sans
   calendrier fériés) dans `ambiguities` ; ne pas trancher celles qui ne le
   sont pas par préséance.
3. Dédoublonner : une obligation = une ligne ; vérifier qu'aucune ligne n'est
   sans source.

## Étape 5 — Livrables finaux (fragments puis assemblage)

Dans `workspace-obligations/output/` :
1. `obligations-register.md` — toutes les colonnes requises, triées par
   catégorie puis partie ; obligations conjointes explicitement marquées.
2. `ambiguities-and-conflicts.md` — conflits (avec préséance appliquée),
   ambiguïtés, informations manquantes, points de validation humaine.
3. `executive-summary.md` — totaux par partie/catégorie/confiance, top points
   de vigilance, couverture des obligations AC.
4. Marquer `progress` = `REPORTED` pour tous les documents.

## Définition de « terminé »

- Les 4 livrables existent dans `workspace-obligations/output/` et sont assemblés.
- Chaque obligation du registre cite une source (vérification SQL :
  aucune ligne avec source vide).
- Les conflits préparés du corpus sont détectés et consignés.
- Les obligations de l'AC sont présentes et comptabilisées.
- `progress` est complet ; une réexécution ne ré-extrait rien.
- Aucun accès à `workspace-obligations/evaluator/`.
