---
name: structured-data-duckdb
description: Inspecte des classeurs XLSX avec pi-office, charge les tables utiles dans DuckDB via pi-alchemy, recupere leur schema, valide un echantillon puis utilise SQL pour filtrer, joindre et agreger les donnees sans charger de gros tableaux dans le contexte du LLM.
---

# Structured Data -> DuckDB

Utiliser ce skill lorsqu'une tache implique des donnees structurees dans des fichiers XLSX/CSV/TSV/Parquet/JSON, en particulier lorsqu'il faut les croiser, filtrer, compter, agreger ou joindre.

## Objectif

Le LLM orchestre les outils. Il ne doit pas lire des milliers de cellules dans son contexte lorsqu'une requete SQL peut faire le travail deterministe.

Flux obligatoire pour XLSX :

```text
XLSX
 -> pi-office : comprendre feuilles, titres, zone tabulaire et en-tetes
 -> pi-alchemy/alchemy_query : DESCRIBE read_xlsx(...)
 -> pi-alchemy/alchemy_query : CREATE OR REPLACE TABLE ... AS SELECT ... FROM read_xlsx(...)
 -> pi-alchemy/alchemy_schema : verifier colonnes et types
 -> pi-alchemy/alchemy_query : SELECT ... LIMIT 10
 -> requetes SQL metier
```

## Regles imperatives

1. Ne jamais modifier le fichier XLSX source.
2. Inspecter d'abord le classeur avec pi-office lorsque la structure n'est pas triviale.
3. Ne pas supposer que la premiere feuille est la bonne.
4. Ne pas supposer que la ligne 1 contient les en-tetes.
5. Identifier explicitement : fichier, feuille, plage et ligne d'en-tete.
6. Avant import definitif, demander a DuckDB le schema infere avec `DESCRIBE`.
7. Apres import, appeler `alchemy_schema` et executer un `SELECT * ... LIMIT 10`.
8. Si le schema ou l'echantillon est incoherent, corriger `sheet`, `range` ou `header` et recommencer.
9. Utiliser SQL pour les tris, filtres, agrégations et jointures ; ne remonter au LLM que les lignes necessaires.
10. Toujours conserver la provenance. Lors d'une creation de table, ajouter si utile des colonnes litterales `_source_file` et `_source_sheet`.
11. Ne jamais fabriquer une valeur manquante. Conserver NULL et signaler les lacunes.
12. Pour les dates, verifier que DuckDB les a bien inferees comme DATE/TIMESTAMP. Sinon effectuer un cast explicite seulement si le format est non ambigu.
13. Si une feuille contient plusieurs tableaux independants, creer une table DuckDB par zone tabulaire.
14. Si `read_xlsx` n'est pas disponible, tenter `INSTALL excel; LOAD excel;` via `alchemy_query`, puis reessayer. Si cela echoue, signaler l'echec plutot que d'inventer une conversion.

## Exemples de tool calls SQL

### Inspecter le schema d'une feuille avant import

```sql
DESCRIBE
SELECT *
FROM read_xlsx(
  'contract/03-annexe-b-livrables-cdrl.xlsx',
  sheet = 'CDRL',
  header = true
);
```

### Creer la table

```sql
CREATE OR REPLACE TABLE cdrl AS
SELECT
  *,
  'contract/03-annexe-b-livrables-cdrl.xlsx' AS _source_file,
  'CDRL' AS _source_sheet
FROM read_xlsx(
  'contract/03-annexe-b-livrables-cdrl.xlsx',
  sheet = 'CDRL',
  header = true
);
```

### Verifier apres import

Appeler ensuite :

```text
alchemy_schema(table="cdrl")
```

puis :

```sql
SELECT * FROM cdrl LIMIT 10;
```

## Nommage des tables

Utiliser des noms courts, stables et SQL-safe :

- `cdrl`
- `gfe_gfi`
- `joint_reviews`
- `milestones`
- `training`
- `planning_assumptions`

Eviter les noms dependants de la langue ou contenant espaces/accents.

## Validation relationnelle

Avant une jointure :

1. verifier les colonnes de jointure des deux tables ;
2. compter les NULL ;
3. controler les doublons de cle ;
4. faire une petite jointure de verification ;
5. seulement ensuite executer l'analyse complete.

Exemple :

```sql
SELECT ID, COUNT(*) AS n
FROM cdrl
GROUP BY ID
HAVING COUNT(*) > 1;
```

## Fin de traitement

Dans la reponse finale, indiquer quelles feuilles ont ete chargees, sous quels noms de tables, et signaler tout probleme d'inference ou de qualite des donnees.
