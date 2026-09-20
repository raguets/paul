# Source lifecycle and change management

> Repris de `process-automation-bootstrap` V3 (§18), adapté à `create-use-case`.
> Chemins d'exécution relatifs à la racine du repo workspace.

Lorsqu'une automatisation consomme une collection persistante de fichiers, documents ou autres sources susceptibles d'évoluer entre deux exécutions, create-use-case doit définir explicitement une stratégie de réconciliation des sources avant de générer l'architecture finale.

Cette gestion ne doit pas être ajoutée systématiquement aux automatisations purement one-shot ou dont les entrées sont immuables par définition.

## 1. Déterminer la politique de mutation

Pour chaque collection de sources persistantes, déterminer si elle est :

```text
APPEND_ONLY
MUTABLE
REPLACEABLE
DELETABLE
```

et préciser :

```text
Can new sources appear?
Can existing sources be modified?
Can existing sources disappear?
Must modified/deleted sources invalidate derived data?
Must source history be preserved?
```

Si une réponse est réellement nécessaire pour concevoir correctement l'automatisation et n'est pas déductible des artefacts existants, la traiter comme un gap de readiness et utiliser grill-me si nécessaire.

Ne pas demander ces précisions si elles ne changent pas la conception du POC.

## 2. Registre persistant des sources

Pour une collection mutable ou incrémentale, générer un registre persistant des sources.

Préférer DuckDB ou un autre stockage structuré déjà résolu par la section Runtime capability resolution lorsque :

- le nombre de sources peut croître ;
- l'automatisation doit reprendre après interruption ;
- des résultats dérivés doivent rester reliés à leurs sources ;
- les changements doivent être détectés entre plusieurs runs.

Le registre devrait contenir, lorsque pertinent :

```text
source_id
relative_path
file_name
file_size
modified_at
content_hash
status
first_seen_at
last_seen_at
last_processed_at
processing_version
```

`source_id` doit être stable autant que possible.

`content_hash` doit être utilisé pour détecter une modification réelle de contenu.

Ne pas se fier uniquement :

- au nom de fichier ;
- à la date de modification ;
- à la taille du fichier.

Ces métadonnées peuvent servir de préfiltre, mais le hash reste la preuve de changement de contenu lorsque cela est nécessaire.

## 3. Réconciliation obligatoire au début du run

Pour les automatisations concernées, le `TASK.md` et les skills générés doivent imposer une phase de source reconciliation avant le traitement métier.

Comparer :

```text
sources actuellement présentes
vs
sources connues dans l'état persistant
```

Classifier chaque source :

```text
NEW
MODIFIED
UNCHANGED
DELETED
REPROCESS_REQUIRED
```

### NEW

Source présente maintenant mais absente du registre.

Action typique :

```text
register
→ extract/parse
→ process
→ persist derived data
→ mark processed
```

### UNCHANGED

Même source et même `content_hash`, avec une `processing_version` encore valide.

Action :

```text
skip expensive reprocessing
```

Ne pas retraiter inutilement une source inchangée.

### MODIFIED

Source connue mais `content_hash` différent.

Action :

```text
preserve source history if required
→ invalidate affected derived data
→ reprocess source
→ rebuild impacted results
```

Ne pas modifier ligne par ligne des résultats dérivés non fiables si une reconstruction déterministe de la portion impactée est plus sûre.

### DELETED

Source connue dans l'état persistant mais absente du corpus actuel.

Ne pas supprimer immédiatement son historique.

Préférer un tombstone :

```text
status = DELETED
last_seen_at = <last known time>
```

Puis déterminer quelles données dérivées doivent :

```text
remain valid
lose one source link
be downgraded in confidence
be invalidated
be rebuilt
```

### REPROCESS_REQUIRED

Le fichier n'a pas changé, mais la logique de traitement a évolué.

Exemples :

```text
skill version changed
extraction schema changed
business rule changed
processing_version changed
```

Action :

```text
reprocess even if content_hash is unchanged
```

## 4. Version de traitement

Les résultats persistants qui dépendent d'une logique susceptible d'évoluer doivent conserver une version de traitement.

Exemple :

```text
processing_version = obligation-register-v3
```

Règle recommandée :

```text
same content_hash
+ same processing_version
→ UNCHANGED

different content_hash
→ MODIFIED

same content_hash
+ different processing_version
→ REPROCESS_REQUIRED
```

La `processing_version` doit refléter une version fonctionnelle significative, pas chaque modification triviale de fichier.

## 5. Traçabilité des données dérivées

Toute donnée dérivée importante doit rester reliée à ses sources lorsque la traçabilité métier l'exige.

Exemple conceptuel :

```text
derived_record
    │
    └── derived_record_sources
            ├── derived_record_id
            ├── source_id
            ├── source_locator
            ├── source_hash
            └── processing_version
```

Cette relation permet de recalculer uniquement la partie impactée lorsqu'une source change ou disparaît.

## 6. Invalidation ciblée

Lorsqu'une source est `MODIFIED`, `DELETED` ou `REPROCESS_REQUIRED` :

1. identifier les résultats qui en dépendent ;
2. invalider uniquement ce qui est impacté ;
3. préserver les résultats indépendants ;
4. recalculer les agrégats, conflits ou synthèses qui dépendent des données invalidées ;
5. conserver la provenance de l'ancienne version si l'audit l'exige.

Éviter deux extrêmes :

```text
retraiter tout le corpus à chaque run
```

et :

```text
ne jamais remettre en cause les anciennes données dérivées
```

## 7. Reprise après interruption

La source reconciliation elle-même doit être reprenable si elle peut être longue.

Pour chaque source, persister si utile :

```text
DISCOVERED
REGISTERED
PROCESSING
PROCESSED
FAILED
INVALIDATED
DELETED
```

Un redémarrage ne doit pas :

- retraiter les sources déjà terminées sans raison ;
- perdre le statut des fichiers supprimés ;
- créer des doublons ;
- oublier une invalidation déjà identifiée.

## 8. Generated runtime contract

Si la gestion de changements de sources est applicable, les artefacts générés doivent préciser explicitement cette capacité.

### Dans AUTOMATION_SPEC.md

Ajouter une section :

```text
Source lifecycle
```

décrivant au minimum :

```text
mutation policy
source registry
change detection
content hash strategy
processing version strategy
derived-data invalidation
deletion/tombstone policy
resume behavior
```

### Dans TASK.md

Ajouter une règle du type :

```text
Always reconcile the current input corpus against persistent source state
before business processing.

Do not assume that the source collection is identical to the previous run.
Process only NEW, MODIFIED or REPROCESS_REQUIRED sources unless a full
rebuild is explicitly required.

Handle DELETED sources according to the configured invalidation policy.
```

### Dans les skills métier générés

Décrire concrètement :

- comment inventorier les sources ;
- comment calculer ou obtenir le hash ;
- quelle table/structure persiste l'état ;
- comment détecter les suppressions ;
- comment invalider les données dérivées ;
- comment versionner le traitement ;
- comment reprendre après interruption.

Ne pas se contenter d'écrire :

```text
Support incremental updates.
```

Le comportement doit être exécutable.

