// Lists the skills Pi would load for a project directory, using Pi's own
// resource loader (no model call). Global user settings are isolated with an
// empty agent dir; the project is treated as trusted.
// Usage: node pi-skills.mjs <pi-coding-agent/dist/index.js> <project-dir>
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, relative } from "node:path";
import { pathToFileURL } from "node:url";

const [piIndex, projectArg] = process.argv.slice(2);
const pi = await import(pathToFileURL(piIndex).href);
const cwd = resolve(projectArg);
const agentDir = mkdtempSync(join(tmpdir(), "pi-agentdir-"));
try {
  const settingsManager = pi.SettingsManager.create(cwd, agentDir, { projectTrusted: true });
  const loader = new pi.DefaultResourceLoader({ cwd, agentDir, settingsManager, noExtensions: true });
  await loader.reload();
  const { skills, diagnostics } = loader.getSkills();
  for (const s of skills) {
    const p = relative(cwd, s.filePath ?? s.path ?? "").replaceAll("\\", "/");
    if (!p.startsWith("..")) console.log(`${s.name}\t${p}`);
  }
  for (const d of diagnostics) console.error(`DIAG ${d.type ?? ""} ${d.message ?? JSON.stringify(d)} ${d.path ?? ""}`);
} finally {
  rmSync(agentDir, { recursive: true, force: true });
}
