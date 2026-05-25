# 📖 X-Ray Plugin for KOReader

Transform your reading experience with AI-powered book analysis, just like Amazon Kindle X-Ray!

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-KOReader-green.svg)
![License](https://img.shields.io/badge/license-MIT-yellow.svg)

---

## 🎯 What is X-Ray Plugin?

X-Ray Plugin brings Amazon Kindle's beloved X-Ray feature to KOReader. Using Google Gemini or OpenAI-compatible chat APIs, it automatically extracts and organizes book context while keeping the data local after it is generated:

    👥 Characters - Names, descriptions, roles, occupations

    📍 Locations - Important places and their significance

    🛡️ Spoiler Free - Intelligent summaries that avoid revealing major plot twists

    ⏱️ Timeline - Key events in chronological order

    📜 Historical Figures - Real people mentioned in the book

    🎨 Themes - Main themes and ideas

    📝 Notes - Your personal character notes

All data is cached locally for offline use and works without internet after the initial fetch!



---

## ✨ Key Features

### 🤖 AI Integration

- **Google Gemini 3.1 Flash-Lite / 3 Flash / 3.1 Pro Preview** with Gemini 2.5 fallback options
- **OpenAI-compatible chat completions** including OpenAI, local gateways, proxies, and self-hosted compatible servers
- **Custom providers** with per-provider endpoint, model, API key, thinking mode, and reasoning effort
- **AI Q&A** from the X-Ray menu or selected text highlight dialog
- **Background AI jobs** so analysis can continue while you read
- **Nearby-context enrichment** to improve character data from the current reading position
- Smart JSON parsing with error recovery
- Language-aware prompts (Turkish/English/Português/Simplified Chinese etc.)

### 👥 Character Management

- Automatic character extraction from book title
- Detailed profiles: name, description, role, gender, occupation
- **Character search** with fuzzy matching
- **Chapter analysis**: See which characters appear in current chapter
- **Personal notes**: Add your own notes for each character
- **📊 Smart Menu Counters**: See live counts (e.g., "Characters (12)")

### 📖 Advanced Analysis

- **Timeline**: Important events in chronological order
- **Historical Figures**: Real people mentioned (with biographies!)
- **Locations**: Important places and their significance
- **Themes**: Main themes extracted by AI
- **Spoiler-Free**: AI is trained to avoid spoilers
- **🔍 Enhanced Historical Analysis**: Detects direct and indirect historical references

### 💾 Cache System

- **Unlimited validity**: Cache never expires
- **Offline usage**: Internet only needed for initial fetch
- **Per-book storage**: Each book has its own cache
- **Auto-load**: Cache loads automatically when opening a book
- **Cache v7 metadata**: Stores provider, model, analysis mode, and source stats for generated data
- **🌍 Multi-Language Support**: Interface + AI prompts

---

## 🚀 Quick Start

### 1. Installation

```bash
# Copy plugin to KOReader plugins directory
cp -r xray.koplugin ~/.config/koreader/plugins/

# Restart KOReader
```

### 2. Get a Free API Key

**Google Gemini (Recommended - FREE)**
1. Go to https://makersuite.google.com/app/apikey
2. Sign in with Google account
3. Click "Create API Key"
4. Copy the key (starts with `AIza...`)

**Alternative: ChatGPT (Paid)**
1. Go to https://platform.openai.com/api-keys
2. Create API key (starts with `sk-...`)

### 3. Configure Plugin

1. Open any book in KOReader
2. Go to **Menu → X-Ray → AI Settings**
3. Select **Google Gemini API Key**
4. Paste your API key
5. Done! ✅

### 4. Fetch Your First Book

1. Go to **Menu → X-Ray → Fetch AI Data** (veya "AI ile Bilgi Çek")
2. The default analysis is a light metadata seed based on title and author
3. Continue reading or open **Menu → X-Ray → Background AI job** to view status, prompt preview, diagnostics, resume, or cancel
4. Done! All data is now cached offline ✨

---

## 🧭 Default AI Workflow

X-Ray uses a low-cost, device-friendly workflow by default:

1. **Light metadata seed**: `Fetch AI Data` first asks AI for a compact X-Ray seed using the book title and author. This avoids scanning the whole book on slow devices.
2. **Nearby-context enrichment**: after reading further, use **Enrich characters from nearby context** to merge details from the current position into the cache.
3. **AI Q&A and character merge**: ask focused questions from the menu or selected text, then add useful extracted characters to the cache.
4. **Advanced local scanning**: local candidates and chunked full-text analysis remain available as manual fallback tools for books where metadata and nearby context are not enough.

Automatic X-Ray seed generation follows the same light metadata path. It does not start local candidate scans or chunked full-text scans when a book opens.

### PDF Behavior

- Automatic seed generation is skipped for PDF files, even when `auto_metadata_on_open` is enabled.
- Manual actions still work on PDF: light seed, AI Q&A, nearby-context enrichment, and advanced scans remain available from the menu.
- Advanced PDF scanning is capped by page and character limits to avoid long blocking extraction on low-performance readers.

---

## 📱 Usage

### Quick Access

- **Alt + X**: Quick X-Ray menu
- **Menu → X-Ray**: Full menu with all features
- **Gestures → X-Ray & All features**

### Main Features

#### 👥 Characters
```
Menu → X-Ray → Characters
```
- View all characters with descriptions
- Click any character for detailed info
- Search for specific characters

#### 📖 This Chapter
```
Menu → X-Ray → Characters in This Chapter
```
- See which characters appear in current chapter
- Shows occurrence frequency (e.g., "John (5x)")
- Quick access to character details

#### ⏱️ Timeline
```
Menu → X-Ray → Timeline
```
- Important events in order
- Chapter references
- Characters involved in each event

#### 📜 Historical Figures
```
Menu → X-Ray → Historical Figures
```
- Real people mentioned in the book
- Biographies and dates
- Context in the book

#### 📝 Character Notes
```
Menu → X-Ray → My Character Notes
```
- Add personal notes for each character
- Edit or delete existing notes
- Notes saved per book

#### 🤖 AI Q&A
```
Menu → X-Ray → AI Q&A
Highlight dialog → AI Q&A
```
- Ask questions about the current book
- Ask about selected text directly from the highlight dialog
- Uses the currently selected AI provider and model

#### 🔍 Enrich from Nearby Context
```
Menu → X-Ray → Enrich characters from nearby context
```
- Extracts text near the current reading position
- Sends a compact context window to AI
- Merges useful new character details with existing cached X-Ray data

#### ⏳ Background AI Job
```
Menu → X-Ray → Background AI job
```
- Shows current stage, provider, model, text source, and progress
- Lets you preview the prompt generated for the AI request
- Provides text extraction diagnostics
- Supports cancellation, retry, light-seed fallback, and resume for resumable job state
- Shows provider diagnostics such as HTTP status, error detail, request/response size, and OpenAI-compatible retry notes when available

### Advanced Features

#### 🌍 Change Language
```
Menu → X-Ray → Language / Dil
```
- Switch between languages
- Applies immediately (menu refreshes on next open)
- AI will fetch data in selected language

#### 🗑️ Clear Cache
```
Menu → X-Ray → Clear Cache
```
- Delete all cached data for current book
- Useful for re-fetching updated data
- Requires confirmation dialog

#### ⚙️ AI Provider Settings
```
Menu → X-Ray → AI Settings
```
- Set Gemini and OpenAI-compatible API keys
- Choose Gemini or OpenAI-compatible models
- Configure OpenAI-compatible endpoint URL
- Choose thinking mode: omit, enabled, or disabled
- Set reasoning effort for compatible providers
- Add, edit, delete, and select custom providers
- Configure automatic X-Ray seed generation when a book opens
- Configure the nearby-context character limit

#### 🔬 Advanced Scans
```
Menu → X-Ray → Fetch AI Data → Advanced analysis options
```
- Local candidate and chunked full-text analysis are advanced fallback paths
- Text extraction diagnostics use a light sample instead of scanning the whole book
- PDF and page-based documents use stricter scan caps
- Large result lists use short previews and pagination/search-first navigation

---

![photo_2025-10-30_13-38-30](https://github.com/user-attachments/assets/48e4b012-f0c1-43b0-9380-c5ca69c8cb6d)
![photo_2025-10-30_13-38-28](https://github.com/user-attachments/assets/60f292d4-acc3-42ef-8ae0-9a501719dd76)
![photo_2025-10-30_13-38-25](https://github.com/user-attachments/assets/2290087a-81e4-404b-bf6a-7fd8aa6f55bd)
![photo_2025-10-30_13-38-37](https://github.com/user-attachments/assets/0b451a75-966a-432d-93ff-83649f965c40)
![photo_2025-10-30_13-38-42](https://github.com/user-attachments/assets/8bf8a6cd-aa83-4f20-a096-924dd4ccd095)
![photo_2025-10-30_13-38-40](https://github.com/user-attachments/assets/c7924bf7-6775-46bb-ab04-c96cc1712b75)
![photo_2025-10-30_13-38-35](https://github.com/user-attachments/assets/345e805f-f34d-4051-8c0a-22c18a1f9825)
![photo_2025-10-30_13-38-33](https://github.com/user-attachments/assets/8c8aabd1-e8da-4690-a55d-d20fafc11484)


## 🛠️ Configuration

### config.lua (Optional)

Create `xray.koplugin/config.lua` for permanent settings:

```lua
return {
    -- API Keys
    gemini_api_key = "AIzaSy...",
    chatgpt_api_key = "sk-...",

    -- Optional: OpenAI-compatible endpoint
    -- Example: "https://your-host/v1/chat/completions"
    chatgpt_endpoint = "https://api.openai.com/v1/chat/completions",
    chatgpt_model = "gpt-4o-mini",
    chatgpt_thinking_mode = "omit", -- "omit", "enabled", or "disabled"
    chatgpt_reasoning_effort = "high", -- "high" or "max"

    -- Default AI Provider
    default_provider = "gemini",  -- or "chatgpt"

    -- Gemini Model Selection
    gemini_model = "gemini-3.1-flash-lite",

    -- Optional additional OpenAI-compatible providers
    custom_providers = {
        ["custom:local"] = {
            name = "Local LLM",
            endpoint = "http://localhost:8000/v1/chat/completions",
            model = "gpt-4o-mini",
            api_key = "",
            thinking_mode = "omit",
            reasoning_effort = "high",
        },
    },

    -- Settings
    settings = {
        auto_fetch_on_open = false,
        auto_metadata_on_open = true,
        auto_metadata_silent = true,
        context_char_limit = 500,
        cache_duration_days = -1,
        max_characters = 20,
    }
}
```

### File Locations

```
~/.config/koreader/
├── cache/xray/                 # Book data cache
│   └── book_hash_*.json
├── settings/xray/              # Plugin settings
│   ├── language.txt            # Selected language
│   ├── *_api_key.txt           # Saved provider keys
│   ├── *_model.txt             # Saved model preferences
│   ├── custom_providers.json   # Custom OpenAI-compatible providers
│   └── notes/                  # Character notes
│       └── book_hash_*.json
├── <book sidecar>/             # KOReader per-book sidecar directory
│   ├── xray_cache.lua          # X-Ray cache
│   ├── xray_notes.lua          # Character notes
│   └── xray_job_state.lua      # Background job state
└── plugins/xray.koplugin/      # Plugin files
    ├── main.lua
    ├── localization.lua
    ├── aihelper.lua
    ├── cachemanager.lua
    ├── jobmanager.lua
    ├── textanalyzer.lua
    ├── chapteranalyzer.lua
    ├── characternotes.lua
    └── config.lua (optional)
```

---

## 💡 Tips & Tricks

### For Best Results

1. **Use original book titles**: "War and Peace" works better than "wp.epub"
2. **Include author name**: Helps AI identify the correct book
3. **Gemini Flash is great**: Free, fast, and accurate for most books
4. **Cache once, use forever**: No need to re-fetch unless you want updates
5. **Use nearby enrichment after you meet new characters**: It can improve cached data from your current reading position
6. **Use custom providers for local or proxy models**: Any OpenAI-compatible chat completions endpoint can be configured

### Character Search Tips

- Search works with partial names: "john" finds "John Smith"
- Case-insensitive: "JOHN" = "john" = "John"
- First name search: "John" finds "John Smith"

### Historical Figures Detection

The plugin intelligently detects:
- **Direct references**: "Napoleon Bonaparte appears in Chapter 5"
- **Indirect references**: "The 1860s nihilist movement" → Adds key figures
- **Philosophical references**: Characters discussing "Hegel" → Adds Hegel
- **Period atmosphere**: Important figures of the book's era

Examples:
- **"Demons" (Dostoevsky)**: Finds Sergei Nechayev, Alexander Herzen, Vissarion Belinsky
- **"War and Peace"**: Finds Napoleon, Kutuzov, Alexander I
- **"1984"**: No historical figures (modern dystopia)

---

## 📚 Example Use Cases

### Classic Literature: "Crime and Punishment"

```
✓ Characters (15)
  - Raskolnikov (protagonist, student)
  - Sonya (poor girl, religious)
  - Porfiry (investigator)

✓ Timeline (8 events)
  - Chapter 1: Raskolnikov plans the crime
  - Chapter 2: The murder takes place
  - Chapter 5: First interrogation

✓ Historical Context
  - 1860s Russian nihilism movement
  - St. Petersburg urban poverty
```

### Historical Fiction: "War and Peace"

```
✓ Characters (100+) organized
✓ Historical Figures (20+)
  - Napoleon Bonaparte (1769-1821)
  - Mikhail Kutuzov (1745-1813)
  - Alexander I of Russia

✓ Locations (15+)
  - Moscow, Petersburg, Austerlitz

✓ Timeline
  - Battle of Austerlitz (1805)
  - French invasion of Russia (1812)
  - Battle of Borodino (1812)
```

### Modern Fiction: "The Great Gatsby"

```
✓ Characters (12)
  - Jay Gatsby (mysterious millionaire)
  - Nick Carraway (narrator)
  - Daisy Buchanan

✓ Themes
  - American Dream
  - Wealth and class
  - Love and obsession

✓ Locations
  - West Egg, East Egg, New York City
```

---

## 🌍 Supported Languages

### Interface Languages
- 🇹🇷 **Turkish** (Türkçe)
- 🇬🇧 **English**
- 🇵🇹 **Brazilian Português**
- 🇨🇳 **Simplified Chinese** (简体中文)

### AI Data Languages
AI automatically provides data in the selected interface language:
- Turkish interface → AI responses in Turkish
- English interface → AI responses in English
- Brazilian Português interface → AI responses in Português
- Simplified Chinese interface → AI responses in Simplified Chinese

### Adding New Languages

1. Edit `main.lua`
2. Add new language code (e.g., `de` for German)
3. Translate all strings in `de.po = { ... }`
4. Add prompt templates in `de.lua`
5. Done! 🎉

---

## 🔧 Technical Details

### Architecture

```
main.lua           → Plugin core, menu management
localization.lua   → Multi-language support
aihelper.lua       → AI integration (Gemini/OpenAI-compatible)
cachemanager.lua   → Cache storage and retrieval
jobmanager.lua     → Background AI job state and execution
textanalyzer.lua   → Local text extraction, chunking, and character candidates
chapteranalyzer.lua → Chapter text analysis
characternotes.lua → Personal notes management
```

### AI Models

| Model | Cost | Speed | Quality | Token Limit |
|-------|------|-------|---------|-------------|
| Gemini 3.1 Flash-Lite | Provider-dependent | Fast | Good | Provider limit |
| Gemini 3 Flash Preview | Provider-dependent | Fast | Good | Provider limit |
| Gemini 3.1 Pro Preview | Provider-dependent | Medium | Excellent | Provider limit |
| Gemini 2.5 Flash / Pro | Provider-dependent | Fast/Medium | Good/Excellent | Provider limit |
| OpenAI-compatible models | Provider-dependent | Varies | Varies | Provider limit |

### Cache Format

```json
{
  "book_title": "Crime and Punishment",
  "author": "Fyodor Dostoevsky",
  "cached_at": 1735563600,
  "cache_version": "7.0",
  "analysis_mode": "metadata",
  "provider_id": "gemini",
  "provider_name": "Google Gemini",
  "model": "gemini-3.1-flash-lite",
  "source_stats": {},
  "characters": [...],
  "locations": [...],
  "timeline": [...],
  "historical_figures": [...],
  "themes": [...],
  "summary": "..."
}
```

Optional v7 fields may include `seed_mode`, `enrichment_history`, `last_provider_id`, `last_model`, `source_stats`, and `last_error`. Older cache files remain compatible.

### Background Job State

Background jobs store resumable state in `xray_job_state.lua` next to the book. Newer state can include `kind`, `retry_count`, `last_error_code`, `last_error_detail`, `request_size`, `response_size`, `status_code`, `provider_type`, and compatibility retry notes. A stale `running` state left behind by a crash is treated as recoverable instead of blocking retry forever.

### Performance Safeguards

- Opening a book and building menus avoids heavy text scans.
- Text extraction diagnostics sample only the current area and a few pages.
- Nearby-context enrichment uses a configurable compact context window.
- PDF and page-based advanced scans use page and character caps.
- Chapter character analysis limits extracted text and scanned character count.
- Large character, location, timeline, and historical-figure lists show short previews with paging/search before full detail.

### Local Smoke Tests

```bash
lua tests/smoke_ai_stability.lua
luajit tests/smoke_ai_stability.lua
luac -p xray.koplugin/*.lua xray.koplugin/prompts/*.lua
git diff --check
```

---

## ❓ FAQ

**Q: Is the API key safe?**
A: Yes, it's stored locally in KOReader. Never shared.

**Q: How much does it cost?**
A: Google Gemini has a generous free tier. Most users never pay.

**Q: Does it work offline?**
A: Yes! After initial fetch, everything is cached locally.

**Q: Can I use it on multiple devices?**
A: Yes, but cache is per-device. Fetch once per device.

**Q: Will it give spoilers?**
A: No! AI is explicitly instructed to avoid spoilers.

**Q: What if the book is not recognized?**
A: AI will try its best. You can also manually edit cache files.

**Q: Can I edit the data?**
A: Yes, cache files are Lua tables stored next to the book by KOReader document settings. Edit carefully with any text editor.

**Q: Can I use a local LLM or proxy?**
A: Yes. Configure an OpenAI-compatible endpoint, or add a custom provider with its own endpoint, model, and API key.

**Q: What does "thinking mode" do?**
A: It controls whether OpenAI-compatible requests send a `thinking` parameter. Use "omit" for maximum compatibility.

**Q: What is automatic X-Ray seed generation?**
A: When enabled, opening a book with no cache can start a quiet, lightweight title/author analysis job if an API key is available.

**Q: Does it support graphic novels?**
A: Not yet. Text-based books only.

**Q: What about DRM-protected books?**
A: Plugin works with any book KOReader can open.

**Q: Can I contribute?**
A: Yes! See Contributing section below.

---

## 🐛 Troubleshooting

### "API key not set"
→ Go to Menu → X-Ray → AI Settings → Set API key

### "Failed to fetch AI data"
- Check internet connection
- Verify API key is correct (copy-paste from provider)
- Try clearing and re-entering API key
- Check API quota (Gemini free tier has limits)
- For OpenAI-compatible servers, verify endpoint ends with `/v1/chat/completions` or let the plugin normalize a base URL
- Try setting thinking mode to "omit" if the server rejects extra compatibility parameters

### Background job failed
- Open **Menu → X-Ray → Background AI job**
- Review status, prompt preview, HTTP/error details, compatibility retry notes, and text extraction diagnostics
- Retry failed/interrupted jobs, resume resumable jobs, or retry as light metadata seed
- Cancel and retry with light metadata mode if local text extraction is unavailable for the document

### PDF opened with automatic seed enabled
- This is expected to do nothing automatically. PDF auto-seed is intentionally skipped to avoid expensive extraction on open.
- Use **Fetch AI Data** manually for a light seed, or use AI Q&A / advanced scans when needed.

### "No characters found in chapter"
- Make sure you're in a chapter (not title page)
- Try a different chapter
- Characters must be in main character list first

### Cache not loading
- Check file permissions in ~/.config/koreader/cache/xray/
- Try clearing cache and re-fetching

### Language not changing
- Language change requires menu reopen
- Check ~/.config/koreader/settings/xray/language.txt

---

## 🎯 Roadmap

### Planned Features
- [x] OpenAI-compatible and custom providers
- [x] AI Q&A from menu and selected text
- [x] Background analysis jobs
- [x] Nearby-context character enrichment
- [ ] Character relationship graph
- [ ] Custom AI prompts
- [ ] Quote extraction
- [ ] Series tracking (Book 1, 2, 3...)

### Under Consideration
- [ ] Character appearance highlighting in text
---

## 🤝 Contributing

Contributions are welcome! Here's how:

### Bug Reports
1. Open an issue on GitHub
2. Include KOReader version and e-Reader
3. Include error message (crash.log)
4. Describe steps to reproduce

### Feature Requests
1. Open an issue with "Feature Request" tag
2. Describe the feature
3. Explain use case

### Code Contributions
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit pull request

### Translations
1. Copy Translations\ `en.lua` and `en.po`
2. Add your language code
3. Translate all strings
4. Submit pull request

---

## 📜 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- **KOReader Team** - For the amazing e-reader platform
- **Testers** - For valuable feedback
- **You** - For using X-Ray Plugin! 📖✨

---

## 📮 Support

- **GitHub Issues**: Report bugs and request features
---

## 🌟 Star History

If you find this plugin useful, please star the repository! ⭐

---

**Made with ❤️ for book lovers everywhere**

*Happy Reading! 📖✨*
