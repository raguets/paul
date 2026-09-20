/**
 * switch-working-directory.ts
 *
 * Generic Pi extension that exposes:
 *   - an LLM-callable tool: switch_working_directory({ path })
 *   - a manual fallback command: /cwd <path>
 *
 * The switch preserves the current conversation/session while rebuilding
 * cwd-bound Pi resources (tools, project context, skills, settings, extensions).
 *
 * Recommended project location:
 *   .pi/extensions/switch-working-directory.ts
 *
 * Note:
 * Pi auto-discovers project extensions from <cwd>/.pi/extensions. If this file
 * lives only at a repository root but Pi is often started from deeper folders,
 * reference this file once from Pi's global settings or install/copy it globally.
 */

import { existsSync, mkdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, isAbsolute, join, resolve } from "node:path";

import {
  getAgentDir,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function expandPath(input: string, baseCwd: string): string {
  let raw = input.trim();

  // Match Pi's built-in path-oriented tools: tolerate a leading "@".
  if (raw.startsWith("@")) raw = raw.slice(1);

  if (raw === "~") return homedir();
  if (raw.startsWith("~/") || raw.startsWith("~\\")) {
    return resolve(homedir(), raw.slice(2));
  }

  return isAbsolute(raw) ? resolve(raw) : resolve(baseCwd, raw);
}

function shortPath(path: string): string {
  const home = homedir();
  if (path === home) return "~";

  const separator = process.platform === "win32" ? "\\" : "/";
  const prefix = home.endsWith("/") || home.endsWith("\\") ? home : `${home}${separator}`;

  return path.startsWith(prefix) ? `~${path.slice(home.length)}` : path;
}

/**
 * Mirror Pi's cwd -> session-directory convention.
 * Sessions are grouped under:
 *   <agentDir>/sessions/--<encoded absolute cwd>--/
 */
function sessionDirectoryFor(cwd: string): string {
  const absolute = resolve(cwd);
  const encoded = `--${absolute
    .replace(/^[/\\]/, "")
    .replace(/[/\\:]/g, "-")}--`;

  return join(getAgentDir(), "sessions", encoded);
}

/**
 * Serialize the in-memory session into the target cwd's session directory,
 * preserving the session id and all entries while replacing only header.cwd.
 */
function writeRelocatedSession(
  header: unknown,
  entries: unknown[],
  targetCwd: string,
  sourceSessionFile: string,
): string {
  if (!header || typeof header !== "object") {
    throw new Error("Current session header is unavailable.");
  }

  const current = header as Record<string, unknown>;
  if (typeof current.cwd !== "string") {
    throw new Error("Current session header does not contain a cwd.");
  }

  const destinationDir = sessionDirectoryFor(targetCwd);
  mkdirSync(destinationDir, { recursive: true });

  const destinationFile = join(destinationDir, basename(sourceSessionFile));
  const relocatedHeader = {
    ...current,
    cwd: resolve(targetCwd),
  };

  const jsonl = [
    JSON.stringify(relocatedHeader),
    ...entries.map((entry) => JSON.stringify(entry)),
    "",
  ].join("\n");

  writeFileSync(destinationFile, jsonl, "utf8");
  return destinationFile;
}

function parseCommandPath(args: string): string {
  const trimmed = args.trim();
  if (!trimmed) return "";

  // Tool calls queue /cwd with JSON.stringify(path), so spaces are unambiguous.
  if (trimmed.startsWith('"')) {
    try {
      const parsed = JSON.parse(trimmed);
      if (typeof parsed === "string") return parsed;
    } catch {
      // Fall through to raw text for manually entered commands.
    }
  }

  return trimmed;
}

export default function switchWorkingDirectoryExtension(pi: ExtensionAPI) {
  /**
   * Manual fallback and internal execution path.
   *
   * A cwd switch replaces the session runtime. Doing that directly from inside
   * an executing LLM tool is unsafe, so the tool below queues this command as a
   * follow-up after its current turn terminates.
   */
  pi.registerCommand("cwd", {
    description:
      "/cwd <path> — move this Pi session to another existing directory and reload cwd-bound resources",

    handler: async (args, ctx) => {
      const requestedPath = parseCommandPath(args);

      if (!requestedPath) {
        ctx.ui.notify(`Current cwd: ${shortPath(ctx.cwd)}`, "info");
        return;
      }

      const target = expandPath(requestedPath, ctx.cwd);

      if (target === resolve(ctx.cwd)) {
        ctx.ui.notify(`Already in ${shortPath(target)}`, "info");
        return;
      }

      if (!existsSync(target)) {
        ctx.ui.notify(
          `Cannot switch cwd: directory does not exist: ${shortPath(target)}`,
          "error",
        );
        return;
      }

      if (!statSync(target).isDirectory()) {
        ctx.ui.notify(
          `Cannot switch cwd: not a directory: ${shortPath(target)}`,
          "error",
        );
        return;
      }

      const sourceSessionFile = ctx.sessionManager.getSessionFile();

      if (!sourceSessionFile) {
        ctx.ui.notify(
          "Cannot switch cwd in an ephemeral (--no-session) Pi session.",
          "error",
        );
        return;
      }

      // Commands are normally invoked while idle. Keep this guard so /cwd also
      // behaves safely when triggered through unusual extension workflows.
      await ctx.waitForIdle();

      let relocatedSessionFile: string;

      try {
        relocatedSessionFile = writeRelocatedSession(
          ctx.sessionManager.getHeader(),
          ctx.sessionManager.getEntries(),
          target,
          sourceSessionFile,
        );
      } catch (error) {
        ctx.ui.notify(
          `Cannot prepare cwd switch: ${errorMessage(error)}`,
          "error",
        );
        return;
      }

      const oldCwd = ctx.cwd;

      try {
        const result = await ctx.switchSession(relocatedSessionFile, {
          withSession: async (freshCtx) => {
            // The replacement runtime is now bound to the new cwd.
            setTimeout(() => {
              freshCtx.ui.notify(
                `Working directory: ${shortPath(oldCwd)} → ${shortPath(target)}`,
                "info",
              );
            }, 150);
          },
        });

        if (result.cancelled) {
          // The new file is only a prepared copy; remove it when another
          // extension vetoes the session replacement.
          rmSync(relocatedSessionFile, { force: true });
          ctx.ui.notify("Working-directory switch was cancelled.", "info");
          return;
        }

        // The replacement session now owns the conversation. Remove the old
        // file so /resume shows this session only under its new cwd.
        rmSync(sourceSessionFile, { force: true });
      } catch (error) {
        // Best-effort cleanup. The active session remains the original one when
        // switchSession fails before replacement completes.
        rmSync(relocatedSessionFile, { force: true });
        ctx.ui.notify(
          `Working-directory switch failed: ${errorMessage(error)}`,
          "error",
        );
      }
    },
  });

  pi.registerTool({
    name: "switch_working_directory",
    label: "Switch Working Directory",

    description:
      "Move the current Pi session to another existing directory while preserving the conversation and reloading cwd-bound project resources such as skills, context, settings, extensions, and tools. Use this when the user asks to move, switch, go, or position the session in another directory, folder, repository, project, workspace, or newly created project. Do not use it merely to read or edit a file located elsewhere.",

    promptSnippet:
      "Switch the Pi session to another directory and reload that directory's project context",

    promptGuidelines: [
      "Use switch_working_directory when the user explicitly asks to change where the Pi session is working, including natural-language requests such as 'positionne-toi dedans', 'va dans ce projet', or 'switch to that folder'.",
      "Do not use switch_working_directory only because a task needs to inspect or modify a file outside the current directory.",
    ],

    parameters: Type.Object({
      path: Type.String({
        description:
          "Target directory. May be absolute, relative to the current working directory, or start with ~/.",
      }),
    }),

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      if (signal?.aborted) {
        return {
          content: [{ type: "text", text: "Working-directory switch cancelled." }],
          details: { cancelled: true },
          terminate: true,
        };
      }

      const target = expandPath(params.path, ctx.cwd);

      if (!existsSync(target)) {
        throw new Error(`Directory does not exist: ${target}`);
      }

      if (!statSync(target).isDirectory()) {
        throw new Error(`Not a directory: ${target}`);
      }

      if (target === resolve(ctx.cwd)) {
        return {
          content: [
            {
              type: "text",
              text: `Already working in ${shortPath(target)}.`,
            },
          ],
          details: { target, changed: false },
          terminate: true,
        };
      }

      // Queue the actual session replacement after this tool turn. JSON
      // encoding preserves spaces and special characters in paths.
      pi.sendUserMessage(`/cwd ${JSON.stringify(target)}`, {
        deliverAs: "followUp",
      });

      return {
        content: [
          {
            type: "text",
            text: `Queued working-directory switch to ${shortPath(target)}.`,
          },
        ],
        details: { target, queued: true },
        // Prevent an automatic model continuation before /cwd runs.
        terminate: true,
      };
    },
  });
}
