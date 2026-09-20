# Portability note — document-processing

This skill was migrated unchanged from the `pi-workspace` monorepo.

It prefers Pi runtime extensions for execution:

- `@siva-sub/pi-docparser` (`document_parse`, `document_search`,
  `document_screenshot`, `document_complexity`, `document_visual_analyze`);
- `pi-office` for some Office formats.

The strategy (direct text extraction first, selective OCR, targeted search,
visual inspection only on relevant pages, structured data to DuckDB) is
harness-neutral.

The `README.md` of this skill still shows installation paths of an older
layout (`G:\pi-workspace\.agents\skills\`). In the `paul` monorepo the skill is
a common skill under `paul/.agents/skills/document-processing/` and is
inherited structurally by every use case; no manual copy is needed.

## Status

| Harness | Status |
|---|---|
| Pi | Works as written when the extensions are installed. |
| Hermes | **Adaptation to do**: map the capabilities to Hermes tools (terminal + local parsers/OCR, or MCP). |
