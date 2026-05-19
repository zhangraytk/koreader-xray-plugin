-- Localization Manager for X-Ray Plugin (with .po support)

local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")

local Localization = {
    current_language = "tr",
    translations = {},
    available_languages = {},
    supported_languages = {
        tr = true,
        en = true,
        pt_br = true,
        es = true,
        zh = true,
    },
}

function Localization:getPluginDir()
    if self.plugin_dir then
        return self.plugin_dir
    end

    local candidates = {}
    local info = debug and debug.getinfo and debug.getinfo(1, "S") or {}
    local source = info.source or ""
    local path = source:match("^@(.+)$")
    if path then
        local source_dir = path:match("^(.*)/localization_xray%.lua$")
        if source_dir then
            table.insert(candidates, source_dir)
        end
    end

    local ok, DataStorage = pcall(require, "datastorage")
    if ok and DataStorage then
        local dir_ok, data_dir = pcall(function()
            return DataStorage.getFullDataDir and DataStorage:getFullDataDir() or DataStorage:getDataDir()
        end)
        if dir_ok and data_dir then
            table.insert(candidates, data_dir .. "/plugins/xray.koplugin")
        end
    end

    table.insert(candidates, "plugins/xray.koplugin")

    for _, dir in ipairs(candidates) do
        if dir and lfs.attributes(dir .. "/languages", "mode") == "directory" then
            self.plugin_dir = dir
            return self.plugin_dir
        end
    end

    return candidates[1] or "plugins/xray.koplugin"
end

function Localization:ensureDirectory(dir)
    local attr = lfs.attributes(dir)
    if attr then
        return attr.mode == "directory"
    end

    local parent = dir:match("^(.*)/[^/]+$")
    if parent and parent ~= "" and parent ~= dir and not self:ensureDirectory(parent) then
        return false
    end

    local success, err = lfs.mkdir(dir)
    if not success and not lfs.attributes(dir) then
        logger.error("Localization: Failed to create directory:", dir, err or "unknown error")
        return false
    end

    return true
end

-- Simple .po file parser
function Localization:parsePO(filepath)
    local translations = {}
    local file = io.open(filepath, "r")
    
    if not file then
        logger.warn("Localization: Cannot open .po file:", filepath)
        return nil
    end
    
    local msgid = nil
    local msgstr = nil
    local in_msgid = false
    local in_msgstr = false
    
    for line in file:lines() do
        if not line:match("^#") and not line:match("^%s*$") then
            -- Start of msgid
            if line:match('^msgid%s+"') then
                -- Save previous translation
                if msgid and msgstr then
                    translations[msgid] = msgstr
                end
                
                msgid = line:match('^msgid%s+"(.-)"')
                msgstr = nil
                in_msgid = true
                in_msgstr = false
            
            -- Start of msgstr
            elseif line:match('^msgstr%s+"') then
                msgstr = line:match('^msgstr%s+"(.-)"')
                in_msgid = false
                in_msgstr = true
            
            -- Continuation line
            elseif line:match('^"') then
                local continuation = line:match('^"(.-)"')
                if in_msgid and msgid then
                    msgid = msgid .. continuation
                elseif in_msgstr and msgstr then
                    msgstr = msgstr .. continuation
                end
            end
        end
    end
    
    -- Save last translation
    if msgid and msgstr then
        translations[msgid] = msgstr
    end
    
    file:close()
    
    -- Process escape sequences
    for key, value in pairs(translations) do
        value = value:gsub("\\n", "\n")
        value = value:gsub("\\t", "\t")
        value = value:gsub('\\"', '"')
        value = value:gsub("\\\\", "\\")
        translations[key] = value
    end
    
    return translations
end

-- Initialize localization system
function Localization:init()
    logger.info("Localization: Initializing...")
    
    -- Ensure settings directory exists
    self:ensureSettingsDir()
    
    -- Discover available language files
    self:discoverLanguages()
    
    -- Load saved language preference
    self:loadLanguage()
    
    -- Load translation file
    self:loadTranslations()
    
    logger.info("Localization: Initialized with language:", self.current_language)
end

-- Ensure the xray settings directory exists
function Localization:ensureSettingsDir()
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    
    local attr = lfs.attributes(xray_dir)
    if attr and attr.mode ~= "directory" then
        logger.warn("Localization: Settings path exists but is not a directory:", xray_dir)
    elseif self:ensureDirectory(xray_dir) then
        logger.info("Localization: Settings directory ready:", xray_dir)
    else
        logger.error("Localization: Failed to prepare settings directory:", xray_dir)
    end
end

-- Discover available .po files
function Localization:discoverLanguages()
    local plugin_dir = self:getPluginDir()
    local lang_dir = plugin_dir .. "/languages"
    
    self.available_languages = {}
    
    local attr = lfs.attributes(lang_dir)
    if not attr or attr.mode ~= "directory" then
        logger.warn("Localization: Languages directory not found:", lang_dir)
        return
    end
    
    for file in lfs.dir(lang_dir) do
        if file:match("%.po$") then
            local lang_code = file:match("^(.+)%.po$")
            if lang_code then
                table.insert(self.available_languages, lang_code)
                self.supported_languages[lang_code] = true
                logger.info("Localization: Found language:", lang_code)
            end
        end
    end
    
    table.sort(self.available_languages)
    logger.info("Localization: Discovered", #self.available_languages, "languages")
end

-- Load translations from .po file
function Localization:loadTranslations()
    local plugin_dir = self:getPluginDir()
    local po_file = plugin_dir .. "/languages/" .. self.current_language .. ".po"
    
    logger.info("Localization: Loading translations from:", po_file)
    
    local translations = self:parsePO(po_file)
    
    if translations then
        self.translations = translations
        logger.info("Localization: Loaded", self:tableSize(translations), "translations")
    else
        logger.warn("Localization: Failed to load .po file")
        
        -- Fallback to Turkish
        if self.current_language ~= "tr" then
            logger.info("Localization: Falling back to Turkish")
            self.current_language = "tr"
            po_file = plugin_dir .. "/languages/tr.po"
            translations = self:parsePO(po_file)
            if translations then
                self.translations = translations
            else
                self.translations = {}
                logger.error("Localization: Failed to load fallback!")
            end
        end
    end
end

-- Helper: count table size
function Localization:tableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Get translated string with better error handling
function Localization:t(key, ...)
    local translation = self.translations[key]
    
    if not translation or translation == "" then
        logger.warn("Localization: Missing translation key:", key)
        -- Return a user-friendly fallback instead of the key
        local fallbacks = {
            cache_saved = "💾 Saved!",
            cache_save_failed = "❌ Save failed",
            ai_fetch_complete = "✅ Fetched from %s\n\n📖 %s\n👤 %s\n\n👥 %d | 📍 %d | 🎨 %d | 📅 %d | 📜 %d\n\n%s",
            fetching_ai = "🤖 Fetching from %s...",
            no_api_key = "⚠️ No API key set!",
            menu_openai_model = "OpenAI-compatible model",
            openai_model_title = "OpenAI-compatible model",
            openai_model_hint = "Model name",
            openai_model_desc = "Use the exact model name exposed by your OpenAI-compatible server.",
            openai_model_saved = "OpenAI-compatible model saved",
            menu_openai_thinking = "Thinking mode",
            openai_thinking_title = "Thinking mode",
            openai_thinking_omit = "Omit parameter",
            openai_thinking_on = "Enabled",
            openai_thinking_off = "Disabled",
            openai_thinking_omitted = "Thinking parameter will be omitted",
            openai_thinking_enabled = "Thinking mode enabled",
            openai_thinking_disabled = "Thinking mode disabled",
            menu_openai_effort = "Thinking effort",
            openai_effort_title = "Thinking effort",
            openai_effort_saved = "Thinking effort saved: %s",
            menu_ai_qa = "AI Q&A",
            menu_ai_qa_result = "Last AI answer",
            ai_qa_title = "Ask AI",
            ai_qa_hint = "Ask about this book or selected text",
            ai_qa_selected_text_desc = "Selected text:\n%s",
            ai_qa_waiting = "Asking %s...\n\nModel: %s\n\nPlease wait.",
            ai_qa_answer_title = "AI Answer",
            ai_qa_no_question = "Please enter a question.",
            ai_qa_no_api_key = "AI API key is not set.\n\nSet it in Menu → X-Ray → AI Settings.",
            ai_qa_failed = "AI Q&A failed.",
            ai_qa_default_selected_question = "Explain the selected text in the context of this book.",
            ai_qa_no_answer = "No AI answer is available yet.",
            ai_qa_actions_title = "AI answer ready",
            ai_qa_view_answer = "View answer",
            ai_qa_follow_up = "Follow up",
            ai_qa_follow_up_hint = "Ask a follow-up question",
            ai_qa_add_character = "Add to characters",
            ai_job_started = "AI task started: %s / %s",
            ai_job_running = "AI task is already running.",
            ai_job_start_failed = "Could not start AI task.",
            ai_job_result_ready = "AI result is ready.",
            ai_job_cancel = "Cancel AI task",
            ai_job_cancelled = "AI task cancelled.",
            ai_character_extract_failed = "Could not extract character JSON.",
            ai_character_confirm_title = "Add character?",
            ai_character_conflict_with = "Possible conflict with existing character: %s",
            ai_character_merge_empty = "Merge empty fields",
            ai_character_overwrite_fields = "Overwrite selected fields",
            ai_character_add_new = "Add as new character",
            ai_character_saved = "Character saved",
            aliases = "Aliases",
            evidence = "Evidence",
            confidence = "Confidence",
            close = "Close",
            menu_gemini_settings = "Gemini settings",
            menu_chatgpt_settings = "ChatGPT settings",
            menu_chatgpt_model = "ChatGPT model",
            chatgpt_model_title = "ChatGPT model",
            chatgpt_model_hint = "Model name",
            chatgpt_model_desc = "Official OpenAI model name.",
            chatgpt_model_saved = "ChatGPT model saved",
            menu_openai_compatible_settings = "OpenAI-compatible settings",
            menu_openai_compatible_key = "OpenAI-compatible API key",
            openai_compatible_key_title = "OpenAI-compatible API key",
            openai_compatible_key_hint = "sk-...",
            openai_compatible_key_desc = "API key for the configured OpenAI-compatible endpoint.",
            openai_compatible_key_saved = "OpenAI-compatible API key saved",
            provider_selected = "%s selected",
            gemini_model_saved = "Gemini model saved",
            gemini_custom_model = "Custom Gemini model",
            menu_custom_providers = "Custom providers",
            custom_provider_add = "Add custom provider",
            custom_provider_edit = "Edit provider",
            custom_provider_saved = "Provider saved",
            custom_provider_deleted = "Provider deleted",
            custom_provider_editor_desc = "Enter fields separated by | as: Name|Endpoint|Model|APIKey|thinking(omit/enabled/disabled)|effort(high/max)",
            analysis_mode_title = "AI analysis mode",
            analysis_mode_metadata = "Light mode (title only)",
            analysis_mode_local_candidates = "Local candidate boost (recommended)",
            analysis_mode_chunked = "Chunked text boost",
            menu_enrich_nearby_context = "Enrich characters from nearby context",
            menu_background_job = "Background AI job",
            background_job_started = "AI analysis started. The reader may pause during network requests.",
            background_job_done = "AI analysis complete. X-Ray data is ready.",
            background_job_failed = "AI analysis failed.",
            background_job_cancel = "Cancel current job",
            background_job_cancelled = "AI analysis cancelled.",
            background_job_cancel_requested = "Cancel requested. The current network request may finish first.",
            background_job_resume = "Resume job",
            background_job_none = "No background job found.",
            background_job_view_prompt = "View prompt",
            background_job_prompt_not_ready = "Prompt is not ready yet. It will appear after scanning starts an AI request.",
            text_extraction_diagnostics = "Text extraction diagnostics",
            menu_auto_metadata = "Auto X-Ray seed on book open",
            auto_metadata_silent = "On, silent",
            auto_metadata_visible = "On, show notifications",
            auto_metadata_disabled = "Off",
            auto_metadata_saved = "Auto X-Ray seed setting saved",
            menu_context_char_limit = "Nearby context length",
            context_char_limit_desc = "Characters of nearby reading context used when enriching characters from the current position. Default: 500.",
            context_char_limit_saved = "Nearby context length saved: %d",
        }
        translation = fallbacks[key] or key
    end
    
    -- Format with arguments
    if select('#', ...) > 0 then
        local success, result = pcall(string.format, translation, ...)
        if success then
            return result
        else
            logger.warn("Localization: Format error for key:", key)
            logger.warn("Localization: Error:", result)
            logger.warn("Localization: Args count:", select('#', ...))
            -- Print arguments for debugging
            for i = 1, select('#', ...) do
                local arg = select(i, ...)
                logger.warn("Localization: Arg", i, "type:", type(arg), "value:", tostring(arg))
            end
            return translation
        end
    end
    
    return translation
end

-- Load/save language preference
function Localization:loadLanguage()
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local language_file = settings_dir .. "/xray/language.txt"
    
    local file = io.open(language_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        if content then
            content = content:gsub("^%s+", ""):gsub("%s+$", "")
            if #content > 0 and self:languageExists(content) then
                self.current_language = content
                logger.info("Localization: Loaded language from file:", content)
                return
            elseif #content > 0 then
                logger.warn("Localization: Saved language is not available:", content)
            end
        end
    end
    
    self.current_language = "tr"
    logger.info("Localization: Using default language: tr")
end

function Localization:languageExists(lang_code)
    for _, code in ipairs(self.available_languages) do
        if code == lang_code then
            return true
        end
    end

    return self.supported_languages[lang_code] == true
end

function Localization:getLanguage()
    return self.current_language
end

function Localization:getLanguageName()
    return self.translations["language_name"] or self.current_language
end

function Localization:setLanguage(lang_code)
    if not self:languageExists(lang_code) then
        logger.warn("Localization: Cannot set non-existent language:", lang_code)
        return false
    end
    
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    
    logger.info("Localization: Attempting to save language to:", xray_dir)
    
    if not self:ensureDirectory(xray_dir) then
        logger.error("Localization: Cannot create settings directory:", xray_dir)
        return false
    end
    
    -- Write language file
    local language_file = xray_dir .. "/language.txt"
    logger.info("Localization: Writing to file:", language_file)
    
    local file, open_err = io.open(language_file, "w")
    if not file then
        logger.error("Localization: io.open failed. Error:", tostring(open_err))
        logger.error("Localization: Full path:", language_file)
        logger.error("Localization: Settings dir:", settings_dir)
        return false
    end
    
    local success, write_err = file:write(lang_code)
    file:close()
    
    if not success then
        logger.error("Localization: file:write failed. Error:", tostring(write_err))
        return false
    end
    
    logger.info("Localization: Language successfully written:", lang_code)
    
    -- Reload translations
    self.current_language = lang_code
    self:loadTranslations()

    local success, AIHelper = pcall(require, "aihelper")
    if success and AIHelper then
        AIHelper:loadLanguage()
    end
    
    return true
end

-- Reload translations (call this after editing .po files)
function Localization:reload()
    logger.info("Localization: Reloading translations...")
    self:loadTranslations()
    
    -- Clear cached translations in AIHelper if it exists
    local AIHelper = require("aihelper")
    if AIHelper and AIHelper.localization then
        AIHelper.localization = nil
    end
    
    logger.info("Localization: Reload complete")
end

return Localization
