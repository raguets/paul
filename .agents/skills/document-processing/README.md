# document-processing

Generic document-processing skill intended for the COMMON skill layer:

```text
G:\pi-workspace\.agents\skills\document-processing\
```

It complements `@siva-sub/pi-docparser`, `pi-office`, and structured-data tooling.

## Required extension

Install separately:

```powershell
pi install npm:@siva-sub/pi-docparser
```

Then reload or restart Pi.

The extension provides direct local PDF parsing, selective Tesseract OCR, text search with page/bounding-box locations, screenshots, complexity detection, and optional visual analysis.

## Install this skill

Copy the `document-processing` directory into:

```text
G:\pi-workspace\.agents\skills\
```

The resulting path should be:

```text
G:\pi-workspace\.agents\skills\document-processing\SKILL.md
```

## Intended behavior

For PDFs, the skill prefers direct parsing and `ocr: "auto"` rather than a manual PDF-to-images OCR pipeline.

For large Office spreadsheets, it uses document tools to understand the structure and then recommends structured-data processing for actual analysis.
