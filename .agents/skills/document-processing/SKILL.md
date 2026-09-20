---
name: document-processing
description: Traite des documents métier locaux en choisissant la stratégie la plus efficace entre extraction texte, OCR sélectif, recherche ciblée, inspection visuelle et traitement structuré. Utilise en priorité @siva-sub/pi-docparser pour les PDF et documents nécessitant OCR/inspection visuelle, pi-office pour certains formats Office si utile, et évite de charger de gros documents entiers dans le contexte.
---

# Document Processing

## Mission

Fournir une capacité générique de lecture et d'analyse documentaire pour les automatisations métier.

Le skill doit :

1. choisir le bon outil selon le format et le besoin ;
2. préférer l'extraction native à l'OCR lorsqu'une couche texte exploitable existe ;
3. utiliser l'OCR automatiquement lorsque le document ou certaines pages en ont besoin ;
4. éviter de convertir manuellement un PDF en images page par page sauf nécessité explicite ;
5. rechercher et cibler avant de charger de gros contenus ;
6. conserver la traçabilité vers le document et les pages ;
7. préserver les documents source en lecture seule.

# 1. Outils principaux

## @siva-sub/pi-docparser

Utiliser en priorité pour :

- PDF texte ;
- PDF scanné ;
- PDF mixte texte + scans ;
- documents dont la mise en page ou les coordonnées sont importantes ;
- recherche de texte avec localisation ;
- pages contenant graphiques, figures, signatures, tableaux complexes ou éléments visuels ;
- OCR local.

Outils disponibles :

```text
document_parse
document_search
document_screenshot
document_complexity
document_visual_analyze
```

## pi-office

Utiliser lorsque c'est plus direct ou déjà adapté au workflow pour :

- DOCX ;
- XLSX ;
- lecture simple de documents Office ;
- inspection rapide de feuilles/classeurs avant traitement structuré.

Pour les gros XLSX destinés à des calculs, filtres, jointures ou agrégations, préférer ensuite une capacité de données structurées telle que DuckDB plutôt que de charger tout le classeur dans le contexte.

# 2. Règle de sélection

```text
Document
   │
   ├── PDF
   │    └── pi-docparser
   │         ├── document_parse
   │         ├── OCR auto si nécessaire
   │         ├── document_search pour cibler
   │         └── screenshot/visual analysis si nécessaire
   │
   ├── DOC/DOCX/ODT/RTF
   │    ├── pi-office si lecture simple suffisante
   │    └── pi-docparser si OCR, pages ciblées,
   │        structure ou inspection visuelle sont utiles
   │
   ├── XLS/XLSX/CSV
   │    ├── pi-office pour comprendre la structure
   │    └── outil de données structurées pour l'analyse volumineuse
   │
   └── Image
        └── pi-docparser / OCR local
```

Ne pas utiliser plusieurs outils sans raison.

# 3. PDF : stratégie par défaut

Pour un PDF, commencer par `document_parse`.

```text
document_parse({
  path: "<document.pdf>"
})
```

Ne pas commencer par convertir toutes les pages en PNG.

Si l'objectif est simplement de résumer, lire une clause, répondre à une question ou extraire du texte, l'extraction texte est le premier choix.

# 4. OCR automatique

Pour un PDF potentiellement scanné ou mixte :

```text
document_parse({
  path: "<document.pdf>",
  ocr: "auto",
  ocrLanguage: "fra"
})
```

Pour l'anglais :

```text
ocrLanguage: "eng"
```

L'OCR doit rester sélectif :

- ne pas OCRiser inutilement les pages possédant déjà un texte exploitable ;
- laisser le moteur identifier les pages ou régions pauvres en texte lorsque le mode automatique le permet ;
- ne pas construire manuellement un pipeline PDF → images → OCR sauf si l'outil principal échoue.

Pour un environnement hors ligne avec données Tesseract spécifiques, utiliser si nécessaire :

```text
tessdataPath: "<local tessdata path>"
```

# 5. Gros documents : ne pas tout charger dans le contexte

Pour un document volumineux :

1. déterminer ce que l'on cherche ;
2. utiliser `document_search` lorsque des termes ou expressions sont connus ;
3. utiliser `targetPages` pour limiter le parsing ;
4. ne lire le résultat complet que si nécessaire ;
5. traiter par groupes de pages lorsque l'analyse est longue.

```text
document_parse({
  path: "<document.pdf>",
  format: "json",
  targetPages: "20-30"
})
```

# 6. Recherche avant screenshot

Pour une clause, un terme ou une phrase connue :

```text
document_search({
  path: "<document.pdf>",
  phrase: "<texte recherché>",
  targetPages: "<plage si connue>"
})
```

Utiliser les résultats pour retrouver les pages pertinentes et limiter les screenshots.

# 7. Inspection visuelle

Utiliser `document_screenshot` lorsque l'information dépend réellement de la présentation visuelle :

- graphique ;
- figure ;
- signature ;
- schéma ;
- tableau dense ou mal extrait ;
- tampon ;
- mise en page porteuse de sens ;
- texte OCR incertain nécessitant vérification visuelle.

```text
document_screenshot({
  path: "<document.pdf>",
  pages: "4",
  dpi: 150
})
```

# 8. Détection de complexité

Pour un PDF long avec contenu visuel potentiel :

```text
document_complexity({
  path: "<document.pdf>"
})
```

Le score sert à décider où regarder, pas quoi conclure.

# 9. Analyse visuelle par modèle

Utiliser `document_visual_analyze` seulement lorsque :

- l'information ne peut pas être obtenue correctement par extraction/OCR ;
- une compréhension graphique est réellement nécessaire ;
- un modèle vision compatible est disponible.

En environnement local/offline :

- préférer un endpoint local ;
- garder `allowCloud: false` ;
- ne pas activer d'appel distant sans demande explicite.

```text
document_visual_analyze({
  path: "<document.pdf>",
  pages: "3,7",
  focus: "<question visuelle>",
  baseUrl: "http://127.0.0.1:<port>/v1",
  model: "<local vision model>",
  allowCloud: false
})
```

Les conclusions du modèle vision sont des inférences. Pour les citations textuelles, les compléter avec `document_search` ou les coordonnées JSON.

# 10. Sortie JSON et coordonnées

Utiliser :

```text
format: "json"
```

quand l'automatisation a besoin de :

- numéros de page ;
- coordonnées ;
- bounding boxes ;
- éléments textuels séparés ;
- traitement programmatique ;
- traçabilité précise.

# 11. Documents Office

Stratégie recommandée :

```text
DOCX simple
→ pi-office

DOCX nécessitant structure visuelle / pages / conversion avancée
→ pi-docparser

XLSX à inspecter
→ pi-office

XLSX à analyser à grande échelle
→ pi-office pour la structure
→ DuckDB / structured-data capability pour les données
```

Ne pas faire de parsing ligne par ligne d'un gros XLSX dans le contexte du LLM.

# 12. Dépendances hôte

Si `pi-docparser` échoue sur une conversion :

1. ne pas inventer la cause ;
2. utiliser `/docparser:doctor` si disponible ;
3. vérifier les dépendances signalées ;
4. informer l'utilisateur uniquement si une dépendance réellement nécessaire manque.

Des conversions Office peuvent nécessiter LibreOffice.
Certains chemins de conversion d'images peuvent nécessiter ImageMagick.

Ne pas installer automatiquement une dépendance système sans autorisation.

# 13. Fichiers temporaires

Les outils documentaires peuvent produire des fichiers temporaires contenant texte extrait, JSON, screenshots ou conversions intermédiaires.

- traiter ces fichiers comme temporaires ;
- ne pas copier automatiquement leur contenu intégral dans le workspace ;
- ne pas charger un gros fichier temporaire entièrement dans le contexte si une lecture ciblée suffit ;
- respecter la politique locale de permissions sur les répertoires temporaires.

# 14. Source preservation

Les documents source sont en lecture seule par défaut.

Ne jamais :

- modifier le PDF original ;
- réenregistrer un XLSX source ;
- remplacer un scan par une version OCR ;
- normaliser silencieusement un document original ;
- supprimer un fichier source.

# 15. Traçabilité

Pour toute information importante, conserver autant que possible :

```text
document
page
section / phrase / locator
méthode d'extraction si utile
confiance ou incertitude si OCR/vision
```

# 16. OCR et confiance

Lorsque le résultat OCR contient des valeurs critiques (dates, nombres, références, noms, identifiants, tableaux), vérifier visuellement ou recouper lorsque l'exactitude est importante.

Ne pas corriger silencieusement une valeur OCR incertaine.

# 17. Performance

Ordre de coût croissant recommandé :

```text
1. document_search ciblé
2. document_parse texte
3. document_parse ciblé / JSON
4. OCR auto
5. screenshot ciblé
6. analyse vision ciblée
```

Choisir la méthode la moins coûteuse capable de répondre correctement.

# 18. Workflow recommandé

```text
1. Identifier format et objectif
        ↓
2. document_parse / pi-office
        ↓
3. Texte suffisant ?
    ├── oui → continuer
    └── non
         ↓
4. OCR auto si scan / texte pauvre
         ↓
5. Besoin de localisation précise ?
    ├── oui → search / JSON
    └── non
         ↓
6. Information visuelle importante ?
    ├── non → continuer
    └── oui
         ↓
7. complexity → pages candidates
         ↓
8. screenshot ciblé
         ↓
9. visual_analyze seulement si nécessaire
```

# 19. Comportements interdits

Ne pas :

- découper systématiquement les PDF en images avant OCR ;
- OCRiser toutes les pages lorsqu'une couche texte exploitable existe ;
- prendre des screenshots de tout un document sans besoin ;
- charger un énorme résultat parse dans le contexte ;
- envoyer un document vers un service cloud sans autorisation explicite ;
- utiliser une analyse vision comme citation textuelle ;
- modifier les documents source ;
- inventer le contenu d'une page mal OCRisée ;
- retraiter plusieurs fois le même document sans raison.

# 20. Priorité

```text
exactitude
→ traçabilité
→ extraction native
→ OCR ciblé
→ inspection visuelle ciblée
→ efficacité de contexte
```
