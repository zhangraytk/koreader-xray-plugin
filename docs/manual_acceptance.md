# Manual Acceptance Checklist

Use this checklist on a KOReader device or emulator after installing `xray.koplugin`.

## Auto Seed

- Enable `Menu -> X-Ray -> AI Settings -> Auto X-Ray seed on book open`.
- Open an EPUB with no X-Ray cache and a configured provider. Expected: a light metadata job starts or runs silently according to the setting.
- Open a PDF with no X-Ray cache and the same setting enabled. Expected: no background job starts, no job prompt appears, and no `xray_job_state.lua` is created only because of opening the PDF.
- From the PDF, manually run `Menu -> X-Ray -> Fetch AI Data`. Expected: manual light seed remains available.
- From the PDF, ask a question through AI Q&A. Expected: manual AI actions still work; only automatic open-time seed is skipped.

## AI Stability

- Run light seed once with Gemini and once with an OpenAI-compatible provider. Expected: successful cache or an endpoint-specific error in Background AI job.
- Run nearby-context enrichment once with Gemini and once with an OpenAI-compatible provider. Expected: extracted details merge into existing cache or produce a provider-specific error.
- Configure an OpenAI-compatible endpoint that rejects `thinking` or `response_format`. Expected: request retries without compatibility parameters where applicable.
- Ask a question from the X-Ray menu and from selected text. Expected: answer appears, follow-up works, and errors show provider details.
- Use `Add to characters` from the last AI answer. Expected: JSON with code fences or surrounding prose can still be parsed.

## Recovery And Diagnostics

- Start a job and cancel it from `Background AI job`. Expected: state becomes cancelled after the current request returns.
- Force a provider error, then open `Background AI job`. Expected: status includes error detail plus request/response byte counts when available.
- Leave a sidecar state with `status = "calling_ai"` or `status = "scanning"` and reopen the book. Expected: retry or light-seed fallback is available instead of a permanent `job_running` block.
- Use `Retry last job` and `Retry as light seed`. Expected: both start a new job from the saved state when a saved failed job exists.
- Open `View prompt` and `Text extraction diagnostics`. Expected: both show text without crashing; diagnostics sample only a small page window.
- Test a mocked or problematic document where page text extraction fails on one page. Expected: the failure is recorded in diagnostics and the menu remains usable.

## Performance

- Open a large book with existing cache. Expected: cache loads without text scanning.
- Open `Characters`, `Timeline`, and `Historical Figures` on a book with many entries. Expected: menus remain responsive enough for normal navigation.
- Verify large lists show short previews and page/search navigation before full details. Expected: detail text is still available after selecting one entry.
- On a PDF or long chapter, run `Characters in This Chapter`. Expected: scan is limited to the current page window rather than the full chapter.
- On a large PDF, manually run advanced analysis. Expected: extraction is capped by page/character limits and the status or diagnostics mention the limit when applicable.

## Local Smoke Tests

- Run `lua tests/smoke_ai_stability.lua`. Expected: all smoke tests pass.
- Run `luajit tests/smoke_ai_stability.lua`. Expected: all smoke tests pass.
- Run `luac -p xray.koplugin/*.lua xray.koplugin/prompts/*.lua`. Expected: no syntax errors.
- Run `git diff --check`. Expected: no whitespace errors.
