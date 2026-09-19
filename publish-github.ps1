<#
.SYNOPSIS
  Creates the PAUL repositories in a GitHub organisation and pushes them, in
  dependency order. Idempotent: existing repositories and remotes are reused.

.DESCRIPTION
  Order: agent-*, automation-*, workspace-*, then paul (this directory).
  Submodule URLs are relative (../agent-common), so no .gitmodules change is
  needed whatever the organisation name.

  Requires: GitHub CLI (gh) authenticated with the "repo" scope and the right
  to create repositories in the organisation. The organisation itself must be
  created beforehand on https://github.com/account/organizations/new.

.EXAMPLE
  .\publish-github.ps1 -Org paul-labor
  .\publish-github.ps1 -Org paul-labor -AgentVisibility public -DryRun
#>
param(
    [Parameter(Mandatory = $true)] [string] $Org,
    [ValidateSet("private", "internal", "public")] [string] $AgentVisibility = "private",
    [ValidateSet("private", "internal", "public")] [string] $AutomationVisibility = "private",
    [switch] $DryRun
)

# Continue: in Windows PowerShell 5.1, "Stop" turns native stderr (2>$null) into errors.
$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

# Name, kind, description — in dependency order.
$Repos = @(
    @("agent-common",               "agent",      "PAUL - common harness-neutral agent skills"),
    @("agent-authoring",            "agent",      "PAUL - authoring skills (grill-me)"),
    @("agent-finance",              "agent",      "PAUL - Finance domain skills"),
    @("agent-contract-management",  "agent",      "PAUL - Contract Management sub-domain skills"),
    @("automation-create-use-case", "automation", "PAUL - create-use-case automation"),
    @("automation-obligations",     "automation", "PAUL - contractual obligations register automation"),
    @("workspace-create-use-case",  "workspace",  "PAUL - entry point to create a use case"),
    @("workspace-obligations",      "workspace",  "PAUL - obligations workspace (business data)"),
    @("paul",                       "system",     "PAUL - Personal Assistant for Universal Labor: architecture and tooling")
)

function Invoke-Step([string] $What, [scriptblock] $Action) {
    Write-Host "  $What"
    if (-not $DryRun) {
        & $Action
        if ($LASTEXITCODE -ne 0) { throw "Failed: $What" }
    }
}

$protocol = (gh config get git_protocol 2>$null)
if (-not $protocol) { $protocol = "https" }

foreach ($r in $Repos) {
    $name = $r[0]; $kind = $r[1]; $desc = $r[2]
    $dir = if ($kind -eq "system") { $Root } else { Join-Path $Root $name }
    $visibility = switch ($kind) {
        "agent"      { $AgentVisibility }
        "system"     { $AgentVisibility }
        "automation" { $AutomationVisibility }
        default      { "private" }   # workspaces are always private
    }
    $url = if ($protocol -eq "ssh") { "git@github.com:$Org/$name.git" } else { "https://github.com/$Org/$name.git" }

    Write-Host "== $Org/$name ($visibility)"
    if (-not (Test-Path (Join-Path $dir ".git"))) { throw "$dir is not a Git repository" }
    $status = git -C $dir status --porcelain
    if ($status) { throw "$name has uncommitted changes" }

    gh repo view "$Org/$name" --json name 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Step "create $Org/$name" { gh repo create "$Org/$name" "--$visibility" --description $desc --disable-wiki | Out-Null }
        $topic = if ($kind -eq "system") { "paul" } else { "paul-$kind" }
        Invoke-Step "topics paul, $topic" { gh repo edit "$Org/$name" --add-topic paul --add-topic $topic | Out-Null }
    } else {
        Write-Host "  exists"
    }

    $current = git -C $dir remote get-url origin 2>$null
    if (-not $current) {
        Invoke-Step "remote origin $url" { git -C $dir remote add origin $url }
    } elseif ($current -ne $url) {
        Write-Host "  origin already set to $current (kept)"
    }
    Invoke-Step "push main" { git -C $dir push -u origin main }
}

Write-Host ""
Write-Host "Done. Clone a workspace with:"
Write-Host "  git clone --recurse-submodules https://github.com/$Org/workspace-obligations.git"
