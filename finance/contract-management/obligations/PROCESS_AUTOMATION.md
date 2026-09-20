# PROCESS_AUTOMATION — POC Contract Management / Registre des obligations

## 1. Objectif métier

Construire automatiquement un registre traçable des obligations contractuelles à partir d'un corpus de contrat industriel complexe.

Le POC doit démontrer qu'un agent peut :
- lire le contrat et ses annexes ;
- extraire les obligations explicites et conditionnelles ;
- distinguer Titulaire / Autorité Contractante / obligations conjointes ;
- retrouver échéances et déclencheurs ;
- identifier ambiguïtés et conflits documentaires ;
- produire un registre exploitable par un contract manager.

Succès attendu :
- bonne couverture des obligations de référence ;
- aucune obligation sans source ;
- peu de faux positifs ;
- détection des principaux conflits préparés dans le corpus.

## 2. Utilisateurs / acteurs

Utilisateur principal : Contract Manager.

Parties :
- Autorité Contractante (AC) ;
- Titulaire.

Le Contract Manager humain valide les conclusions ambiguës ou engageantes.

## 3. Déclencheur

Pour le POC : l'utilisateur lance explicitement l'analyse du corpus contractuel.

## 4. Entrées

Corpus synthétique d'un projet fictif de frégate de nouvelle génération :

1. Contrat principal — PDF souhaité.
2. Annexe technique — PDF souhaité.
3. Annexe B / CDRL — XLSX souhaité.
4. Annexe C / responsabilités et GFE-GFI — XLSX souhaité.
5. Planning contractuel — XLSX souhaité.

Si la génération PDF/XLSX n'est pas possible localement, générer une variante Markdown/CSV équivalente et documenter la limitation.

## 5. Processus cible

1. Inventorier les documents.
2. Lire définitions et ordre de préséance.
3. Inspecter les PDF.
4. Inspecter les XLSX.
5. Utiliser DuckDB pour les données structurées.
6. Extraire les obligations par lots.
7. Persister obligations et progression.
8. Vérifier Titulaire, AC et obligations conjointes.
9. Croiser les échéances avec le planning.
10. Détecter conflits et ambiguïtés.
11. Dédupliquer.
12. Valider la traçabilité.
13. Générer les livrables finaux.

## 6. Règles de décision

Une obligation doit être supportée par une source contractuelle.

Toute obligation conserve :
- partie responsable ;
- action ;
- déclencheur ;
- échéance / périodicité ;
- source précise ;
- confiance.

En cas de contradiction :
- appliquer la préséance si elle est définie ;
- signaler malgré tout le conflit.

Une interprétation ne doit pas être présentée comme un fait.

## 7. Exceptions importantes

- Pas de calendrier des jours fériés : ne pas inventer une date exacte en jours ouvrés.
- Date cible différente d'une date effective : conserver le vrai déclencheur contractuel.
- Documents contradictoires : appliquer la préséance et créer un point de vigilance.
- Information manquante : signaler le manque.
- Interruption : reprendre depuis l'état persistant.

## 8. Sorties

Dans `workspace-obligations/output/` :

- `data-ingestion-report.md`
- `obligations-register.md`
- `ambiguities-and-conflicts.md`
- `executive-summary.md`

Le registre contient au minimum :

| ID | Partie responsable | Obligation | Catégorie | Déclencheur | Échéance / périodicité | Livrable / preuve | Source | Confiance |

## 9. Human-in-the-loop

- Lecture / extraction : AUTONOME
- SQL / DuckDB : AUTONOME
- Création du registre : AUTONOME
- Résolution d'une ambiguïté non tranchable : VALIDATION_HUMAINE
- Qualification juridique définitive : INTERDIT
- Modification d'un contrat source : INTERDIT

## 10. Systèmes / données / permissions

Environnement :
- Windows 11 ;
- Pi ;
- Qwen local via llama.cpp ;
- aucun Internet requis pour la mission ;
- pi-office pour PDF/XLSX ;
- pi-alchemy + DuckDB pour données structurées.

Corpus source en lecture seule.
Écriture dans `workspace-obligations/data/` et `workspace-obligations/output/`.

## 11. Volumétrie approximative

POC réduit :
- 5 documents ;
- quelques dizaines de lignes par XLSX ;
- environ 70 à 100 obligations.

La mission doit être reprenable après interruption.

## 12. Critères d'acceptation

- environ 80 obligations de référence dans le corpus synthétique ;
- ≥ 80 % de couverture pour un premier succès MVP ;
- chaque obligation retenue cite une source ;
- les conflits préparés sont détectés ;
- les obligations de l'AC sont couvertes ;
- aucun accès au ground truth pendant l'analyse ;
- reprise possible grâce à l'état persistant.

## 13. Données de test disponibles

Pas de données réelles.

Le bootstrap doit générer un corpus synthétique réaliste.

Inclure volontairement :
- un conflit de délai contrat principal / CDRL ;
- des obligations de l'AC ;
- des échéances relatives à des jalons ;
- des délais en jours ouvrés ;
- acceptation cible vs effective ;
- obligations périodiques.

## 14. Contraintes connues

Le POC doit rester simple.

Architecture préférée :
- un seul agent principal ;
- skills spécialisés ;
- DuckDB comme source de vérité ;
- traitement par lots ;
- pas de gros appels `write/edit`.

Les gros fichiers de restitution sont générés par fragments puis assemblés.

## 15. Questions ouvertes

Le bootstrap doit demander uniquement les compléments réellement bloquants.

S'il estime que ce document satisfait R1 à R10, il passe directement à la génération.
