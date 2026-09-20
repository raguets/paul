# @siva-sub/pi-docparser reference

Expected extension tools:

```text
document_parse
document_search
document_screenshot
document_complexity
document_visual_analyze
```

## Direct PDF OCR

```text
document_parse({
  path: "./scans/report.pdf",
  ocr: "auto",
  ocrLanguage: "fra"
})
```

Built-in OCR uses native Tesseract when OCR is enabled and no OCR server is configured.

## Custom/offline Tesseract data

```text
document_parse({
  path: "./scans/report.pdf",
  ocr: "auto",
  ocrLanguage: "fra",
  tessdataPath: "<local tessdata>"
})
```

## Precise structure

```text
document_parse({
  path: "./document.pdf",
  format: "json",
  targetPages: "1-10"
})
```

## Search

```text
document_search({
  path: "./document.pdf",
  phrase: "example phrase"
})
```

## Visual candidate detection

```text
document_complexity({
  path: "./document.pdf"
})
```

Then target only relevant pages with `document_screenshot` or `document_visual_analyze`.
