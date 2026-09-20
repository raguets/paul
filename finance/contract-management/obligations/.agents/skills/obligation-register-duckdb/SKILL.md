---
name: obligation-register-duckdb
description: "État persistant DuckDB pour un registre d'obligations contractuelles : schéma, lots d'extraction, reprise après interruption, croisement planning, génération des rapports markdown par fragments puis assemblage."
---

# Obligation Register — DuckDB

État persistant et génération des livrables pour un registre d'obligations
contractuelles. La base DuckDB est la **source de vérité** ; les rapports
markdown sont des vues dérivées régénérables.

## 1. Emplacement (relatif au dossier du cas d'usage)

Les données vivent dans le repo imbriqué `workspace-obligations/` :

- Base : `workspace-obligations/data/obligations.duckdb`
- Fragments de rapports : `workspace-obligations/output/.parts/`
- Livrables finaux : `workspace-obligations/output/*.md`

## 2. Schéma

```sql
CREATE TABLE IF NOT EXISTS documents(
  doc_id TEXT PRIMARY KEY,        -- ex. '01-contrat-principal'
  path TEXT NOT NULL,
  doc_type TEXT,                  -- PDF | XLSX
  contract_ref TEXT,              -- ex. 'ACN-FNG-2026-001'
  version TEXT,
  status TEXT DEFAULT 'NEW'       -- NEW | INGESTED | ERROR
);

CREATE TABLE IF NOT EXISTS milestones(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  date DATE,
  kind TEXT DEFAULT 'CONTRACTUELLE',  -- CONTRACTUELLE | CIBLE | INDICATIF
  source_doc TEXT
);

CREATE TABLE IF NOT EXISTS obligations(
  id TEXT PRIMARY KEY,           -- ex. 'OBL-0001'
  party TEXT NOT NULL,           -- TITULAIRE | AC | CONJOINTE
  obligation TEXT NOT NULL,
  category TEXT,
  trigger TEXT,
  deadline TEXT,                 -- forme contractuelle, jamais de date inventée
  deliverable TEXT,
  source_doc TEXT NOT NULL,
  source_locator TEXT NOT NULL,
  confidence TEXT DEFAULT 'HAUTE', -- HAUTE | MOYENNE | BASSE
  status TEXT DEFAULT 'EXTRAITE',  -- EXTRAITE | VALIDEE | EN_CONFLIT | AMBIGUE
  notes TEXT
);

CREATE TABLE IF NOT EXISTS conflicts(
  id TEXT PRIMARY KEY,           -- 'CONF-001'
  description TEXT NOT NULL,
  source_a TEXT NOT NULL,
  source_b TEXT NOT NULL,
  precedence_applied TEXT,
  resolution TEXT,
  status TEXT DEFAULT 'OUVERT'   -- OUVERT | TRANCHE_PAR_PRESEANCE | VALIDATION_HUMAINE
);

CREATE TABLE IF NOT EXISTS ambiguities(
  id TEXT PRIMARY KEY,           -- 'AMBIG-001'
  description TEXT NOT NULL,
  source_doc TEXT,
  readings TEXT,                 -- lectures possibles, séparées par ';'
  status TEXT DEFAULT 'OUVERT'
);

CREATE TABLE IF NOT EXISTS progress(
  doc_id TEXT NOT NULL,
  stage TEXT NOT NULL,           -- INGESTED | EXTRACTED | CROSSED | REPORTED
  status TEXT DEFAULT 'DONE',
  updated_at TEXT DEFAULT (strftime(now(),'YYYY-MM-DD HH24:MI:SS')),
  PRIMARY KEY (doc_id, stage)
);
```

## 3. Lots et reprise

- Un **lot** = un document (ou une feuille XLSX pour les gros classeurs).
- Avant de traiter un document :
  `SELECT stage FROM progress WHERE doc_id='…'` — sauter les étapes déjà `DONE`.
- Après chaque lot : insérer la ligne `progress` correspondante.
- Les insertions d'obligations sont idempotentes par `id` (INSERT … ON CONFLICT
  DO NOTHING) : une réexécution ne duplique pas.
- Ne jamais vider une table pour « recommencer » : corriger ligne par ligne
  (UPDATE/DELETE ciblé) et documenter la correction dans `notes`.

## 4. Requêtes de contrôle (à exécuter avant les rapports)

```sql
-- traçabilité : aucune obligation sans source
SELECT id FROM obligations WHERE source_doc IS NULL OR source_locator IS NULL
  OR source_doc='' OR source_locator='';

-- couverture par partie / catégorie / confiance
SELECT party, COUNT(*) FROM obligations GROUP BY 1;
SELECT category, COUNT(*) FROM obligations GROUP BY 1 ORDER BY 2 DESC;
SELECT confidence, COUNT(*) FROM obligations GROUP BY 1;

-- conflits et ambiguïtés ouverts
SELECT * FROM conflicts WHERE status != 'TRANCHE_PAR_PRESEANCE';
SELECT * FROM ambiguities WHERE status = 'OUVERT';
```

## 5. Génération des rapports par fragments

Règle : aucun rapport > quelques dizaines de lignes en une seule écriture.

1. Produire les fragments dans `workspace-obligations/output/.parts/` :
   - registre : un fragment **par catégorie** (ou par tranche de ~25 lignes) ;
   - conflits : un fragment par section (conflits / ambiguïtés / manques) ;
   - synthèse et ingestion : un seul fragment chacun (courts).
2. Chaque fragment provient d'une requête SQL ciblée (pagination si besoin),
   pas d'une relecture des documents source.
3. Assemblage déterministe : en-tête commun + fragments dans l'ordre des
   catégories ; écrire le fichier final dans `workspace-obligations/output/`.
4. Conserver `.parts/` (utile à la reprise) ; le registre final est
   régénérable depuis DuckDB à tout moment.

## 6. Colonnes du registre (vue finale)

| ID | Partie responsable | Obligation | Catégorie | Déclencheur | Échéance / périodicité | Livrable / preuve | Source | Confiance |

`Source` = `doc_id` + localisateur (ex. : `01-contrat-principal §4.2`,
`03-annexe-b-livrables-cdrl!CDRL-014`).

## 7. Rappels

- La base est la source de vérité ; un rapport n'est jamais la seule trace.
- Ne pas charger de gros tableaux entiers en contexte : projections, filtres,
  compteurs, pagination.
- Toute date produite doit être soit une date du corpus, soit une règle
  contractuelle non convertie ; jamais une date calculée avec un calendrier
  non disponible.
