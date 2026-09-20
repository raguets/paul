---
name: grill-me
description: Relentlessly interviews the user one question at a time to extract what's in their head into a durable, project-local capture file. Activates on "grill me", "grill me about <X>", "stress-test this plan", "pressure-test my thinking on <X>", "interview me about <X>", "drill me on <X>", "get this out of my head", "discovery session on <X>", "I need to think through <X> properly", or when another skill (e.g. create-use-case) asks it to resolve specific gaps. Gives a recommended answer with every question and checkpoints every answer to a markdown file on disk. NOT a content generator — it extracts, it doesn't write deliverables.
argument-hint: "[topic, plan, or decision to be grilled on]"
---

<!--
Adapted from grill-me by Aaron Gusinov — https://github.com/gusinov/grill-me
(commit 600ffe979f14d59492fbce6f6b25248ef8cb9849, MIT License, see LICENSE in
this directory and THIRD_PARTY_NOTICES.md at the repository root).
Changes: project-local capture path, caller contract (create-use-case),
explicit stop / "generate now" handling, harness-neutral wording.
-->

# Grill Me

You want something out of the user's head and into a durable system. Interview
the user relentlessly about every branch of the topic until you reach genuine
shared understanding. The real job is **extraction** — turning what only lives
in someone's head into durable, reusable, retrievable context.

This skill is harness-neutral. It only needs the standard file tools (read,
write/edit) and optionally a shell of the current harness. It does not require
any slash command, extension or harness-specific tool.

## The capture file is the whole point

A long interview fills the context window. If answers live only in your head,
you will eventually misremember, conflate, or drop one. So you **checkpoint to
disk after every single answer**. The file on disk — not your conversation
memory — is the source of truth. Never make the user ask you to save progress;
it's automatic and constant.

There are TWO distinct "checkpoints". Do not conflate them:

1. **Capture-file write** — appending each answer to the markdown file. A cheap
   local write. Happens after **EVERY single answer**, always.
2. **Ingest / indexing** — optional. Only if a retrieval layer (notes index,
   vector store…) is available in the current environment. Happens **once at
   session close**, or when the user explicitly asks. Never on a timer.

## When this runs

- The user says one of the trigger phrases above, or clearly wants to
  externalize a process / plan / decision / mental model.
- Another skill delegates a focused interview to it (see "Caller contract").

## When NOT to run this skill

- A single thing to save right now: that is a quick capture, not an interview.
- The user wants a deliverable written (copy, a doc, a post). This skill
  extracts thinking; it does not produce finished artifacts.

## Setup — do this BEFORE the first question

### 1. Resolve the capture path (project-local)

- When invoked by `create-use-case`: `.create-use-case/interview.md` at the
  root of the current project.
- When a caller gives an explicit path: use it.
- Otherwise: `.grill/<slug>.md` at the root of the current project, where
  `<slug>` is a short kebab-case name of the topic (prefix with the date,
  e.g. `.grill/2026-09-19-pricing-model.md`, if several sessions may exist).

Never write the capture file in a user-level or harness-specific directory
(`~/.pi/…`, `~/.hermes/…`, `~/.claude/…`).

### 2. Resume or create the file

- **If the file already exists**: read it entirely first. Do not ask again any
  question already answered there. Continue from the open branches and the
  "Open flags" section. Tell the user in one line that you are resuming.
- **Otherwise** create it immediately with the header (see structure below):
  title, date, the one-line goal, empty "Summary" and "Open flags" sections.

Tell the user the path in ONE line ("Capturing to `<path>` as we go."). Then
ask Q1.

## The checkpoint rule (non-negotiable)

After EVERY answer, BEFORE you ask the next question:

- Append a structured entry to the capture file: the question topic, the key
  facts and decisions from the answer (**in the user's own words where the
  wording matters**), and any flags (things they couldn't answer + who owns
  them).
- Update or correct earlier entries if a later answer changes them. Keep the
  running "Summary / key decisions" synthesis current.
- ONLY then ask the next question.

Never batch multiple answers into one write. One answer, one write.

## Interview method

- Ask **one question at a time.** For each, provide your **recommended answer**
  — your best inference from context — so the user can confirm, correct, or
  redirect.
- Resolve dependencies in order: settle the upstream decision before the ones
  that depend on it. Walk each branch to its end before moving to the next.
- If a question can be answered by **reading the project files, existing notes,
  or a document the user hands you**, do that instead of asking. Only surface
  what's net-new.
- When the user **can't answer** something, capture it as a flag with the right
  owner and move on. Don't stall on a gap.
- Keep going until the user says you're done, or you've covered every branch.
  Near the end, offer a completeness backstop: "Anything we haven't touched
  that should be in here?"

## Stopping early — the user is always in charge

The user may stop at any moment, e.g.:

```text
stop · on arrête · ça suffit · génère maintenant · arrête les questions ·
crée le projet avec ce que tu sais · on complétera plus tard
```

Then, immediately:

1. do not ask another question;
2. write the last answer (if any) to the capture file;
3. mark every question still open as `DEFERRED` in "Open flags";
4. update the "Summary / key decisions" section;
5. write `Status: STOPPED_BY_USER` in the header (or `Status: COMPLETE` when all
   branches were covered);
6. hand control back to the caller skill if there is one, passing along the
   user's instruction (e.g. "génère maintenant").

## Caller contract (when another skill delegates the interview)

A caller such as `create-use-case` provides:

- the capture path;
- the precise list of gaps to clarify (e.g. readiness dimensions R5, R8);
- what is already known and must not be asked again.

In that mode:

- ask only about the listed gaps (and their direct dependencies);
- keep the Q&A log grouped or tagged by gap id (e.g. `### Q3 — R8 human validation`);
- when the listed gaps are resolved, or the user stops, finish the capture file
  and **return control to the caller in the same turn**: re-read the caller's
  state file and continue its procedure. The end of the interview is not the
  end of the caller's mission.

## Capture file structure

```markdown
# {Topic}: Grill / Discovery Notes
Date: {YYYY-MM-DD} · Goal: {one line} · Status: IN_PROGRESS | COMPLETE | STOPPED_BY_USER

## Summary / key decisions
(running synthesis, updated as you go)

## Q&A log

### Q1 — {topic or gap id}
- Asked: {the question}
- Recommended: {your recommended answer}
- Captured: {facts, decisions, the user's words verbatim where it matters}
- Flags: {open item -> owner}

### Q2 — {topic}
...

## Open flags (pending input)
- {item} -> {who/what can answer}  (DEFERRED when the user stopped the interview)
```

## At the end — reconcile, then graduate

1. **Reconcile.** Re-read the capture file, fix contradictions or gaps inline,
   and make "Summary / key decisions" a clean standalone TL;DR.
2. **Make it searchable** (optional). If a retrieval layer is available, index
   the file. If that step fails or none exists, say so — don't pretend.
3. **Propose graduating the insights** — propose, don't auto-edit: a curated
   knowledge page, a task/instructions file, an improvement to an existing
   skill, or a durable rule.
4. **Recap** in a few lines: what's captured (+ path), what's still flagged,
   and the single suggested next step. When a caller skill is waiting, the
   recap is one line and the caller continues immediately.

## Why this skill exists

The hardest part of building a good operating system is extraction — getting
what's in someone's head into the system as reusable context. Grilling
thoroughly up front gets a skill, a plan, or a strategy to 90% on the first
pass; the capture file makes that extraction durable.
