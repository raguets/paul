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

  python scaffold.py pi-adapter --path finance/contract-management/obligations

Run `python scaffold.py <command> --help` for all options.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
TEMPLATES = SKILL_DIR / "templates"
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLACEHOLDER_STYLES = ("stub", "dir", "empty")
PI_README_EXCLUDE = "!**/README.md"
SKILLS_REL = Path(".agents") / "skills"
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


# --------------------------------------------------------------------------- pi adapter

def ancestor_skill_dirs(use_case: Path) -> list[Path]:
    """`.agents/skills` directories of the business levels above *use_case*,
    from the monorepo root down to its direct parent."""
    use_case = use_case.resolve()
    root = monorepo_root(use_case)
    levels = [root, *[p for p in reversed(use_case.parents) if root in p.parents]]
    return [lvl / SKILLS_REL for lvl in levels if (lvl / SKILLS_REL).is_dir()]


def write_pi_adapter(use_case: Path) -> list[str]:
    """Pi only auto-discovers `<cwd>/.agents/skills`; it does not walk up the
    business hierarchy. List the ancestor skill directories explicitly in the
    project settings (paths relative to `.pi/`). No skill is ever copied, and
    the use case's own `.agents/skills` is left to auto-discovery.
    Other keys of an existing `.pi/settings.json` are preserved."""
    use_case = use_case.resolve()
    pi_dir = use_case / ".pi"
    dirs = [_relative_to_dir(d, pi_dir) for d in ancestor_skill_dirs(use_case)]
    settings_file = pi_dir / "settings.json"
    settings: dict = {}
    if settings_file.exists():
        settings = json.loads(settings_file.read_text(encoding="utf-8"))
    kept = [s for s in settings.get("skills", [])
            if not s.startswith("../") and s != PI_README_EXCLUDE]
    settings["skills"] = kept + dirs + ([PI_README_EXCLUDE] if dirs else [])
    if not settings["skills"]:
        settings.pop("skills")
    if settings:
        pi_dir.mkdir(exist_ok=True)
        settings_file.write_text(json.dumps(settings, indent=2) + "\n",
                                 encoding="utf-8", newline="\n")
    elif settings_file.exists():
        settings_file.unlink()
    return dirs


def _common(a: Path, b: Path) -> Path:
    parts = []
    for x, y in zip(a.parts, b.parts):
        if x != y:
            break
        parts.append(x)
    return Path(*parts)


def _relative_to_dir(target: Path, base: Path) -> str:
    """POSIX relative path from *base* to *target* (both absolute)."""
    base, target = base.resolve(), target.resolve()
    common = _common(base, target)
    up = [".."] * (len(base.parts) - len(common.parts))
    down = list(target.parts[len(common.parts):])
    return "/".join(up + down) or "."


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
    pi_dirs = write_pi_adapter(use_case)

    log("create-use-case scaffold summary")
    log(f"- use case: {use_case}")
    for c in created:
        log(f"    {c}")
    if ws:
        log(f"- workspace repo: {ws}" + ("" if (ws / '.git').exists() else "  (no git: --no-git)"))
    else:
        log("- workspace repo: none (no persistent data needed)")
    log(f"- inherited skill dirs exposed to Pi: {len(pi_dirs)}")
    for d in pi_dirs:
        log(f"    {d}")


def cmd_pi_adapter(args: argparse.Namespace) -> None:
    use_case = Path(args.path).resolve()
    if not use_case.is_dir():
        raise ScaffoldError(f"--path {use_case} does not exist")
    dirs = write_pi_adapter(use_case)
    log(f"{use_case / '.pi' / 'settings.json'}: {len(dirs)} inherited skill dir(s)")
    for d in dirs:
        log(f"  {d}")


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

    pa = sub.add_parser("pi-adapter",
                        help="(re)write <use-case>/.pi/settings.json from the business hierarchy")
    pa.add_argument("--path", required=True, help="the use case directory")
    pa.set_defaults(func=cmd_pi_adapter)
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
