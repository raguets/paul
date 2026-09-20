#!/usr/bin/env python3
"""Deterministic scaffolder used by the create-use-case skill.

It only materialises decisions already taken by the agent running
create-use-case: the use case folder, TASK.md, optional local skills, optional
scripts/, and the optional independent workspace repository. It never decides
business logic, never decides that a skill is needed, and never asks questions.

Monorepo model: the business hierarchy is expressed by folders inside `paul`.
A use case is a plain folder named after its function. Its persistent data
lives in a nested, independent Git repository `workspace-<slug>` which `paul`
ignores (`**/*workspace*`). There is no `_deps`, no agentic submodule, no
`automation-*` or `agent-*` repository and no `authoring/` level.

Usage (run from the business folder that should receive the use case):

  python scaffold.py use-case --name obligations
  python scaffold.py use-case --name obligations --parent-dir finance/contract-management \
      --skills obligation-register-duckdb --scripts \
      --workspace --workspace-dirs contract,data,output
  python scaffold.py use-case --name obligations --workspace-from ../old/workspace-obligations

  python scaffold.py hermes-adapter --path finance/contract-management/obligations

Pi needs no adapter: it walks up from cwd to the Git root collecting
`<level>/.agents/skills` on its own. Hermes only scans the Git root, so
`hermes-adapter` mirrors the intermediate levels with directory links.

Run `python scaffold.py <command> --help` for all options.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
TEMPLATES = SKILL_DIR / "templates"
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLACEHOLDER_STYLES = ("stub", "dir", "empty")
SKILLS_REL = Path(".agents") / "skills"
HERMES_SKILLS_REL = Path(".hermes") / "skills"
# Names that would recreate the structures this architecture removed.
FORBIDDEN_PREFIXES = ("automation-", "agent-", "workspace-")
FORBIDDEN_NAMES = ("authoring", "_deps")


class ScaffoldError(Exception):
    pass


# --------------------------------------------------------------------------- helpers

def log(msg: str) -> None:
    print(msg, flush=True)


def slug(value: str, what: str) -> str:
    if not SLUG_RE.match(value):
        raise ScaffoldError(f"{what} must be kebab-case (a-z, 0-9, '-'): {value!r}")
    return value


def use_case_slug(value: str) -> str:
    """A use case carries its functional name: `obligations`, not `automation-obligations`."""
    slug(value, "--name")
    if value.startswith(FORBIDDEN_PREFIXES) or value in FORBIDDEN_NAMES:
        raise ScaffoldError(
            f"--name {value!r}: a use case carries its functional name only "
            f"(e.g. 'obligations', not 'automation-obligations')")
    return value


def csv_list(value: str | None) -> list[str]:
    return [v.strip() for v in value.split(",") if v.strip()] if value else []


def placeholders(value: str | None, what: str) -> list[tuple[str, str]]:
    """'a,b:dir,c:empty' -> [('a','stub'),('b','dir'),('c','empty')]"""
    result = []
    for item in csv_list(value):
        name, _, style = item.partition(":")
        style = style or "stub"
        if style not in PLACEHOLDER_STYLES:
            raise ScaffoldError(f"{what} {name!r}: style must be one of {PLACEHOLDER_STYLES}")
        result.append((slug(name, what), style))
    return result


def git(repo: Path, *args: str, check: bool = True) -> str:
    cmd = ["git", "-c", "protocol.file.allow=always", "-c", "core.longpaths=true", *args]
    proc = subprocess.run(cmd, cwd=repo, text=True, capture_output=True)
    if check and proc.returncode != 0:
        raise ScaffoldError(f"git {' '.join(args)} failed in {repo}:\n{proc.stderr.strip()}")
    return proc.stdout.strip()


def render(template: Path, dest: Path, values: dict[str, str]) -> None:
    text = template.read_text(encoding="utf-8")
    for key, val in values.items():
        text = text.replace("{{" + key + "}}", val)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8", newline="\n")


def monorepo_root(start: Path) -> Path:
    """Nearest ancestor of *start* (excluded) holding a .git: the `paul` root.

    A workspace repo sits *below* a use case folder, so walking up from the use
    case never hits it.
    """
    for parent in start.resolve().parents:
        if (parent / ".git").exists():
            return parent
    raise ScaffoldError(f"no Git repository above {start}: run this inside the `paul` monorepo")


# --------------------------------------------------------------------------- hermes adapter

def business_skill_dirs(use_case: Path | None, root: Path) -> list[Path]:
    """`.agents/skills` directories that Hermes cannot reach on its own.

    Hermes indexes only `<git root>/.agents/skills` and `<git root>/.hermes/skills`.
    The root level is therefore excluded here: it is already native. With
    *use_case*, return the levels of that branch only (business scoping, the
    same set Pi sees natively). Without it, every business level of the repo.
    """
    if use_case is not None:
        levels = [p for p in reversed(use_case.resolve().parents) if root in p.parents]
        levels.append(use_case.resolve())
    else:
        levels = sorted({d.parent.parent for d in root.rglob("*/" + SKILLS_REL.as_posix())
                         if d.is_dir() and "workspace-" not in d.as_posix()})
    return [lvl / SKILLS_REL for lvl in levels
            if lvl != root and (lvl / SKILLS_REL).is_dir()]


def link_name(skills_dir: Path, root: Path) -> str:
    """`finance/contract-management/.agents/skills` -> `finance-contract-management`.

    The business level is two directories above (`<level>/.agents/skills`).
    """
    return "-".join(skills_dir.parent.parent.relative_to(root).parts)


def remove_link(path: Path) -> None:
    """Remove a directory link without ever touching what it points at.

    A junction or directory symlink must be unlinked, never walked: deleting it
    recursively would delete the real `.agents/skills` behind it.
    """
    if not path.is_symlink() and not path.exists():
        return
    if not path.is_symlink() and path.is_dir() and any(path.iterdir()) and not _is_reparse(path):
        raise ScaffoldError(f"{path} is a real directory, not a link; refusing to remove it")
    try:
        path.unlink()
    except (OSError, PermissionError):
        os.rmdir(path)


def _is_reparse(path: Path) -> bool:
    """True for a Windows junction, which `is_symlink()` may not report."""
    try:
        return bool(os.lstat(path).st_reparse_tag)  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        return False


def make_link(link: Path, target: Path) -> None:
    if os.name == "nt":
        proc = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(target)],
                              text=True, capture_output=True)
        if proc.returncode != 0:
            detail = (proc.stdout + proc.stderr).strip()
            raise ScaffoldError(f"mklink /J {link} failed: {detail}")
    else:
        os.symlink(target, link, target_is_directory=True)


def write_hermes_adapter(root: Path, use_case: Path | None, clear: bool = False) -> list[str]:
    """(Re)build `<root>/.hermes/skills`: one directory link per business level
    Hermes cannot see. No SKILL.md is ever copied; the farm is gitignored."""
    farm = root / HERMES_SKILLS_REL
    if farm.exists():
        for child in sorted(farm.iterdir()):
            remove_link(child)
    if clear:
        if farm.exists() and not any(farm.iterdir()):
            farm.rmdir()
        return []
    dirs = business_skill_dirs(use_case, root)
    if not dirs:
        return []
    farm.mkdir(parents=True, exist_ok=True)
    created = []
    for d in dirs:
        name = link_name(d, root)
        make_link(farm / name, d)
        created.append(f"{name} -> {d.relative_to(root).as_posix()}")
    return created


# --------------------------------------------------------------------------- commands

def make_skills(use_case: Path, items: list[tuple[str, str]]) -> list[str]:
    created = []
    for name, style in items:
        d = use_case / SKILLS_REL / name
        d.mkdir(parents=True, exist_ok=True)
        if style == "dir":
            pass
        elif style == "empty":
            (d / "SKILL.md").touch()
        else:
            (d / "SKILL.md").write_text(
                f"---\nname: {name}\ndescription: TODO - à définir.\n---\n\n# TODO\n",
                encoding="utf-8", newline="\n")
        created.append(f".agents/skills/{name}/ ({style})")
    return created


def make_workspace(use_case: Path, name: str, args: argparse.Namespace) -> Path:
    ws = use_case / f"workspace-{name}"
    if ws.exists() and any(ws.iterdir()):
        raise ScaffoldError(f"{ws} already exists and is not empty; nothing overwritten")
    if args.workspace_from:
        ws.parent.mkdir(parents=True, exist_ok=True)
        git(use_case, "clone", "-q", args.workspace_from, ws.name)
        return ws
    ws.mkdir(parents=True, exist_ok=True)
    for d in csv_list(args.workspace_dirs):
        if d in ("workspace", ".agents", ".git") or "/" in d or "\\" in d:
            raise ScaffoldError(f"invalid workspace directory {d!r}")
        (ws / d).mkdir(parents=True, exist_ok=True)
    if not args.no_git:
        git(ws, "init", "-q", "-b", "main")
        git(ws, "add", "-A")
        git(ws, "commit", "-q", "--allow-empty", "-m",
            f"Initial workspace for the use case {name}")
        if args.workspace_url:
            git(ws, "remote", "add", "origin", args.workspace_url)
    return ws


def cmd_use_case(args: argparse.Namespace) -> None:
    name = use_case_slug(args.name)
    parent = Path(args.parent_dir).resolve()
    if not parent.is_dir():
        raise ScaffoldError(f"--parent-dir {parent} does not exist")
    root = monorepo_root(parent / "x")  # validates we are inside the monorepo
    use_case = parent / name
    if use_case.exists() and any(use_case.iterdir()):
        raise ScaffoldError(f"{use_case} already exists and is not empty; nothing overwritten")
    use_case.mkdir(parents=True, exist_ok=True)

    created: list[str] = []
    task = use_case / "TASK.md"
    if args.task_from:
        src = Path(args.task_from).resolve()
        if not src.is_file():
            raise ScaffoldError(f"--task-from {src} is not a file")
        task.write_text(src.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
    else:
        render(TEMPLATES / "TASK.md", task, {
            "NAME": name,
            "USE_CASE_PATH": use_case.relative_to(root).as_posix(),
            "WORKSPACE": f"workspace-{name}",
            "DATE": _dt.date.today().isoformat(),
        })
    created.append("TASK.md")
    created += make_skills(use_case, placeholders(args.skills, "--skills"))
    if args.scripts:
        (use_case / "scripts").mkdir(exist_ok=True)
        created.append("scripts/")
    ws = make_workspace(use_case, name, args) if (args.workspace or args.workspace_from) else None

    log("create-use-case scaffold summary")
    log(f"- use case: {use_case}")
    for c in created:
        log(f"    {c}")
    if ws:
        log(f"- workspace repo: {ws}" + ("" if (ws / '.git').exists() else "  (no git: --no-git)"))
    else:
        log("- workspace repo: none (no persistent data needed)")
    inherited = business_skill_dirs(use_case, root)
    log(f"- inherited business skill levels: {len(inherited)} "
        "(Pi walks up to them natively; for Hermes run `scaffold.py hermes-adapter`)")
    for d in inherited:
        log(f"    {d.relative_to(root).as_posix()}")


def cmd_hermes_adapter(args: argparse.Namespace) -> None:
    if args.path:
        use_case = Path(args.path).resolve()
        if not use_case.is_dir():
            raise ScaffoldError(f"--path {use_case} does not exist")
        root = monorepo_root(use_case)
    else:
        use_case = None
        root = monorepo_root(Path.cwd() / "x")
    links = write_hermes_adapter(root, None if args.all else use_case, clear=args.clear)
    farm = (root / HERMES_SKILLS_REL).as_posix()
    if args.clear:
        log(f"{farm}: cleared")
        return
    log(f"{farm}: {len(links)} business level(s) linked for Hermes")
    for l in links:
        log(f"  {l}")
    if not links:
        log("  (nothing to link: no business level above the root has skills)")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)

    uc = sub.add_parser("use-case", help="create a use case folder under a business folder")
    uc.add_argument("--name", required=True,
                    help="functional use case slug, without any prefix (e.g. obligations)")
    uc.add_argument("--parent-dir", default=".",
                    help="business folder receiving the use case (default: current directory)")
    uc.add_argument("--task-from", help="use this file as TASK.md instead of the template")
    uc.add_argument("--skills", help="local skills to create: name[:stub|dir|empty],... "
                                     "(only when a specific skill is really needed)")
    uc.add_argument("--scripts", action="store_true", help="create an empty scripts/ directory")
    uc.add_argument("--workspace", action="store_true",
                    help="create the independent repo workspace-<name> under the use case")
    uc.add_argument("--workspace-from", metavar="URL_OR_PATH",
                    help="clone an existing workspace repo as workspace-<name>")
    uc.add_argument("--workspace-dirs", default="input,output",
                    help="folders at the workspace root (default: input,output)")
    uc.add_argument("--workspace-url", help="Git URL recorded as the workspace origin")
    uc.add_argument("--no-git", action="store_true",
                    help="write files only: do not initialise the workspace repository")
    uc.set_defaults(func=cmd_use_case)

    ha = sub.add_parser("hermes-adapter",
                        help="(re)build <root>/.hermes/skills with links to the business levels "
                             "Hermes cannot reach (Pi needs no adapter)")
    ha.add_argument("--path", help="use case directory: link only its branch (business scoping)")
    ha.add_argument("--all", action="store_true",
                    help="link every business level of the repo (no scoping)")
    ha.add_argument("--clear", action="store_true", help="remove the links and stop")
    ha.set_defaults(func=cmd_hermes_adapter)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        args.func(args)
    except ScaffoldError as exc:
        print(f"scaffold error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
