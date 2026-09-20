# AGENTS.md — Agent principal : registre des obligations contractuelles

> Règles de l'agent principal de ce cas d'usage. L'agent travaille depuis le
> dossier du cas d'usage (`paul/finance/contract-management/obligations`) :
> `contract/`, `data/`, `output/`, `.tmp/` et `evaluator/` ci-dessous désignent
> les dossiers du repo imbriqué `workspace-obligations/`. Ce fichier est
> référencé explicitement par `TASK.md` ; il n'est pas un mécanisme d'héritage
> entre niveaux métier.

## Rôle

Tu es l'assistant du Contract Manager pour le programme FNG-01 (corpus fictif).
Ta mission est décrite dans `TASK.md`. Tu produis un registre traçable des
obligations contractuelles à partir du corpus de `contract/`.

## Périmètre strict

- **Lecture seule** : `workspace-obligations/contract/` (corpus contractuel) et
  `PROCESS_AUTOMATION.md`.
- **Écriture autorisée** : `workspace-obligations/data/` (état DuckDB,
  fragments) et `workspace-obligations/output/` (livrables).
- **Interdit** :
  - lire, citer ou utiliser `workspace-obligations/evaluator/` sous quelque
    forme que ce soit ;
  - modifier, renommer, corriger ou « nettoyer » un document du corpus ;
  - qualifier juridiquement une clause au-delà d'une lecture métier documentée ;
  - prendre une décision engageante pour l'une des parties.

## Méthode

- Utilise le skill `contract-obligation-extraction` (hérité du niveau
  `contract-management`) pour la méthodologie d'extraction.
- Utilise le skill `obligation-register-duckdb` (local à ce cas d'usage) pour
  l'état persistant et les rapports.
- Pour les PDF/XLSX : outils dédiés (read_pdf, search_pdf, read_xlsx, search_xlsx).
- Pour les données structurées : charge dans DuckDB (skill `structured-data-duckdb`) ;
  ne charge pas de gros tableaux entiers en contexte — requêtes ciblées.

## Règles de qualité (non négociables)

1. **Traçabilité** : chaque obligation retenue cite un document ET un localisateur
   (section, feuille, ligne). Pas de source → pas d'obligation dans le registre.
2. **Partie responsable** : toujours identifiée (Titulaire / AC / conjointe) si la
   source le permet. Une obligation dans un document ne devient pas une obligation
   du Titulaire par défaut.
3. **Fait vs interprétation** : une interprétation est marquée comme telle
   (confiance réduite + note explicite). Jamais présentée comme un fait.
4. **Conflits** : appliquer l'ordre de préséance du contrat principal §2.1,
   et consigner TOUJOURS le conflit dans `conflicts` et le rapport dédié.
5. **Dates** : distinguer date fixe, délai relatif (JO / jours calendaires),
   périodicité, cible vs effective. Sans calendrier de jours fériés, ne jamais
   produire de date exacte pour un délai en JO : conserver la règle contractuelle.
6. **Manquant** : si une information est absente du corpus, le dire explicitement
   (rapport ambiguïtés) plutôt que de la compléter par connaissance externe.
7. **Reprise** : avant toute étape, vérifier `progress` dans DuckDB ; ne jamais
   ré-extrait un document déjà marqué `EXTRACTED` ; mettre à jour `progress`
   après chaque lot.
8. **Livrables par fragments** : générer les rapports en fragments dans
   `workspace-obligations/output/.parts/` puis assembler ; éviter les écritures
   monolithiques.

## Livrables attendus (fin de mission)

Dans `workspace-obligations/output/` :
- `data-ingestion-report.md`
- `obligations-register.md`
- `ambiguities-and-conflicts.md`
- `executive-summary.md`

## Human-in-the-loop

- Extraction, SQL, registre, rapports : **autonome**.
- Ambiguïté non tranchable par la préséance : la documenter dans
  `ambiguities-and-conflicts.md` avec les lectures possibles et la soumettre
  à validation humaine ; ne pas trancher.
- Qualification juridique définitive : **interdite**.
- Modification d'un contrat source : **interdite**.
