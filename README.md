# PAUL — Personal Assistant for Universal Labor

System repository of PAUL: architecture, migration reports and tooling. The
agent assets, automations and workspaces live in sibling repositories of the
same GitHub organisation (see [ARCHITECTURE.md](ARCHITECTURE.md)).

| File | Purpose |
|---|---|
| `ARCHITECTURE.md` | taxonomy, use cases, repositories, flat dependency model — source of truth |
| `MIGRATION_REPORT.md` | split of the former `pi-workspace` monorepo |
| `MIGRATION_INVENTORY.md` | audit of the monorepo before the split |
| `verify.sh` | structural checks of all repositories (`bash verify.sh`) |
| `harness-check/` | Pi / Hermes skill-discovery probes used by `verify.sh` |
| `publish-github.ps1` | creates and pushes the repositories in dependency order |

## Local setup

All PAUL repositories are siblings of this one:

```powershell
git config --global core.longpaths true          # Windows
git clone https://github.com/<org>/paul.git
cd paul
foreach ($r in "agent-common","agent-authoring","agent-finance","agent-contract-management",
               "automation-create-use-case","automation-obligations") {
  git clone "https://github.com/<org>/$r.git"
}
git clone --recurse-submodules https://github.com/<org>/workspace-create-use-case.git
git clone --recurse-submodules https://github.com/<org>/workspace-obligations.git   # if authorised
```

The sibling repositories are ignored by this repository (`.gitignore`).
