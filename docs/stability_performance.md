# Stability And Performance Notes

This document records the current low-performance-device safeguards and recovery semantics for maintainers.

## Default Workflow

The default user path is intentionally light:

1. `Fetch AI Data` starts a metadata seed based on title and author.
2. `Enrich from nearby context` sends a compact window around the current reading position.
3. AI Q&A can extract focused character facts and merge them into the cache.
4. Local candidates and chunked full-text analysis are advanced manual fallback paths.

Opening a book should not synchronously scan heavy text. Automatic metadata seed generation must stay metadata-only.

## PDF Rules

- Automatic open-time metadata seed is skipped for PDF files.
- Manual PDF actions remain available: metadata seed, Q&A, nearby-context enrichment, and advanced scans.
- Advanced PDF scans must remain capped because PDF text extraction can be slow or unreliable on e-readers.

## Current Limits

| Area | Limit | Value |
|------|-------|-------|
| Text chunks | `TextAnalyzer.max_chunk_chars` | `14000` |
| Candidate contexts | `TextAnalyzer.max_candidate_contexts` | `2` |
| Reflowable scan pages | `TextAnalyzer.max_scan_pages` | `120` |
| PDF scan pages | `TextAnalyzer.max_pdf_scan_pages` | `40` |
| General scan chars | `TextAnalyzer.max_scan_chars` | `240000` |
| CJK candidate scan chars | `TextAnalyzer.max_cjk_scan_chars` | `60000` |
| Candidate names | `TextAnalyzer.max_candidate_names` | `500` |
| Diagnose sample pages | `TextAnalyzer.max_diagnose_sample_pages` | `3` |
| Chapter analysis text | `ChapterAnalyzer.max_text_chars` | `60000` |
| Chapter page text | `ChapterAnalyzer.max_page_text_chars` | `40000` |
| Chapter scanned characters | `ChapterAnalyzer.max_scan_characters` | `250` |
| JSON recovery scan | `AIHelper.max_json_scan_chars` | `60000` |
| Nearby context default | `context_char_limit` | `500` |

When changing these values, test on slow hardware or an emulator with large EPUB and PDF files. Prefer lowering synchronous work over increasing scan coverage.

## Job State

Background job state lives in the book sidecar as `xray_job_state.lua`.

Expected fields are optional for backward compatibility. Newer state may contain:

- `kind`
- `retry_count`
- `last_error_code`
- `last_error_detail`
- `request_size`
- `response_size`
- `status_code`
- `provider_type`
- compatibility retry notes, including stripped OpenAI-compatible request parameters

The in-memory active job flag is separate from sidecar `status`. A stale sidecar status such as `running`, `calling_ai`, or `scanning` after a crash must be recoverable and must not permanently return `job_running`.

Before starting a new job or making a new AI request, clear stale request diagnostics so a later failure does not show the previous task's HTTP status or byte counts.

## Diagnostics

Text extraction diagnostics should stay lightweight. They are for checking available document APIs and sampling the current or nearby pages, not for building full chunks.

Status views should prefer actionable controls:

- Show cancel only for an active in-memory job.
- Show retry or light-seed fallback for failed, cancelled, interrupted, or stale resumable jobs.
- Show prompt preview only when a saved prompt exists.
- Show provider and HTTP diagnostics when the request reached a provider.

## UI List Performance

Large `characters`, `locations`, `timeline`, `historical_figures`, and chapter-character lists should show short previews first. Full descriptions belong in the selected detail view.

For large books, prefer pagination and search over constructing one huge menu with every full description and callback closure at once.

## Smoke Tests

Run these before merging changes in AI parsing, job recovery, text extraction, or menu performance:

```bash
lua tests/smoke_ai_stability.lua
luajit tests/smoke_ai_stability.lua
luac -p xray.koplugin/*.lua xray.koplugin/prompts/*.lua
git diff --check
```

The smoke suite covers JSON recovery, PDF auto-skip, safe document API wrappers, lightweight diagnostics, scan caps, and stale job-state recovery.
