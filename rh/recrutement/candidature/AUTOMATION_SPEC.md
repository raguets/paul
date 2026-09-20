# AUTOMATION_SPEC — candidature

Spécification de l'automatisation : architecture, données, statuts, format de
sortie. Références : `USE_CASE.md` (métier), `TASK.md` (exécution),
`.agents/skills/analyse-candidature/SKILL.md` (logique).

## Architecture (create-use-case)

- Cas d'usage `candidature` dans le monorepo `paul`, sous `rh/recrutement/` :
  `TASK.md`, `USE_CASE.md`, ce fichier et le skill local
  `.agents/skills/analyse-candidature/`.
- Données métier dans le repo Git **indépendant** imbriqué
  `workspace-candidature/` : `input/`, `output/`, `evaluator/`.
- Héritage structurel des skills : `rh/recrutement/` → `rh/` → `paul/`.
- Exécution **100 % locale/offline** ; pas de dépendance réseau, pas de ATS.
- Skills utilisés : `analyse-candidature` (local) ; `document-processing` +
  `office` (communs) pour l'extraction de texte / OCR.

## Données

| Emplacement | Contenu | Droits agent |
|---|---|---|
| `workspace-candidature/input/` | offre + CV (PDF/DOCX), déposés par le recruteur | lecture seule |
| `workspace-candidature/output/` | rapports `<candidat>.md` | écriture |
| `workspace-candidature/.tmp/` | fichiers temporaires | lecture/écriture, à nettoyer |
| `workspace-candidature/evaluator/` | critères d'acceptation / ground truth | **jamais** |

Aucun état persistant entre exécutions (runs one-shot, idempotent).

## Statuts de comparaison (un seul par critère × CV)

`CORRESPOND` · `PARTIEL` · `ECART` · `MANQUANT` · `TRANSFERT`

Invariants :
- `MANQUANT` (absence d'information) ≠ `ECART` (non-correspondance) ;
- aucun statut sans preuve (extrait verbatim, ou mention d'absence pour
  `MANQUANT`) ;
- `TRANSFERT` toujours étiqueté comme hypothèse de rapprochement, avec son
  raisonnement ;
- aucun fait non démontré par le CV n'est présenté comme acquis.

## Format du rapport `workspace-candidature/output/<candidat>.md`

```markdown
# Analyse d'adéquation — <Candidat> ↔ <Titre de l'offre>

> Aide à l'analyse pour le recruteur. La décision de recrutement appartient
> au recruteur : aucun verdict, aucune note, aucune décision automatique.
> Offre : <fichier …/input/…> · CV : <fichier …/input/…> · Date : <AAAA-MM-JJ>

## 1. Lecture d'ensemble
2–5 lignes qualitatives (forces, faiblesses, points d'attention). Pas de score.

## 2. Correspondance avec l'offre
| # | Critère (nature) | Statut | Preuve (extrait CV) | Commentaire |
|---|---|---|---|---|
| 1 | <critère> (exigé) | CORRESPOND | « <extrait verbatim CV> » | <précis, bref> |
| … | … | … | … | … |

## 3. Compétences / expériences transférables
- **<transfert>** : <élément du CV> → <critère de l'offre> —
  « <extrait CV> » — rapprochement : <raisonnement>.
(si rien : « Aucun transfert identifié. »)

## 4. Ce que le CV ne permet pas d'évaluer
- <critère> : le CV ne contient aucune information à ce sujet.
(si rien : « Aucun. »)

## 5. Éléments à vérifier en entretien (suggestions)
- <question neutre>
(section optionnelle — suggestions au recruteur, jamais des constats)
```

Règles de nommage : `workspace-candidature/output/<slug-candidat>.md`, slug = nom du candidat
minuscules, tirets (ex. `marie-dupont.md`). Ré-exécution : écrasement du même
fichier (idempotent).

## Critères d'acceptation

Voir `workspace-candidature/evaluator/ACCEPTANCE.md`.
