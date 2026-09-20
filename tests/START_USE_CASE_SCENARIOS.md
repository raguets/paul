# start-use-case — scénarios de test fonctionnels

Scénarios manuels, à exécuter avec Pi et Hermes depuis le **dossier d'un cas
d'usage** (par exemple `paul/finance/contract-management/obligations`). Ils
vérifient le comportement décrit dans
`paul/.agents/skills/start-use-case/SKILL.md`.

## SU1 — lancement implicite au premier tour

Nouvelle conversation. Utilisateur : `go`

Attendu : `obligations/TASK.md` est résolu et le cas d'usage est lancé. Aucun
`TASK.md` situé sous `workspace-*/`, `.agents/`, `evaluator/` ou `.git/` n'est
choisi comme point d'entrée.

## SU2 — `go` plus tard dans la conversation

Conversation déjà engagée sur une étape précise. Utilisateur : `go`

Attendu : poursuivre selon le contexte courant ; `TASK.md` n'est **pas**
rechargé ; le cas d'usage n'est pas relancé depuis le début.

## SU3 — lancement explicite tardif

Conversation déjà engagée. Utilisateur :

```text
lance le use case obligations
exécute TASK.md
reprends obligations
```

Attendu : le cas d'usage demandé est résolu explicitement, son fichier de tâche
est chargé, lancé ou repris selon l'instruction. Valable à tout moment.

## SU4 — le workspace n'est pas prioritaire

Créer temporairement `workspace-obligations/TASK.md`. Nouvelle conversation
depuis `obligations/`. Utilisateur : `go`

Attendu : `obligations/TASK.md` est choisi, jamais celui du workspace.
Supprimer le fichier de test ensuite.

## SU5 — repli sur un autre nom de fichier

Un dossier de cas d'usage sans `TASK.md`, contenant seulement
`USE_CASE_contract-review.md`. Nouvelle conversation. Utilisateur :
`commençons`

Attendu : ce fichier est utilisé, seul candidat raisonnable.

## SU6 — exclusions

Un dossier sans fichier de tâche à sa racine, mais avec
`workspace-x/TASK.md` et `workspace-x/evaluator/TASK.md`. Nouvelle
conversation. Utilisateur : `go`

Attendu : rien n'est lancé implicitement ; l'agent dit en une ligne qu'aucun
fichier de tâche n'a été trouvé dans le dossier courant et demande quoi lancer.

## SU7 — plusieurs cas d'usage côte à côte

Depuis un dossier métier contenant plusieurs cas d'usage (par exemple
`paul/finance/contract-management`). Utilisateur :
`lance le use case obligations`

Attendu : `obligations/TASK.md` est résolu. Les dossiers `workspace-*`,
`.agents/` et `evaluator/` sont ignorés pendant la recherche.
