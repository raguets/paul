// Lists the skills Pi would load for a use case directory, using Pi's own
// resource loader (no model call). Global user settings are isolated with an
// empty agent dir; the project is treated as trusted.
//
// In the `paul` monorepo a use case inherits the `.agents/skills` of the
// business levels above it (exposed through <use-case>/.pi/settings.json), so
// loaded skills legitimately live outside the given directory. Paths are
// therefore printed relative to the monorepo root; skills coming from outside
// it (the user's global skills) are skipped.
//
// Usage: node pi-skills.mjs <pi-coding-agent/dist/index.js> <use-case-dir>
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, resolve, relative } from "node:path";
import { pathToFileURL } from "node:url";

function repoRoot(dir) {
  for (let cur = dir, prev = ""; cur !== prev; prev = cur, cur = dirname(cur)) {
    if (existsSync(join(cur, ".git"))) return cur;
  }
  return dir;
}

const [piIndex, projectArg] = process.argv.slice(2);
const pi = await import(pathToFileURL(piIndex).href);
const cwd = resolve(projectArg);
const root = repoRoot(cwd);
const agentDir = mkdtempSync(join(tmpdir(), "pi-agentdir-"));
try {
  const settingsManager = pi.SettingsManager.create(cwd, agentDir, { projectTrusted: true });
  const loader = new pi.DefaultResourceLoader({ cwd, agentDir, settingsManager, noExtensions: true });
  await loader.reload();
  const { skills, diagnostics } = loader.getSkills();
  for (const s of skills) {
    const p = relative(root, s.filePath ?? s.path ?? "").replaceAll("\\", "/");
    if (!p.startsWith("..") && !isAbsolute(p)) console.log(`${s.name}\t${p}`);
  }
  for (const d of diagnostics) console.error(`DIAG ${d.type ?? ""} ${d.message ?? JSON.stringify(d)} ${d.path ?? ""}`);
} finally {
  rmSync(agentDir, { recursive: true, force: true });
}
