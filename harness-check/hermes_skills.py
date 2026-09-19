"""Lists the project skills Hermes would index for a project directory, using
Hermes' own discovery functions (no model call, no change to the Hermes
configuration). Trust (`hermes skills trust`) is not checked here.
Usage: <hermes venv python> hermes_skills.py <hermes-agent dir> <project-dir>
"""
import sys
from pathlib import Path

hermes_dir, project = sys.argv[1], Path(sys.argv[2]).resolve()
sys.path.insert(0, hermes_dir)
from agent.skill_utils import (  # noqa: E402
    _candidate_project_skills_dirs, find_project_root, iter_skill_index_files)

root = find_project_root(project)
print(f"# project root: {root}", file=sys.stderr)
for d in _candidate_project_skills_dirs(root):
    for f in iter_skill_index_files(d, "SKILL.md"):
        print(f"{f.parent.name}\t{f.relative_to(root).as_posix()}")
