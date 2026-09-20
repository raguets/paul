<#
.SYNOPSIS
  Creates the PAUL repositories in a GitHub organisation and pushes them.
  Idempotent: existing repositories and remotes are reused.

.DESCRIPTION
  The monorepo `paul` holds all the agentic logic. The persistent data of each
  use case lives in a nested, independent repository `workspace-<slug>` that
  `paul` ignores; those are discovered on disk and published separately, always
  private, because they hold business documents, data and ground truth.

  Requires: GitHub CLI (gh) authenticated with the "repo" scope and the right
  to create repositories in the organisation. The organisation itself must be
  created beforehand on https://github.com/account/organizations/new.

.EXAMPLE
  .\publish-github.ps1 -Org paul-agent
  .\publish-github.ps1 -Org paul-agent -Visibility public -DryRun
  .\publish-github.ps1 -Org paul-agent -SkipWorkspaces
#>
param(
    [Parameter(Mandatory = $true)] [string] $Org,
    [ValidateSet("private", "internal", "public")] [string] $Visibility = "private",
    [switch] $SkipWorkspaces,
    [switch] $DryRun
)

# Continue: in Windows PowerShell 5.1, "Stop" turns native stderr into errors.
$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

function Invoke-Step([string] $What, [scriptblock] $Action) {
    Write-Host "  $What"
    if (-not $DryRun) {
        & $Action
        if ($LASTEXITCODE -ne 0) { throw "Failed: $What" }
    }
}

function Publish-Repo([string] $Dir, [string] $Name, [string] $Desc, [string] $Vis, [string] $Topic) {
    Write-Host "== $Org/$Name ($Vis)"
    if (-not (Test-Path (Join-Path $Dir ".git"))) { throw "$Dir is not a Git repository" }
    $status = git -C $Dir status --porcelain --untracked-files=no
    if ($status) { throw "$Name has uncommitted changes" }

    $url = if ($protocol -eq "ssh") { "git@github.com:$Org/$Name.git" } else { "https://github.com/$Org/$Name.git" }

    gh repo view "$Org/$Name" --json name 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Step "create $Org/$Name" { gh repo create "$Org/$Name" "--$Vis" --description $Desc --disable-wiki | Out-Null }
        Invoke-Step "topics paul, $Topic" { gh repo edit "$Org/$Name" --add-topic paul --add-topic $Topic | Out-Null }
    } else {
        Write-Host "  exists"
    }

    $current = git -C $Dir remote get-url origin 2>$null
    if (-not $current) {
        Invoke-Step "remote origin $url" { git -C $Dir remote add origin $url }
    } elseif ($current -ne $url) {
        Write-Host "  origin already set to $current (kept)"
    }
    Invoke-Step "push main" { git -C $Dir push -u origin main }
}

$protocol = (gh config get git_protocol 2>$null)
if (-not $protocol) { $protocol = "https" }

Publish-Repo $Root "paul" "PAUL - Personal Assistant for Universal Labor: agentic monorepo" $Visibility "paul-monorepo"

if (-not $SkipWorkspaces) {
    # Nested workspace repositories: any directory matching workspace-* that is
    # itself a Git repository. Always private: business data.
    $workspaces = Get-ChildItem -Path $Root -Directory -Recurse -Filter "workspace-*" |
        Where-Object { Test-Path (Join-Path $_.FullName ".git") }
    foreach ($ws in $workspaces) {
        $useCase = Split-Path $ws.FullName -Parent | Split-Path -Leaf
        Publish-Repo $ws.FullName $ws.Name "PAUL - business data of the use case $useCase" "private" "paul-workspace"
    }
    if (-not $workspaces) { Write-Host "No nested workspace repository found." }
}

Write-Host ""
Write-Host "Done. Clone with:"
Write-Host "  git clone https://github.com/$Org/paul.git"
Write-Host "  # then, inside a use case directory, clone its workspace if authorised:"
Write-Host "  #   git clone https://github.com/$Org/workspace-<slug>.git"
