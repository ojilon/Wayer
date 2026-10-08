# 103 — PDF/text extraction: MuPDF vs Poppler vs none (render later, text now?)

## Goal
`native/documents/` foundation only today — decide the text-extraction path before any render dream.

## Touches
- `native/documents/src/document_engine.cpp`, `include/wayer/documents/*.hpp`, `native/MODULES.md` (documents depends on storage)
- `third_party/` future slot, `ui/DocumentActivity.java` (51 text path)

## How it works today
Text preview only (51). No PDF/Office parse. README: "libs go under native/third_party/ when ready."

## Guided tasks
1. Needs: text-search in PDF? page count? first-page text for preview? Rank — extraction (text) BEFORE render (pixels).
2. Options: MuPDF (AGPL/commercial — Play Store poison unless licensed — document + likely REJECT), Poppler (GPL-ish heavy — reject for phone), Pdfium (Chromium, BSD — big build, best license), QPDF-lite? For TEXT ONLY: `pdftotext`-class minimal? Evaluate binary size vs value. Likely answer: NONE yet — open PDFs via system viewer Intent (FileProvider) + show metadata (pages? via PdfRenderer API 21+ Java-side, no native!).
3. Java-first: `android.graphics.pdf.PdfRenderer` for page COUNT + first-page bitmap (no native). Implement count+thumbnail in DocumentActivity for `.pdf` before ANY native lib.
4. Office (`docx/xlsx/pptx` are ZIP+XML): unzip + `document.xml` text via miniz? (single-header ZIP, see 104.) Prototype `docx` text-extract behind flag if 2 felt easy.

## Stretch
- Full render? Park with license/size note. System viewer + count + text-extract covers 90%.

## Verify
- [ ] PDF shows count+first-page via PdfRenderer; no AGPL/GPL vendored; decision recorded.
