# PAUL — Architecture

**PAUL — Personal Assistant for Universal Labor.**

This document is the source of truth for the business taxonomy, the use cases
and the repositories. Repository names do not encode the taxonomy; Git only
materialises what each workspace needs.

Derived from the `openlabollioules/pi-workspace` monorepo (2026-09-19), spec v1.2
revised: flat dependency model and short names.

## 1. Three separate notions

```text
Business taxonomy (this document + catalog.yaml)
common
└── finance
    └── contract-management
        └── obligations            (use case)

Logical dependencies
contract-management → finance → common
obligations         → contract-management (hence finance, common)

Git implementation
only the workspace of a use case has submodules; it mounts, flat,
its automation and every node of its parent chain
```

## 2. Repositories

GitHub has no folders inside an organisation: the organisation is the top-level
container and the prefix (`agent-`, `automation-`, `workspace-`) plays the role
of the folder. Repositories are also tagged with the topics `paul` and
`paul-agent` / `paul-automation` / `paul-workspace`.

| Kind | Repository | Contents | Submodules |
|---|---|---|---|
| system | `paul` | this document, reports, `verify.sh`, publication script | — |
| agent | `agent-common` | `document-processing`, `structured-data-duckdb`, `start-use-case` | — |
| agent | `agent-authoring` | `grill-me` (authoring only) | — |
| agent | `agent-finance` | Finance domain (no skill yet) | — |
| agent | `agent-contract-management` | `contract-obligation-extraction` | — |
| automation | `automation-create-use-case` | `create-use-case` + `scaffold.py` | — |
| automation | `automation-obligations` | obligations task, specs, `AGENTS.md`, `obligation-register-duckdb` | — |
| workspace | `workspace-create-use-case` | `USE_CASE.md`, `catalog.yaml`, `.create-use-case/` | `automation`, `authoring` |
| workspace | `workspace-obligations` | `contract/`, `data/`, `output/`, `.tmp/`, `evaluator/` | `automation`, `contract-management`, `finance`, `common` |

Local layout = GitHub organisation layout (all repositories are siblings):

```text
G:\DEV\paul\                     # repo "paul" (ignores the sibling repos below)
├── ARCHITECTURE.md
├── agent-common\  agent-authoring\  agent-finance\  agent-contract-management\
├── automation-create-use-case\  automation-obligations\
└── workspace-create-use-case\   workspace-obligations\
```

## 3. Business taxonomy

| Node | Type | Parent | Repository |
|---|---|---|---|
| `common` | common | — | `agent-common` |
| `finance` | domain | `common` | `agent-finance` |
| `contract-management` | sub-domain | `finance` | `agent-contract-management` |

Sub-domains are optional specialisations. A use case attached to `finance`
inherits `finance` and `common`, **not** `contract-management`. The machine-readable
copy used by `create-use-case` is `workspace-create-use-case/catalog.yaml`.

## 4. Use cases

| Use case | Type | Parent | Automation | Workspace |
|---|---|---|---|---|
| `obligations` | AUTOMATION | `contract-management` | `automation-obligations` | `workspace-obligations` |
| `create-use-case` | AUTOMATION (tooling) | — (uses `authoring`) | `automation-create-use-case` | `workspace-create-use-case` |

Moving a use case to another branch changes this table, the catalog parent and
the workspace submodules — not repository names.

## 5. Flat dependency model

The workspace is the **composition root**. It mounts under
`.agents/skills/_deps/<id>/`:

```text
workspace-obligations/.agents/skills/_deps/
├── automation/            -> automation-obligations
├── contract-management/   -> agent-contract-management
├── finance/               -> agent-finance
└── common/                -> agent-common
```

Rules:

- `agent-*` and `automation-*` repositories never have submodules;
- the workspace mounts its automation and the whole parent chain (parent,
  then ancestors from the catalog);
- one copy and one pinned version of each repository per workspace;
- constant depth: skills are always at `_deps/<id>/.agents/skills/<skill>/`.

Why not nested submodules (each repo containing its parent)? Pi 0.84 does not
discover skills below hidden directories (`_deps/x/.agents/…/_deps/y/.agents`),
nested `.git/modules` paths exceed Windows `MAX_PATH`, and a repository
referencing its whole chain would be cloned several times (duplicate skills for
Hermes, divergent versions).

## 6. Submodule URLs

Relative URLs, no host and no organisation:

```ini
[submodule ".agents/skills/_deps/common"]
    path = .agents/skills/_deps/common
    url = ../agent-common
```

Resolved against the workspace remote (`git@github.com:<org>/workspace-x.git`
→ `git@github.com:<org>/agent-common`, same for HTTPS), or against the sibling
directory while the repository has no remote. Renaming the organisation or
moving to GitLab (one flat group) requires no change.

## 7. Harness

| Harness | Skill discovery from a workspace root |
|---|---|
| Hermes 0.21 | native: `<root>/.agents/skills/**` walked recursively, after `hermes skills trust` |
| Pi 0.84 | `.agents/skills` auto-discovered but hidden directories are skipped; `.pi/settings.json` lists the 4 `_deps/<id>/.agents/skills` directories (+ `!**/README.md`). Generated by `scaffold.py pi-adapter`, no copy of any skill |

## 8. Access rights (GitHub)

| Repositories | Content | Access |
|---|---|---|
| `agent-*`, `paul` | skills, no business document | broad (team `paul-maintainers`) |
| `automation-*` | automation logic | people maintaining or reviewing the logic |
| `workspace-*` | contracts, data, outputs, ground truth | **private**, need-to-know team per workspace; do not grant through a broad base permission of the organisation |

Cloning a workspace requires read access to the repositories it mounts; the
reverse is not needed.

## 9. Publication order

Dependencies first: `agent-*`, then `automation-*`, then `workspace-*`, then
`paul`. See `publish-github.ps1`.

## 10. Windows

`git config --global core.longpaths true` is still recommended; with the flat
model the longest path inside a workspace clone is below 120 characters.
