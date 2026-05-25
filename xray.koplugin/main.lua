-- X-Ray Plugin for KOReader v2.0.0

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")
local Screen = require("device").screen

local XRayPlugin = WidgetContainer:new{
    name = "xray",
    is_doc_only = true,
}

function XRayPlugin:init()
    self.ui.menu:registerToMainMenu(self)
    
    -- Load localization module
    local Localization = require("localization_xray")
    self.loc = Localization
    self.loc:init() -- Load saved language preference
    
    self:onDispatcherRegisterActions()
    
    logger.info("XRayPlugin v1.0.0: Initialized with language:", self.loc:getLanguage())
end

function XRayPlugin:onReaderReady()
    -- Auto-load cache when book is opened
    local has_cache = self:autoLoadCache()
    self:loadBackgroundJob()
    if not has_cache then
        self:maybeStartInitialMetadataJob()
    end
    self:registerAIQuestionHighlightAction()
end

function XRayPlugin:onDispatcherRegisterActions()
    
    local Dispatcher = require("dispatcher")
    
    -- X-Ray Quick Menu action
    Dispatcher:registerAction("xray_quick_menu", {
        category = "none",
        event = "ShowXRayQuickMenu",
        title = self.loc:t("quick_menu_title") or "X-Ray Quick Menu",
        general = true,
        separator = true,
    })
    
    -- X-Ray Characters action
    Dispatcher:registerAction("xray_characters", {
        category = "none",
        event = "ShowXRayCharacters",
        title = self.loc:t("menu_characters") or "Characters",
        general = true,
    })
    
    -- X-Ray Chapter Characters action
    Dispatcher:registerAction("xray_chapter_characters", {
        category = "none",
        event = "ShowXRayChapterCharacters",
        title = self.loc:t("menu_chapter_characters") or "Chapter Characters",
        general = true,
    })
    
    -- X-Ray Timeline action
    Dispatcher:registerAction("xray_timeline", {
        category = "none",
        event = "ShowXRayTimeline",
        title = self.loc:t("menu_timeline") or "Timeline",
        general = true,
    })
    
    -- X-Ray Historical Figures action
    Dispatcher:registerAction("xray_historical", {
        category = "none",
        event = "ShowXRayHistorical",
        title = self.loc:t("menu_historical_figures") or "Historical Figures",
        general = true,
    })

    -- X-Ray Themes action
    Dispatcher:registerAction("xray_themes", {
        category = "none",
        event = "ShowXRayThemes",
        title = self.loc:t("menu_themes") or "Themes",
        general = true,
    })    
    
    -- X-Ray Locations action
    Dispatcher:registerAction("xray_locations", {
        category = "none",
        event = "ShowXRayLocations",
        title = self.loc:t("menu_locations") or "Locations",
        general = true,
    })

    -- X-Ray AI Q&A action
    Dispatcher:registerAction("xray_ai_qa", {
        category = "none",
        event = "ShowXRayAIQuestion",
        title = self.loc:t("menu_ai_qa") or "AI Q&A",
        general = true,
    })
end

-- Event handlers for Dispatcher actions
function XRayPlugin:onShowXRayQuickMenu()
    self:showQuickXRayMenu()
    return true
end

function XRayPlugin:onShowXRayFullMenu()
    self:showFullXRayMenu()
    return true
end

function XRayPlugin:onShowXRayCharacters()
    self:showCharacters()
    return true
end

function XRayPlugin:onShowXRayChapterCharacters()
    self:showChapterCharacters()
    return true
end

function XRayPlugin:onShowXRayTimeline()
    self:showTimeline()
    return true
end

function XRayPlugin:onShowXRayHistorical()
    self:showHistoricalFigures()
    return true
end

function XRayPlugin:onShowXRayThemes()
    self:showThemes()
    return true
end

function XRayPlugin:onShowXRayLocations()
    self:showLocations()
    return true
end

function XRayPlugin:onShowXRayAIQuestion()
    self:showAIQuestionDialog()
    return true
end

function XRayPlugin:autoLoadCache()
    if not self.cache_manager then
        local CacheManager = require("cachemanager")
        self.cache_manager = CacheManager:new()
    end
    
    local book_path = self.ui.document.file
    logger.info("XRayPlugin: Auto-loading cache for:", book_path)
    local cached_data = self.cache_manager:loadCache(book_path)
    
    if cached_data then
        self.book_data = cached_data
        self.characters = cached_data.characters or {}
        self.locations = cached_data.locations or {}
        self.themes = cached_data.themes or {}
        self.summary = cached_data.summary
        self.timeline = cached_data.timeline or {}
        self.historical_figures = cached_data.historical_figures or {}
        if cached_data.author_info then
            self.author_info = cached_data.author_info
        else
            -- Eğer yapı düz ise (author_bio varsa)
            self.author_info = {
                name = cached_data.author,
                description = cached_data.author_bio,
                birthDate = cached_data.author_birth,
                deathDate = cached_data.author_death
            }
        end
        local cache_age = math.floor((os.time() - cached_data.cached_at) / 86400)
        
        logger.info("XRayPlugin: Auto-loaded from cache -", #self.characters, "characters,", 
                    cache_age, "days old")
        
        if #self.characters > 0 then
            self.xray_mode_enabled = true
            logger.info("XRayPlugin: X-Ray mode auto-enabled")
        end
        
        UIManager:show(InfoMessage:new{
            text = self.loc:t("xray_ready") .. "\n\n" ..
                   "👥 " .. #self.characters .. " " .. self.loc:t("characters_loaded") .. "\n" ..
                   "📍 " .. #self.locations .. " " .. self.loc:t("locations_loaded") .. "\n" ..
                   "🎨 " .. #self.themes .. " " .. self.loc:t("themes_loaded"),
            timeout = 3,
        })
        return true
    else
        logger.info("XRayPlugin: No cache found for auto-load")
    end
    return false
end

function XRayPlugin:applyBookData(book_data)
    self.book_data = book_data
    self.book_title = book_data.book_title
    self.author = book_data.author
    self.author_bio = book_data.author_bio
    self.author_birth = book_data.author_birth
    self.author_death = book_data.author_death
    self.summary = book_data.summary
    self.characters = book_data.characters or {}
    self.themes = book_data.themes or {}
    self.locations = book_data.locations or {}
    self.timeline = book_data.timeline or {}
    self.historical_figures = book_data.historical_figures or {}
    self.author_info = {
        name = book_data.author,
        description = book_data.author_bio,
        birthDate = book_data.author_birth,
        deathDate = book_data.author_death,
    }
    if #self.characters > 0 then
        self.xray_mode_enabled = true
    end
end

function XRayPlugin:getJobManager()
    if not self.job_manager then
        local JobManager = require("jobmanager")
        self.job_manager = JobManager:new()
    end
    return self.job_manager
end

function XRayPlugin:getCurrentBookPath()
    return self.ui and self.ui.document and self.ui.document.file or nil
end

function XRayPlugin:isCurrentBook(book_path)
    return book_path and self:getCurrentBookPath() == book_path
end

function XRayPlugin:formatAIError(default_key, error_code, error_msg)
    if error_code == "error_no_api_key" then
        return self.loc:t("ai_qa_no_api_key")
    elseif error_code == "error_cancelled" then
        return self.loc:t("ai_job_cancelled")
    elseif error_msg and #tostring(error_msg) > 0 then
        return tostring(error_msg)
    end
    return self.loc:t(default_key)
end

function XRayPlugin:getCompactCharactersForAI()
    local compact = {}
    for _, char in ipairs(self.characters or {}) do
        if type(char) == "table" and char.name and #tostring(char.name) > 0 then
            table.insert(compact, {
                name = tostring(char.name),
                aliases = type(char.aliases) == "table" and char.aliases or {},
            })
        end
        if #compact >= 80 then
            break
        end
    end
    return compact
end

function XRayPlugin:saveCurrentXRayCache()
    local book_path = self:getCurrentBookPath()
    if not book_path then return false end
    if not self.cache_manager then
        local CacheManager = require("cachemanager")
        self.cache_manager = CacheManager:new()
    end
    self.book_data = self.book_data or {}
    self.book_data.characters = self.characters or {}
    self.book_data.locations = self.locations or {}
    self.book_data.themes = self.themes or {}
    self.book_data.timeline = self.timeline or {}
    self.book_data.historical_figures = self.historical_figures or {}
    self.book_data.summary = self.summary or self.book_data.summary
    if self.author_info then
        self.book_data.author_info = self.author_info
    end
    return self.cache_manager:saveCache(book_path, self.book_data)
end

function XRayPlugin:getActiveAIJob(kind, book_path)
    local jobs = self.ai_jobs or {}
    local job = jobs[kind]
    if job and job.book_path == book_path and job.status == "running" then
        return job
    end
    return nil
end

function XRayPlugin:showAIJobRunning(kind)
    local book_path = self:getCurrentBookPath()
    local job = self:getActiveAIJob(kind, book_path)
    local text = self.loc:t("ai_job_running")
    if job and job.label then
        text = text .. "\n\n" .. job.label
    end
    local ButtonDialog = require("ui/widget/buttondialog")
    local dialog
    dialog = ButtonDialog:new{
        title = text,
        buttons = {
            {
                {
                    text = self.loc:t("ai_job_cancel"),
                    callback = function()
                        if job then job.cancelled = true end
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{
                            text = self.loc:t("ai_job_cancelled"),
                            timeout = 3,
                        })
                    end,
                },
            },
            {
                {
                    text = self.loc:t("close"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function XRayPlugin:startSimpleAIJob(kind, book_path, label, started_text, task, on_complete)
    self.ai_jobs = self.ai_jobs or {}
    if self:getActiveAIJob(kind, book_path) then
        return false, "already_running"
    end

    local job = {
        kind = kind,
        book_path = book_path,
        label = label,
        status = "running",
        started_at = os.time(),
        cancelled = false,
    }
    self.ai_jobs[kind] = job

    UIManager:show(InfoMessage:new{
        text = started_text or self.loc:t("ai_job_started"),
        timeout = 3,
    })

    UIManager:scheduleIn(0.1, function()
        local trap_ok, Trapper = pcall(require, "ui/trapper")
        if trap_ok and Trapper and Trapper.wrap and Trapper.dismissableRunInSubprocess then
            Trapper:wrap(function()
                local completed, result = Trapper:dismissableRunInSubprocess(function()
                    local success, data = pcall(task)
                    if success then
                        return data
                    end
                    return {
                        ok = false,
                        error_code = "error_exception",
                        error_msg = tostring(data),
                    }
                end, true)

                if job.cancelled then
                    job.status = "cancelled"
                    return
                end
                job.status = "done"

                if completed == false then
                    result = {
                        ok = false,
                        error_code = "error_cancelled",
                        error_msg = self.loc:t("ai_job_cancelled"),
                    }
                end

                if on_complete then
                    on_complete(result)
                end
            end)
            return
        end

        local ok, result = pcall(task)
        if not ok then
            result = {
                ok = false,
                error_code = "error_exception",
                error_msg = tostring(result),
            }
        end
        if job.cancelled then
            job.status = "cancelled"
            return
        end
        job.status = "done"
        if on_complete then
            on_complete(result)
        end
    end)

    return true
end
function XRayPlugin:loadBackgroundJob()
    local job_manager = self:getJobManager()
    local book_path = self.ui and self.ui.document and self.ui.document.file
    if not book_path then return end
    local state = job_manager:loadState(book_path)
    if state and state.status and state.status ~= "done" and state.status ~= "cancelled" then
        logger.info("XRayPlugin: Found background job state:", state.status)
    end
end

function XRayPlugin:shouldSkipAutoSeed(book_path, ui)
    if type(book_path) == "string" and book_path:lower():match("%.pdf$") then
        return true, "pdf"
    end
    local doc = ui and ui.document
    if doc and type(doc.getProps) == "function" then
        local ok, props = pcall(function() return doc:getProps() end)
        if ok and type(props) == "table" then
            local format = tostring(props.format or props.type or props.file_type or ""):lower()
            if format == "pdf" or format:find("pdf", 1, true) then
                return true, "pdf"
            end
        end
    end
    return false
end

function XRayPlugin:maybeStartInitialMetadataJob()
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local settings = self.ai_helper.settings or {}
    if settings.auto_metadata_on_open == false then
        return
    end

    local book_path = self.ui and self.ui.document and self.ui.document.file
    if not book_path then return end
    local skip, reason = self:shouldSkipAutoSeed(book_path, self.ui)
    if skip then
        logger.info("XRayPlugin: Initial metadata job skipped for", tostring(reason), "document:", book_path)
        return
    end

    local job_manager = self:getJobManager()
    local existing_job = job_manager:loadState(book_path)
    if existing_job and existing_job.status and existing_job.status ~= "done" and existing_job.status ~= "cancelled" then
        logger.info("XRayPlugin: Initial metadata job skipped; existing job:", existing_job.status)
        return
    end

    local selected_provider = self.ai_provider or self.ai_helper.default_provider or "gemini"
    local provider_config = self.ai_helper.providers[selected_provider]
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        logger.info("XRayPlugin: Initial metadata job skipped; provider has no API key")
        return
    end

    local title, author = self:getBookTitleAndAuthor()

    job_manager:start(self, {
        book_path = book_path,
        title = title,
        author = author,
        provider_id = selected_provider,
        provider_name = provider_config.name or "AI",
        model = provider_config.model or "",
        kind = "auto_metadata",
        provider_type = provider_config.type,
        analysis_mode = "metadata",
        reading_percent = 100,
        initial_metadata = true,
        silent = settings.auto_metadata_silent ~= false,
    })
end

function XRayPlugin:clampText(text, max_len)
    text = type(text) == "string" and text or tostring(text or "")
    max_len = max_len or 120
    text = text:gsub("%s+", " ")
    if #text > max_len then
        return text:sub(1, max_len) .. "..."
    end
    return text
end

function XRayPlugin:getSafeReadingPercent()
    local _, total_pages, progress = self:getReadingProgress()
    progress = tonumber(progress) or 100
    if total_pages <= 0 or progress <= 0 then progress = 100 end
    if progress < 1 then progress = 1 end
    if progress > 100 then progress = 100 end
    return progress
end

function XRayPlugin:getMenuPageBounds(total_count, page, page_size)
    page_size = page_size or 80
    total_count = tonumber(total_count) or 0
    local total_pages = math.max(1, math.ceil(total_count / page_size))
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end
    local start_index = ((page - 1) * page_size) + 1
    local end_index = math.min(total_count, page * page_size)
    return page, total_pages, start_index, end_index
end

function XRayPlugin:addPagingItems(items, total_count, page, total_pages, callback)
    if total_pages <= 1 then return end
    table.insert(items, { separator = true })
    if page > 1 then
        table.insert(items, {
            text = "< " .. tostring(page - 1) .. "/" .. tostring(total_pages),
            callback = function() callback(page - 1) end,
        })
    end
    if page < total_pages then
        table.insert(items, {
            text = "> " .. tostring(page + 1) .. "/" .. tostring(total_pages),
            callback = function() callback(page + 1) end,
        })
    end
end

function XRayPlugin:getPagedMenuTitle(title, total_count, page, total_pages)
    if total_pages and total_pages > 1 then
        return title .. " (" .. tostring(total_count) .. ") " .. tostring(page) .. "/" .. tostring(total_pages)
    end
    return title .. " (" .. tostring(total_count) .. ")"
end

function XRayPlugin:getMenuCounts()
    return {
        characters = self.characters and #self.characters or 0,
        locations = self.locations and #self.locations or 0,
        themes = self.themes and #self.themes or 0,
        timeline = self.timeline and #self.timeline or 0,
        historical_figures = self.historical_figures and #self.historical_figures or 0,
    }
end

-- Get current reading progress (works for EPUB, PDF, MOBI, etc.)
function XRayPlugin:getReadingProgress()
    -- Default values
    local current_page = 0
    local total_pages = 0
    local progress = 0
    
    if not self.ui or not self.ui.document then
        logger.warn("XRayPlugin: No document or UI available")
        return current_page, total_pages, progress
    end
    
    local doc = self.ui.document
    
    -- Get total pages
    local success_pages, pages = pcall(function() return doc:getPageCount() end)
    if success_pages and pages and pages > 0 then
        total_pages = pages
    else
        logger.warn("XRayPlugin: Could not get page count")
        return current_page, total_pages, progress
    end
    
    -- Try multiple methods to get current page
    local methods = {
        -- Method 1: Paging (for PDF, DjVu)
        function()
            if self.ui.paging and type(self.ui.paging.getCurrentPage) == "function" then
                return self.ui.paging:getCurrentPage()
            end
        end,
        -- Method 2: Rolling (for EPUB, MOBI)
        function()
            if self.ui.rolling and type(self.ui.rolling.getCurrentPage) == "function" then
                return self.ui.rolling:getCurrentPage()
            end
        end,
        -- Method 3: Document direct
        function()
            if type(doc.getCurrentPage) == "function" then
                return doc:getCurrentPage()
            end
        end,
        -- Method 4: View state
        function()
            if self.view and self.view.state and self.view.state.page then
                return self.view.state.page
            end
        end,
        -- Method 5: Document settings
        function()
            if self.ui.doc_settings then
                local settings = self.ui.doc_settings
                return settings:readSetting("last_page") or settings:readSetting("page")
            end
        end,
    }
    
    -- Try each method
    for i, method in ipairs(methods) do
        local success_method, page = pcall(method)
        if success_method and page and tonumber(page) then
            current_page = tonumber(page)
            logger.info("XRayPlugin: Got current page using method", i, ":", current_page)
            break
        end
    end
    
    -- If still no page, try one more fallback
    if current_page == 0 and self.ui.document then
        local success_fallback, fallback_page = pcall(function()
            -- Try to get from bookmark or last position
            if self.ui.bookmark and self.ui.bookmark.getCurrentPageNumber then
                return self.ui.bookmark:getCurrentPageNumber()
            end
        end)
        
        if success_fallback and fallback_page then
            current_page = tonumber(fallback_page) or 0
            logger.info("XRayPlugin: Got current page from fallback:", current_page)
        end
    end
    
    -- Calculate progress
    if total_pages > 0 and current_page > 0 then
        progress = math.floor((current_page / total_pages) * 100)
    end
    
    logger.info("XRayPlugin: Reading progress -", current_page, "/", total_pages, "=", progress .. "%")
    
    return current_page, total_pages, progress
end

function XRayPlugin:addToMainMenu(menu_items)
    logger.info("XRayPlugin: addToMainMenu called")
    
    self.ui:registerKeyEvents({
        ShowXRayMenu = {
            { "Alt", "X" },
            event = "ShowXRayMenu",
        },
    })
    
    local counts = self:getMenuCounts()
    local function safe_t(key)
        if self.loc and self.loc.t then
            return self.loc:t(key) or key
        end
        return key
    end
    
    menu_items.xray = {
        text = self.loc:t("menu_xray"),
        sorting_hint = "tools",
        callback = function()
            self:showQuickXRayMenu()
        end,
        hold_callback = function()
            self:showFullXRayMenu()
        end,
        sub_item_table = {
            {
                text = self.loc:t("menu_characters") .. (counts.characters > 0 and " (" .. counts.characters .. ")" or ""),
                keep_menu_open = true,
                callback = function()
                    self:showCharacters()
                end,
            },
            {
                text = self.loc:t("menu_chapter_characters"),
                keep_menu_open = true,
                callback = function()
                    self:showChapterCharacters()
                end,
            },
            {
                text = self.loc:t("menu_character_notes"),
                keep_menu_open = true,
                callback = function()
                    self:showCharacterNotes()
                end,
            },
            {
                text = self.loc:t("menu_timeline") .. (counts.timeline > 0 and " (" .. counts.timeline .. " " .. self.loc:t("events") .. ")" or ""),
                keep_menu_open = true,
                callback = function()
                    self:showTimeline()
                end,
            },
            { separator = true,},
            {
                text = self.loc:t("menu_historical_figures") .. (counts.historical_figures > 0 and " (" .. counts.historical_figures .. ")" or ""),
                keep_menu_open = true,
                callback = function()
                    self:showHistoricalFigures()
                end,
            },
            {
                text = self.loc:t("menu_locations") .. (counts.locations > 0 and " (" .. counts.locations .. ")" or ""),
                keep_menu_open = true,
                callback = function()
                    self:showLocations()
                end,
            },
            {
                text = self.loc:t("menu_author_info"),
                keep_menu_open = true,
                callback = function()
                    self:showAuthorInfo()
                end,
            },
            {
                text = self.loc:t("menu_summary"),
                keep_menu_open = true,
                callback = function()
                    self:showSummary()
                end,
            },
            {
                text = self.loc:t("menu_themes") .. (counts.themes > 0 and " (" .. counts.themes .. ")" or ""),
                keep_menu_open = true,
                callback = function()
                    self:showThemes()
                end,
            },
            { separator = true },
            {
                text = self.loc:t("menu_ai_qa"),
                keep_menu_open = true,
                callback = function()
                    self:showAIQuestionDialog()
                end,
            },
            {
                text = self.loc:t("menu_ai_qa_result"),
                keep_menu_open = true,
                callback = function()
                    self:showAIQuestionActions()
                end,
            },
            {
                text = self.loc:t("menu_fetch_ai"),
                keep_menu_open = true,
                callback = function()
                    self:fetchFromAI()
                end,
            },
            {
                text = self.loc:t("menu_enrich_nearby_context"),
                keep_menu_open = true,
                callback = function()
                    self:enrichFromNearbyContext()
                end,
            },
            {
                text = self.loc:t("menu_advanced_scan"),
                keep_menu_open = true,
                callback = function()
                    self:showAdvancedAnalysisMenu()
                end,
            },
            {
                text = self.loc:t("menu_background_job"),
                keep_menu_open = true,
                callback = function()
                    self:showBackgroundJobStatus()
                end,
            },
            {
                text = self.loc:t("menu_ai_settings"),
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = self.loc:t("menu_gemini_settings"),
                        keep_menu_open = true,
                        sub_item_table = {
                            {
                                text = self.loc:t("menu_gemini_key"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setGeminiAPIKey()
                                end,
                            },
                            {
                                text = self.loc:t("menu_gemini_model"),
                                keep_menu_open = true,
                                callback = function()
                                    self:selectGeminiModel()
                                end,
                            },
                        },
                    },
                    { separator = true },
                    {
                        text = self.loc:t("menu_chatgpt_settings"),
                        keep_menu_open = true,
                        sub_item_table = {
                            {
                                text = self.loc:t("menu_chatgpt_key"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setChatGPTAPIKey()
                                end,
                            },
                            {
                                text = self.loc:t("menu_chatgpt_model"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setProviderModelDialog("chatgpt", "chatgpt_model")
                                end,
                            },
                        },
                    },
                    {
                        text = self.loc:t("menu_openai_compatible_settings"),
                        keep_menu_open = true,
                        sub_item_table = {
                            {
                                text = self.loc:t("menu_openai_compatible_key"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setOpenAICompatibleAPIKey()
                                end,
                            },
                            {
                                text = self.loc:t("menu_openai_endpoint"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setOpenAICompatibleEndpoint()
                                end,
                            },
                            {
                                text = self.loc:t("menu_openai_model"),
                                keep_menu_open = true,
                                callback = function()
                                    self:setOpenAICompatibleModel()
                                end,
                            },
                            {
                                text = self.loc:t("menu_openai_thinking"),
                                keep_menu_open = true,
                                callback = function()
                                    self:selectOpenAIThinkingMode()
                                end,
                            },
                            {
                                text = self.loc:t("menu_openai_effort"),
                                keep_menu_open = true,
                                callback = function()
                                    self:selectOpenAIReasoningEffort()
                                end,
                            },
                        },
                    },
                    {
                        text = self.loc:t("menu_custom_providers"),
                        keep_menu_open = true,
                        callback = function()
                            self:showCustomProviderMenu()
                        end,
                    },
                    {
                        text = self.loc:t("menu_auto_metadata"),
                        keep_menu_open = true,
                        callback = function()
                            self:toggleAutoMetadataOnOpen()
                        end,
                    },
                    {
                        text = self.loc:t("menu_context_char_limit"),
                        keep_menu_open = true,
                        callback = function()
                            self:setContextCharLimit()
                        end,
                    },
                    { separator = true },
                    {
                        text = self.loc:t("menu_provider_select"), 
                        keep_menu_open = true,
                        callback = function()
                            self:selectAIProvider()
                        end,
                    },
                }
            },
            {separator = true,},
            {
                text = self.loc:t("menu_clear_cache"),
                keep_menu_open = true,
                callback = function()
                    self:clearCache()
                end,
            },
            {
                text = self.loc:t("menu_xray_mode") .. " " .. (self.xray_mode_enabled and self.loc:t("xray_mode_active") or self.loc:t("xray_mode_inactive")),
                keep_menu_open = true,
                callback = function()
                    self:toggleXRayMode()
                end,
            },
            {
                text = self.loc:t("menu_language"),
                keep_menu_open = true,
                callback = function()
                    self:showLanguageSelection()
                end,
            },
            { separator = true },
            {
                text = self.loc:t("menu_about"),
                keep_menu_open = true,
                callback = function()
                    self:showAbout()
                end,
            },
        }
    }
    
    logger.info("XRayPlugin: Menu item 'xray' added successfully with Gemini Model option")
end

function XRayPlugin:showLanguageSelection()
    local ButtonDialog = require("ui/widget/buttondialog")
    local InfoMessage = require("ui/widget/infomessage")
    
    local current_lang = "tr"
    if self.loc then
        current_lang = self.loc:getLanguage()
    end

    local function changeLang(lang_code, lang_name)
        UIManager:close(self.ldlg)

        if self.loc then
            local save_success = self.loc:setLanguage(lang_code)
            
            if save_success then
                UIManager:show(InfoMessage:new{
                    text = "✅ " .. self.loc:t("language_changed") .. "\n\n" .. self.loc:t("please_restart"),
                    timeout = 4 
                })
            else
                UIManager:show(InfoMessage:new{
                    text = "❌ Language save failed!\n\nPlease check:\n1. Storage is writable\n2. Have enough free space",
                    timeout = 4 
                })
            end
        end
    end
    
    local buttons = {
        {
            {
                text = "Türkçe" .. (current_lang == "tr" and " ✓" or ""), 
                callback = function() changeLang("tr", "Türkçe") end
            }
        },
        {
            {
                text = "English" .. (current_lang == "en" and " ✓" or ""), 
                callback = function() changeLang("en", "English") end
            }
        },
        {
            {
                text = "Português" .. (current_lang == "pt_br" and " ✓" or ""), 
                callback = function() changeLang("pt_br", "Português") end
            }
        },
        {
            {
                text = "Español" .. (current_lang == "es" and " ✓" or ""), 
                callback = function() changeLang("es", "Español") end
            }
        },
        {
            {
                text = "简体中文" .. (current_lang == "zh" and " ✓" or ""),
                callback = function() changeLang("zh", "简体中文") end
            }
        },
    }
    
    self.ldlg = ButtonDialog:new{title = self.loc:t("language_title"), buttons = buttons}
    UIManager:show(self.ldlg)
end

function XRayPlugin:showCharacters(page)
    if not self.characters or #self.characters == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_character_data") or "No character data",
            timeout = 3,
        })
        return
    end
    
    local page_size = 60
    page = page or 1
    local current_page, total_pages, start_index, end_index = self:getMenuPageBounds(#self.characters, page, page_size)
    local items = {}
    
    -- Add search option
    table.insert(items, {
        text = self.loc:t("search_character") or "🔍 Search Character",
        callback = function()
            self:showCharacterSearch()
        end
    })
    
    for i = start_index, end_index do
        local char = self.characters[i]
        -- CRITICAL: Ensure char and char.name exist
        if char and type(char) == "table" then
            local name = char.name
            
            -- Ensure name is a string
            if type(name) ~= "string" or name == "" then
                name = self.loc:t("unknown_character") or "Unknown Character"
            end
            
            local text = "│ " .. name

            -- Add description if available
            if char.description and type(char.description) == "string" and #char.description > 0 then
                text = text .. "\n   " .. self:clampText(char.description, 120)
            elseif char.gender or char.occupation then
                local details = {}
                if char.gender and type(char.gender) == "string" then 
                    table.insert(details, char.gender) 
                end
                if char.occupation and type(char.occupation) == "string" then 
                    table.insert(details, char.occupation) 
                end
                if #details > 0 then
                    text = text .. "\n   " .. table.concat(details, ", ")
                end
            end
            
            -- CRITICAL: Ensure text is not nil
            if text and type(text) == "string" and #text > 0 then
                table.insert(items, {
                    text = text,
                    callback = function()
                        self:showCharacterDetails(char)
                    end
                })
            else
                logger.warn("XRayPlugin: Skipping character with invalid text at index", i)
            end
        else
            logger.warn("XRayPlugin: Skipping invalid character at index", i)
        end
    end
    
    self:addPagingItems(items, #self.characters, current_page, total_pages, function(next_page)
        self:showCharacters(next_page)
    end)

    if #items <= 1 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_character_data") or "No valid character data",
            timeout = 3,
        })
        return
    end
    
    local character_menu = Menu:new{
        title = self:getPagedMenuTitle(self.loc:t("menu_characters") or "Characters", #self.characters, current_page, total_pages),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(character_menu)
end

function XRayPlugin:showCharacterDetails(character)
    if not character then
        return
    end
    
    local function safeString(value, default)
        if value == nil then
            return default or self.loc:t("not_specified")
        elseif type(value) == "string" then
            return value
        elseif type(value) == "number" then
            return tostring(value)
        elseif type(value) == "table" then
            return json.encode(value)
        elseif type(value) == "function" then
            return self.loc:t("not_specified")
        else
            return tostring(value)
        end
    end
    
    local name = safeString(character.name, self.loc:t("unnamed_character"))
    local description = safeString(character.description, self.loc:t("no_description"))
    local role = safeString(character.role, self.loc:t("not_specified"))
    local gender = safeString(character.gender, self.loc:t("not_specified"))
    local occupation = safeString(character.occupation, self.loc:t("not_specified"))
    
    local text = string.format([[
%s %s

%s
%s

%s %s
%s %s
%s %s
]], self.loc:t("character_name"), name, 
    self.loc:t("description"), description,
    self.loc:t("role"), role,
    self.loc:t("gender"), gender,
    self.loc:t("occupation"), occupation)
    
    UIManager:show(InfoMessage:new{
        text = text,
        width = Screen:getWidth() * 0.9,
    })
end

function XRayPlugin:selectGeminiModel()
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local current_model = "gemini-3.1-flash-lite"
    if self.ai_helper.providers and self.ai_helper.providers.gemini then
        current_model = self.ai_helper.providers.gemini.model or "gemini-3.1-flash-lite"
    end

    local ButtonDialog = require("ui/widget/buttondialog")
    local buttons = {
        {
            {
                text = "Gemini 3.1 Flash-Lite" .. (current_model == "gemini-3.1-flash-lite" and " ✓" or ""),
                callback = function()
                    self.ai_helper:setGeminiModel("gemini-3.1-flash-lite")
                    UIManager:close(self.dlg)
                    UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                end
            }
        },
        {
            {
                text = "Gemini 3 Flash Preview" .. (current_model == "gemini-3-flash-preview" and " ✓" or ""),
                callback = function()
                    self.ai_helper:setGeminiModel("gemini-3-flash-preview")
                    UIManager:close(self.dlg)
                    UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                end
            }
        },
        {
            {
                text = "Gemini 3.1 Pro Preview" .. (current_model == "gemini-3.1-pro-preview" and " ✓" or ""),
                callback = function()
                    self.ai_helper:setGeminiModel("gemini-3.1-pro-preview")
                    UIManager:close(self.dlg)
                    UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                end
            }
        },
        {
            {
                text = "Gemini 2.5 Flash" .. (current_model == "gemini-2.5-flash" and " ✓" or ""),
                callback = function()
                    self.ai_helper:setGeminiModel("gemini-2.5-flash")
                    UIManager:close(self.dlg)
                    UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                end
            }
        },
        {
            {
                text = "Gemini 2.5 Pro" .. (current_model == "gemini-2.5-pro" and " ✓" or ""),
                callback = function()
                    self.ai_helper:setGeminiModel("gemini-2.5-pro")
                    UIManager:close(self.dlg)
                    UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                end
            }
        },
        {
            {
                text = self.loc:t("gemini_custom_model"),
                callback = function()
                    UIManager:close(self.dlg)
                    self:setCustomGeminiModel()
                end
            }
        },
    }
    self.dlg = ButtonDialog:new{
        title = self.loc:t("gemini_model_title"),
        buttons = buttons,
    }
    UIManager:show(self.dlg)
end

function XRayPlugin:setCustomGeminiModel()
    local InputDialog = require("ui/widget/inputdialog")
    local current_model = self.ai_helper.providers.gemini.model or ""
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("gemini_custom_model"),
        input = current_model,
        input_hint = "gemini-3.1-flash-lite",
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function() UIManager:close(input_dialog) end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local model = input_dialog:getInputText()
                        if model and #model > 0 then
                            self.ai_helper:setGeminiModel(model)
                            UIManager:show(InfoMessage:new{text = self.loc:t("gemini_model_saved"), timeout = 2})
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:fetchFromAI()
    logger.info("XRayPlugin: Fetching AI data")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    -- Do not block on KOReader's NetworkMgr:isOnline(): it can be stale on
    -- devices using local endpoints, proxies, or already-connected Wi-Fi.
    -- Provider calls still report real transport/API errors later.
    self:askSpoilerPreference()
end

function XRayPlugin:askSpoilerPreference()
    logger.info("XRayPlugin: Asking spoiler preference")

    local reading_percent = self:getSafeReadingPercent()

    local spoiler_menu
    spoiler_menu = Menu:new{
        title = self.loc:t("spoiler_preference_title"),
        item_table = {
            {
                text = string.format(self.loc:t("spoiler_free_option"), reading_percent),
                callback = function()
                    logger.info("XRayPlugin: User chose spoiler-free mode")
                    UIManager:close(spoiler_menu)
                    self:askAnalysisModePreference(reading_percent)
                end,
            },
            {
                text = self.loc:t("full_book_option"),
                callback = function()
                    logger.info("XRayPlugin: User chose full book mode")
                    UIManager:close(spoiler_menu)
                    self:askAnalysisModePreference(100)
                end,
            },
            {
                text = self.loc:t("cancel"),
                callback = function()
                    logger.info("XRayPlugin: User cancelled fetch")
                    UIManager:close(spoiler_menu)
                    UIManager:show(InfoMessage:new{
                        text = self.loc:t("fetch_cancelled"),
                        timeout = 3,
                    })
                end,
            },
        },
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }

    UIManager:show(spoiler_menu)
end

function XRayPlugin:askAnalysisModePreference(reading_percent)
    logger.info("XRayPlugin: Asking AI analysis mode")
    self:continueWithFetch(reading_percent or 100, "metadata")
end

function XRayPlugin:continueWithFetch(reading_percent, analysis_mode)
    logger.info("XRayPlugin: Continuing with fetch process (reading_percent:", reading_percent, ")")
    
    -- 1. Cache Manager Başlat (Kontrol için gerekli)
    if not self.cache_manager then
        local CacheManager = require("cachemanager")
        self.cache_manager = CacheManager:new()
    end
    
    -- 2. CACHE KONTROLÜ
    local book_path = self.ui.document.file
    local cache_path = self.cache_manager:getCachePath(book_path)
    local lfs = require("libs/libkoreader-lfs")
    
    local existing_data = nil
    if cache_path and lfs.attributes(cache_path) then
        existing_data = self.cache_manager:loadCache(book_path)
        if analysis_mode == "metadata" then
            UIManager:show(InfoMessage:new{
                text = self.loc:t("cache_verify"),
                timeout = 6,
            })
            return
        end
    end

    -- 3. AI Helper Başlat (Eğer cache yoksa devam et)
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    
    -- Seçili provider'ı al (varsayılan: gemini)
    local selected_provider, provider_config = self:getSelectedAIProvider()
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_api_key"),
            timeout = 4,
        })
        return
    end

    local title, author = self:getBookTitleAndAuthor()

    -- Model adını seçili provider'a göre al
    local current_model = self.loc:t("unknown_model")
    if provider_config and provider_config.model then
        current_model = provider_config.model
    end

    -- Provider adını al
    local provider_name = provider_config and provider_config.name or "AI"
    
    local job_manager = self:getJobManager()
    local ok, err = job_manager:start(self, {
        book_path = book_path,
        title = title,
        author = author,
        provider_id = selected_provider,
        provider_name = provider_name,
        model = current_model,
        kind = analysis_mode or "metadata",
        provider_type = provider_config.type,
        analysis_mode = analysis_mode or "metadata",
        reading_percent = reading_percent,
        existing_data = existing_data or self.book_data,
    })

    if not ok then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("background_job_failed") .. "\n\n" .. tostring(err or ""),
            timeout = 5,
        })
    end
end

function XRayPlugin:getSelectedAIProvider()
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    local selected_provider = self.ai_provider or self.ai_helper.default_provider or "gemini"
    local provider_config = self.ai_helper.providers[selected_provider]
    return selected_provider, provider_config
end

function XRayPlugin:getBookTitleAndAuthor()
    local props = {}
    if self.ui and self.ui.document and type(self.ui.document.getProps) == "function" then
        local ok, result = pcall(function() return self.ui.document:getProps() end)
        if ok and type(result) == "table" then
            props = result
        end
    end
    local title = props.title or self.book_title or "Unknown"
    local author = props.authors or props.author or self.author or ""
    if type(author) == "table" then
        author = table.concat(author, ", ")
    elseif type(author) ~= "string" then
        author = tostring(author or "")
    end
    return title, author
end

function XRayPlugin:enrichFromNearbyContext()
    logger.info("XRayPlugin: Enriching X-Ray from nearby context")
    if not self.cache_manager then
        local CacheManager = require("cachemanager")
        self.cache_manager = CacheManager:new()
    end
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local selected_provider, provider_config = self:getSelectedAIProvider()
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        UIManager:show(InfoMessage:new{text = self.loc:t("no_api_key"), timeout = 4})
        return
    end

    local book_path = self.ui and self.ui.document and self.ui.document.file
    if not book_path then return end
    local existing_data = self.book_data or self.cache_manager:loadCache(book_path)
    local title, author = self:getBookTitleAndAuthor()
    local context_limit = tonumber(self.ai_helper.settings and self.ai_helper.settings.context_char_limit) or 500

    local ok, err = self:getJobManager():start(self, {
        book_path = book_path,
        title = title,
        author = author,
        provider_id = selected_provider,
        provider_name = provider_config.name or "AI",
        model = provider_config.model or "",
        kind = "nearby_context",
        provider_type = provider_config.type,
        analysis_mode = "nearby_context",
        reading_percent = 100,
        existing_data = existing_data,
        context_char_limit = context_limit,
    })

    if not ok then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("background_job_failed") .. "\n\n" .. tostring(err or ""),
            timeout = 5,
        })
    end
end

function XRayPlugin:showAdvancedAnalysisMenu()
    local reading_percent = self:getSafeReadingPercent()

    local advanced_menu
    advanced_menu = Menu:new{
        title = self.loc:t("menu_advanced_scan"),
        item_table = {
            {
                text = string.format(self.loc:t("analysis_mode_local_candidates"), reading_percent),
                callback = function()
                    UIManager:close(advanced_menu)
                    self:continueWithFetch(reading_percent, "local_candidates")
                end,
            },
            {
                text = self.loc:t("analysis_mode_chunked"),
                callback = function()
                    UIManager:close(advanced_menu)
                    self:continueWithFetch(reading_percent, "chunked_fulltext")
                end,
            },
            {
                text = self.loc:t("cancel"),
                callback = function()
                    UIManager:close(advanced_menu)
                end,
            },
        },
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    UIManager:show(advanced_menu)
end

function XRayPlugin:restartBackgroundJob(mode_override)
    local job_manager = self:getJobManager()
    local book_path = self.ui and self.ui.document and self.ui.document.file
    if not book_path then return false, "no_book" end
    local state = job_manager:loadState(book_path)
    if not state then return false, "no_job" end
    if job_manager:isRunning() then return false, "job_running" end
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    local provider_id = state.provider_id or self.ai_helper.default_provider or "gemini"
    local provider_config = self.ai_helper.providers[provider_id]
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        return false, "no_api_key"
    end
    local fallback_title, fallback_author = self:getBookTitleAndAuthor()
    local title = (type(state.title) == "string" and #state.title > 0) and state.title or fallback_title
    local author = (type(state.author) == "string" and #state.author > 0) and state.author or fallback_author
    return job_manager:start(self, {
        book_path = book_path,
        title = title,
        author = author,
        provider_id = provider_id,
        provider_name = state.provider_name or provider_config.name or "AI",
        model = state.model or provider_config.model or "",
        kind = mode_override or state.kind or state.analysis_mode,
        provider_type = provider_config.type,
        analysis_mode = mode_override or state.analysis_mode or "metadata",
        reading_percent = state.reading_percent or 100,
        existing_data = state.existing_data or self.book_data,
        context_char_limit = state.context_char_limit,
        silent = false,
    })
end

function XRayPlugin:showBackgroundJobStatus()
    local ButtonDialog = require("ui/widget/buttondialog")
    local TextViewer = require("ui/widget/textviewer")
    local job_manager = self:getJobManager()
    local book_path = self.ui and self.ui.document and self.ui.document.file
    if book_path then
        job_manager:loadState(book_path)
    end

    local buttons = {}
    local state = job_manager.state or {}
    local status = state.status or "idle"
    local has_job = book_path and state.book_path ~= nil
    local active = job_manager:isRunning()
    local resumable = has_job and job_manager:isStateResumable()

    local function addButton(text, callback)
        table.insert(buttons, {{ text = text, callback = callback }})
    end

    if resumable and not active then
        addButton(self.loc:t("background_job_retry"), function()
            UIManager:close(self.job_status_dialog)
            local ok, err = self:restartBackgroundJob()
            UIManager:show(InfoMessage:new{
                text = ok and self.loc:t("background_job_started") or (self.loc:t("background_job_failed") .. "\n\n" .. tostring(err or "")),
                timeout = 4,
            })
        end)
        addButton(self.loc:t("background_job_fallback_metadata"), function()
            UIManager:close(self.job_status_dialog)
            local ok, err = self:restartBackgroundJob("metadata")
            UIManager:show(InfoMessage:new{
                text = ok and self.loc:t("background_job_started") or (self.loc:t("background_job_failed") .. "\n\n" .. tostring(err or "")),
                timeout = 4,
            })
        end)
    end

    if resumable and not active and status ~= "failed" then
        addButton(self.loc:t("background_job_resume"), function()
            UIManager:close(self.job_status_dialog)
            if not book_path or not job_manager:loadState(book_path) then
                UIManager:show(InfoMessage:new{text = self.loc:t("background_job_none"), timeout = 3})
                return
            end
            local ok, err = job_manager:resume(self)
            UIManager:show(InfoMessage:new{
                text = ok and self.loc:t("background_job_started") or (self.loc:t("background_job_failed") .. "\n\n" .. tostring(err or "")),
                timeout = 4,
            })
        end)
    end

    if state.last_prompt_preview and #state.last_prompt_preview > 0 then
        addButton(self.loc:t("background_job_view_prompt"), function()
            local prompt, label = job_manager:getPromptPreview()
            if not prompt then
                UIManager:show(InfoMessage:new{text = self.loc:t("background_job_prompt_not_ready"), timeout = 3})
                return
            end
            UIManager:show(TextViewer:new{
                title = label or self.loc:t("background_job_view_prompt"),
                text = prompt,
                justified = false,
            })
        end)
    end

    addButton(self.loc:t("text_extraction_diagnostics"), function()
        local TextAnalyzer = require("textanalyzer")
        local analyzer = TextAnalyzer:new()
        UIManager:show(TextViewer:new{
            title = self.loc:t("text_extraction_diagnostics"),
            text = analyzer:diagnose(self.ui),
            justified = false,
        })
    end)

    if active then
        addButton(self.loc:t("background_job_cancel"), function()
            job_manager:cancel()
            if book_path then job_manager:saveState(book_path) end
            UIManager:close(self.job_status_dialog)
            UIManager:show(InfoMessage:new{text = self.loc:t("background_job_cancel_requested"), timeout = 3})
        end)
    end

    self.job_status_dialog = ButtonDialog:new{
        title = self.loc:t("menu_background_job") .. "\n\n" .. job_manager:getStatusText(),
        buttons = buttons,
    }
    UIManager:show(self.job_status_dialog)
end

function XRayPlugin:showLocations(page)
    if not self.locations or #self.locations == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_location_data"),
            timeout = 3,
        })
        return
    end

    local page_size = 60
    page = page or 1
    local current_page, total_pages, start_index, end_index = self:getMenuPageBounds(#self.locations, page, page_size)
    local items = {}
    for i = start_index, end_index do
        local loc = self.locations[i]
        local text = loc.name or "Unknown Location"

        if loc.description then
            text = text .. "\n   " .. self:clampText(loc.description, 120)
        end
        if loc.importance then
            text = text .. "\n   🎯 " .. self:clampText(loc.importance, 90)
        end
        
        table.insert(items, {
            text = text,
            callback = function()
                local detail_text = "📍 " .. (loc.name or "Unknown") .. "\n\n"
                if loc.description then
                    detail_text = detail_text .. loc.description .. "\n\n"
                end
                if loc.importance then
                    detail_text = detail_text .. "🎯 " .. self.loc:t("importance") .. "\n" .. loc.importance
                end
                UIManager:show(InfoMessage:new{
                    text = detail_text,
                    timeout = 10,
                })
            end,
        })
    end

    self:addPagingItems(items, #self.locations, current_page, total_pages, function(next_page)
        self:showLocations(next_page)
    end)

    local location_menu = Menu:new{
        title = self:getPagedMenuTitle(self.loc:t("menu_locations"), #self.locations, current_page, total_pages),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(location_menu)
end

function XRayPlugin:showAuthorInfo()
    if not self.author_info or not self.author_info.description or #self.author_info.description == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_author_data"),
            timeout = 3,
        })
        return
    end
    
    local text = "✍️ " .. (self.author_info.name or self.loc:t("menu_author_info")) .. "\n\n"
    text = text .. self.author_info.description .. "\n\n"
    
    if self.author_info.birthDate and #self.author_info.birthDate > 0 then
        text = text .. "📅: " .. self.author_info.birthDate .. "\n"
    end
    if self.author_info.deathDate and #self.author_info.deathDate > 0 then
        text = text .. "💀: " .. self.author_info.deathDate .. "\n"
    end
    
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = 15,
    })
end

function XRayPlugin:showAbout()
    local TextViewer = require("ui/widget/textviewer")
    
    local about_viewer = TextViewer:new{
        title = self.loc:t("about_title"),
        text = self.loc:t("about_text"),
        justified = false,
    }
    
    UIManager:show(about_viewer)
end

function XRayPlugin:clearCache()
    if not self.cache_manager then
        local CacheManager = require("cachemanager")
        self.cache_manager = CacheManager:new()
    end
    
    local ConfirmBox = require("ui/widget/confirmbox")
    UIManager:show(ConfirmBox:new{
        text = self.loc:t("cache_clear_confirm"),
        ok_text = self.loc:t("yes_clear"),
        cancel_text = self.loc:t("cancel"),
        ok_callback = function()
            local book_path = self.ui.document.file
            local success = self.cache_manager:clearCache(book_path)
            
            if success then
                self.book_data = nil
                self.characters = {}
                self.locations = {}
                self.themes = {}
                self.summary = nil
                self.author_info = nil
                self.timeline = {}
                self.historical_figures = {}
                
                UIManager:show(InfoMessage:new{
                    text = self.loc:t("cache_cleared"),
                    timeout = 5,
                })
            else
                UIManager:show(InfoMessage:new{
                    text = self.loc:t("cache_not_found"),
                    timeout = 3,
                })
            end
        end,
    })
end

function XRayPlugin:toggleXRayMode()
    if not self.characters or #self.characters == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("xray_mode_no_data"),
            timeout = 5,
        })
        return
    end
    
    self.xray_mode_enabled = not self.xray_mode_enabled
    
    if self.xray_mode_enabled then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("xray_mode_enabled"),
            timeout = 7,
        })
    else
        UIManager:show(InfoMessage:new{
            text = self.loc:t("xray_mode_disabled"),
            timeout = 3,
        })
    end
    
    logger.info("XRayPlugin: X-Ray mode:", self.xray_mode_enabled and "enabled" or "disabled")
end

function XRayPlugin:findCharacterByName(word)
    if not self.characters or not word then
        return nil
    end
    
    local word_lower = string.lower(word)
    
    for _, char in ipairs(self.characters) do
        local name_lower = string.lower(char.name or "")
        
        if name_lower == word_lower then
            return char
        end
        
        if string.find(name_lower, word_lower, 1, true) or
           string.find(word_lower, name_lower, 1, true) then
            return char
        end
        
        local first_name = string.match(name_lower, "^(%S+)")
        if first_name and first_name == word_lower then
            return char
        end
    end
    
    return nil
end

function XRayPlugin:showCharacterInfo(char)
    local text = "👤 " .. (char.name or "Unknown") .. "\n\n"
    
    if char.description then
        text = text .. char.description .. "\n\n"
    end
    
    if char.role then
        text = text .. "🎭 " .. self.loc:t("role") .. ": " .. char.role .. "\n"
    end
    
    if char.gender then
        local gender_tr = char.gender == "male" and self.loc:t("gender_male") or 
                         char.gender == "female" and self.loc:t("gender_female") or 
                         char.gender == "erkek" and self.loc:t("gender_male") or
                         char.gender == "kadın" and self.loc:t("gender_female") or
                         char.gender
        text = text .. "👤 " .. self.loc:t("gender") .. ": " .. gender_tr .. "\n"
    end
    
    if char.occupation then
        text = text .. "💼 " .. self.loc:t("occupation") .. ": " .. char.occupation .. "\n"
    end
    
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = 10,
    })
end

function XRayPlugin:registerAIQuestionHighlightAction()
    if self._xray_ai_qa_highlight_registered then
        return
    end

    if not self.ui or not self.ui.highlight or type(self.ui.highlight.addToHighlightDialog) ~= "function" then
        logger.warn("XRayPlugin: Highlight dialog is not available for AI Q&A")
        if not self._xray_ai_qa_highlight_retry_scheduled then
            self._xray_ai_qa_highlight_retry_scheduled = true
            UIManager:scheduleIn(1.0, function()
                self._xray_ai_qa_highlight_retry_scheduled = nil
                self:registerAIQuestionHighlightAction()
            end)
        end
        return
    end

    local plugin = self
    self.ui.highlight:addToHighlightDialog("08_xray_ai_qa", function(highlight)
        return {
            text = plugin.loc:t("menu_ai_qa"),
            enabled = highlight.selected_text and highlight.selected_text.text and #highlight.selected_text.text > 0,
            callback = function()
                local util = require("util")
                local selected_text = ""
                if highlight.selected_text and highlight.selected_text.text then
                    selected_text = util.cleanupSelectedText(highlight.selected_text.text)
                end
                highlight:onClose(true)
                UIManager:scheduleIn(0.1, function()
                    plugin:showAIQuestionDialog(selected_text)
                end)
            end,
        }
    end)

    self._xray_ai_qa_highlight_registered = true
    logger.info("XRayPlugin: AI Q&A highlight action registered")
end

function XRayPlugin:getAIQuestionContext(selected_text)
    local props = self.ui and self.ui.document and self.ui.document.getProps and self.ui.document:getProps() or {}
    local title = props.title or self.book_title or "Unknown"
    local author = props.authors or props.author or self.author or ""

    if type(author) == "table" then
        author = table.concat(author, ", ")
    elseif type(author) ~= "string" then
        author = tostring(author or "")
    end

    return {
        title = title,
        author = author,
        summary = self.summary or "",
        selected_text = selected_text or "",
        language = self.loc and self.loc.getLanguage and self.loc:getLanguage() or "en",
    }
end

function XRayPlugin:showAIQuestionDialog(selected_text)
    local InputDialog = require("ui/widget/inputdialog")

    selected_text = selected_text or ""
    local selected_preview = selected_text
    if #selected_preview > 300 then
        selected_preview = selected_preview:sub(1, 300) .. "..."
    end

    local description = nil
    if #selected_preview > 0 then
        description = string.format(self.loc:t("ai_qa_selected_text_desc"), selected_preview)
    end

    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("ai_qa_title"),
        input = "",
        input_hint = self.loc:t("ai_qa_hint"),
        description = description,
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("menu_ai_qa"),
                    is_enter_default = true,
                    callback = function()
                        local question = input_dialog:getInputText() or ""
                        UIManager:close(input_dialog)
                        self:askAIQuestion(question, selected_text)
                    end,
                },
            },
        },
    }

    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:askAIQuestion(question, selected_text, is_followup)
    question = question or ""
    question = question:match("^%s*(.-)%s*$") or ""
    selected_text = selected_text or ""

    if #question == 0 and #selected_text == 0 and not is_followup then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_question"),
            timeout = 3,
        })
        return
    end

    if #question == 0 and is_followup then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_question"),
            timeout = 3,
        })
        return
    elseif #question == 0 then
        question = self.loc:t("ai_qa_default_selected_question")
    end

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local selected_provider = self.ai_provider or self.ai_helper.default_provider or "gemini"
    local provider_config = self.ai_helper.providers[selected_provider]
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_api_key"),
            timeout = 5,
        })
        return
    end

    local book_path = self:getCurrentBookPath()
    if self:getActiveAIJob("qa", book_path) then
        self:showAIJobRunning("qa")
        return
    end

    if not is_followup or not self.ai_qa_session then
        self.ai_qa_session = {
            book_path = book_path,
            selected_text = selected_text,
            context = self:getAIQuestionContext(selected_text),
            history = {},
        }
    else
        self.ai_qa_session.book_path = book_path
        self.ai_qa_session.selected_text = self.ai_qa_session.selected_text or selected_text
        self.ai_qa_session.context = self.ai_qa_session.context or self:getAIQuestionContext(selected_text)
        self.ai_qa_session.history = self.ai_qa_session.history or {}
    end

    local provider_name = provider_config.name or "AI"
    local model = provider_config.model or self.loc:t("unknown_model")
    local context = self:getAIQuestionContext(self.ai_qa_session.selected_text or selected_text)
    context.history = self.ai_qa_session.history
    context.selected_text = self.ai_qa_session.selected_text or selected_text

    local request = {
        book_path = book_path,
        question = question,
        selected_provider = selected_provider,
        provider_name = provider_name,
        model = model,
        context = context,
    }

    local started, err = self:startSimpleAIJob(
        "qa",
        book_path,
        provider_name .. " / " .. model,
        string.format(self.loc:t("ai_job_started"), provider_name, model),
        function()
            local AIHelper = require("aihelper")
            AIHelper:init()
            local answer, error_code, error_msg = AIHelper:askQuestion(
                request.question,
                request.selected_provider,
                request.context
            )
            if not answer then
                return {
                    ok = false,
                    error_code = error_code,
                    error_msg = error_msg,
                }
            end
            return {
                ok = true,
                answer = answer,
            }
        end,
        function(result)
            self:onAIQuestionJobComplete(result, request)
        end
    )

    if not started then
        if err == "already_running" then
            self:showAIJobRunning("qa")
        else
            UIManager:show(InfoMessage:new{
                text = self.loc:t("ai_job_start_failed"),
                timeout = 4,
            })
        end
    end
end

function XRayPlugin:onAIQuestionJobComplete(result, request)
    if not self:isCurrentBook(request.book_path) then
        logger.warn("XRayPlugin: Ignoring Q&A result for inactive book")
        return
    end

    if not result or not result.ok or not result.answer then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_failed") .. "\n\n" ..
                self:formatAIError("ai_qa_failed", result and result.error_code, result and result.error_msg),
            timeout = 7,
        })
        return
    end

    self.ai_qa_session = self.ai_qa_session or {
        book_path = request.book_path,
        context = request.context,
        selected_text = request.context and request.context.selected_text or "",
        history = {},
    }
    self.ai_qa_session.history = self.ai_qa_session.history or {}
    table.insert(self.ai_qa_session.history, {
        question = request.question,
        answer = result.answer,
        created_at = os.time(),
    })
    while #self.ai_qa_session.history > 6 do
        table.remove(self.ai_qa_session.history, 1)
    end
    self.ai_qa_session.last_question = request.question
    self.ai_qa_session.last_answer = result.answer
    self.ai_qa_session.provider = request.selected_provider

    UIManager:show(InfoMessage:new{
        text = self.loc:t("ai_job_result_ready"),
        timeout = 3,
    })
    self:showAIQuestionActions()
end

function XRayPlugin:showAIQuestionActions()
    if not self.ai_qa_session or not self.ai_qa_session.last_answer then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_answer"),
            timeout = 3,
        })
        return
    end

    local ButtonDialog = require("ui/widget/buttondialog")
    local preview = self.ai_qa_session.last_answer
    if #preview > 500 then
        preview = preview:sub(1, 500) .. "..."
    end

    local action_dialog
    action_dialog = ButtonDialog:new{
        title = self.loc:t("ai_qa_actions_title") .. "\n\n" .. preview,
        buttons = {
            {
                {
                    text = self.loc:t("ai_qa_view_answer"),
                    callback = function()
                        UIManager:close(action_dialog)
                        self:showAIAnswer()
                    end,
                },
            },
            {
                {
                    text = self.loc:t("ai_qa_follow_up"),
                    callback = function()
                        UIManager:close(action_dialog)
                        self:showAIQuestionFollowupDialog()
                    end,
                },
            },
            {
                {
                    text = self.loc:t("ai_qa_add_character"),
                    callback = function()
                        UIManager:close(action_dialog)
                        self:startCharacterExtractionFromQA()
                    end,
                },
            },
            {
                {
                    text = self.loc:t("close"),
                    callback = function()
                        UIManager:close(action_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(action_dialog)
end

function XRayPlugin:showAIAnswer()
    if not self.ai_qa_session or not self.ai_qa_session.last_answer then
        return
    end
    local TextViewer = require("ui/widget/textviewer")
    UIManager:show(TextViewer:new{
        title = self.loc:t("ai_qa_answer_title"),
        text = self.ai_qa_session.last_answer,
        justified = false,
    })
end

function XRayPlugin:showAIQuestionFollowupDialog()
    if not self.ai_qa_session then return end
    local InputDialog = require("ui/widget/inputdialog")
    local description = self.ai_qa_session.last_answer or ""
    if #description > 500 then
        description = description:sub(1, 500) .. "..."
    end

    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("ai_qa_follow_up"),
        input = "",
        input_hint = self.loc:t("ai_qa_follow_up_hint"),
        description = description,
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("ai_qa_follow_up"),
                    is_enter_default = true,
                    callback = function()
                        local followup = input_dialog:getInputText() or ""
                        UIManager:close(input_dialog)
                        self:askAIQuestion(followup, self.ai_qa_session.selected_text or "", true)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:startCharacterExtractionFromQA()
    if not self.ai_qa_session or not self.ai_qa_session.last_answer then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_answer"),
            timeout = 3,
        })
        return
    end

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local book_path = self:getCurrentBookPath()
    if self:getActiveAIJob("character_extract", book_path) then
        self:showAIJobRunning("character_extract")
        return
    end

    local selected_provider = self.ai_provider or self.ai_helper.default_provider or self.ai_qa_session.provider or "gemini"
    local provider_config = self.ai_helper.providers[selected_provider]
    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_qa_no_api_key"),
            timeout = 5,
        })
        return
    end

    local request = {
        book_path = book_path,
        selected_provider = selected_provider,
        question = self.ai_qa_session.last_question or "",
        answer = self.ai_qa_session.last_answer or "",
        selected_text = self.ai_qa_session.selected_text or "",
        existing_characters = self:getCompactCharactersForAI(),
        provider_name = provider_config.name or "AI",
        model = provider_config.model or self.loc:t("unknown_model"),
    }

    local started, err = self:startSimpleAIJob(
        "character_extract",
        book_path,
        request.provider_name .. " / " .. request.model,
        string.format(self.loc:t("ai_job_started"), request.provider_name, request.model),
        function()
            local AIHelper = require("aihelper")
            AIHelper:init()
            local candidate, error_code, error_msg = AIHelper:extractCharacterJSON(
                request.selected_provider,
                {
                    question = request.question,
                    answer = request.answer,
                    selected_text = request.selected_text,
                    existing_characters = request.existing_characters,
                }
            )
            if not candidate then
                return {
                    ok = false,
                    error_code = error_code,
                    error_msg = error_msg,
                }
            end
            return {
                ok = true,
                candidate = candidate,
            }
        end,
        function(result)
            self:onCharacterExtractComplete(result, request)
        end
    )

    if not started then
        if err == "already_running" then
            self:showAIJobRunning("character_extract")
        else
            UIManager:show(InfoMessage:new{
                text = self.loc:t("ai_job_start_failed"),
                timeout = 4,
            })
        end
    end
end

function XRayPlugin:onCharacterExtractComplete(result, request)
    if not self:isCurrentBook(request.book_path) then
        logger.warn("XRayPlugin: Ignoring character extraction result for inactive book")
        return
    end

    if not result or not result.ok or not result.candidate then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("ai_character_extract_failed") .. "\n\n" ..
                self:formatAIError("ai_character_extract_failed", result and result.error_code, result and result.error_msg),
            timeout = 7,
        })
        return
    end

    self:confirmApplyCharacter(result.candidate)
end

function XRayPlugin:normalizeCharacterName(name)
    if type(name) ~= "string" then return "" end
    return name:lower():gsub("%s+", ""):gsub("[\"'`“”‘’]", "")
end

function XRayPlugin:findCharacterConflict(candidate)
    local target = self:normalizeCharacterName(candidate.merge_target or "")
    local names = {}
    names[self:normalizeCharacterName(candidate.name)] = true
    if type(candidate.aliases) == "table" then
        for _, alias in ipairs(candidate.aliases) do
            names[self:normalizeCharacterName(alias)] = true
        end
    end

    for index, char in ipairs(self.characters or {}) do
        local existing_name = self:normalizeCharacterName(char.name or "")
        if existing_name ~= "" and (names[existing_name] or (target ~= "" and existing_name == target)) then
            return char, index
        end
        if type(char.aliases) == "table" then
            for _, alias in ipairs(char.aliases) do
                local existing_alias = self:normalizeCharacterName(alias)
                if existing_alias ~= "" and names[existing_alias] then
                    return char, index
                end
            end
        end
    end

    return nil, nil
end

function XRayPlugin:formatCharacterCandidate(candidate, existing)
    local aliases = ""
    if type(candidate.aliases) == "table" and #candidate.aliases > 0 then
        aliases = table.concat(candidate.aliases, ", ")
    end
    local text = string.format(
        "%s: %s\n%s: %s\n%s: %s\n%s: %s\n%s: %s\n%s: %.2f",
        self.loc:t("character_name"), candidate.name or "",
        self.loc:t("aliases"), aliases,
        self.loc:t("role"), candidate.role or "",
        self.loc:t("description"), candidate.description or "",
        self.loc:t("evidence"), candidate.evidence or "",
        self.loc:t("confidence"), tonumber(candidate.confidence) or 0
    )
    if existing then
        text = text .. "\n\n" .. string.format(self.loc:t("ai_character_conflict_with"), existing.name or "")
    end
    return text
end

function XRayPlugin:confirmApplyCharacter(candidate)
    self.characters = self.characters or {}
    local existing, existing_index = self:findCharacterConflict(candidate)
    local ButtonDialog = require("ui/widget/buttondialog")
    local dialog

    local function apply(mode)
        UIManager:close(dialog)
        self:applyCharacterCandidate(candidate, existing_index, mode)
    end

    local buttons
    if existing then
        buttons = {
            {{ text = self.loc:t("ai_character_merge_empty"), callback = function() apply("merge_empty") end }},
            {{ text = self.loc:t("ai_character_overwrite_fields"), callback = function() apply("overwrite") end }},
            {{ text = self.loc:t("ai_character_add_new"), callback = function() apply("add") end }},
            {{ text = self.loc:t("cancel"), callback = function() UIManager:close(dialog) end }},
        }
    else
        buttons = {
            {{ text = self.loc:t("ai_character_add_new"), callback = function() apply("add") end }},
            {{ text = self.loc:t("cancel"), callback = function() UIManager:close(dialog) end }},
        }
    end

    dialog = ButtonDialog:new{
        title = self.loc:t("ai_character_confirm_title") .. "\n\n" .. self:formatCharacterCandidate(candidate, existing),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function XRayPlugin:mergeAliases(target, aliases)
    if type(aliases) ~= "table" or #aliases == 0 then return end
    target.aliases = target.aliases or {}
    local seen = {}
    for _, alias in ipairs(target.aliases) do
        seen[self:normalizeCharacterName(alias)] = true
    end
    for _, alias in ipairs(aliases) do
        local key = self:normalizeCharacterName(alias)
        if key ~= "" and not seen[key] then
            table.insert(target.aliases, alias)
            seen[key] = true
        end
    end
end

function XRayPlugin:applyCharacterCandidate(candidate, existing_index, mode)
    self.characters = self.characters or {}
    local fields = { "role", "description", "gender", "occupation", "evidence", "confidence" }
    local target

    if mode == "add" or not existing_index then
        target = {
            name = candidate.name,
            aliases = candidate.aliases or {},
            role = candidate.role or "",
            description = candidate.description or "",
            gender = candidate.gender or "",
            occupation = candidate.occupation or "",
            evidence = candidate.evidence or "",
            confidence = candidate.confidence or 0,
        }
        table.insert(self.characters, target)
    else
        target = self.characters[existing_index]
        for _, field in ipairs(fields) do
            local value = candidate[field]
            if value ~= nil and tostring(value) ~= "" then
                if mode == "overwrite" or target[field] == nil or tostring(target[field]) == "" then
                    target[field] = value
                end
            end
        end
        self:mergeAliases(target, candidate.aliases)
    end

    self.book_data = self.book_data or {}
    self.book_data.characters = self.characters
    local saved = self:saveCurrentXRayCache()
    UIManager:show(InfoMessage:new{
        text = (saved and self.loc:t("ai_character_saved") or self.loc:t("cache_save_failed")) .. "\n\n" .. (target.name or ""),
        timeout = 4,
    })
end

function XRayPlugin:setGeminiAPIKey()
    local InputDialog = require("ui/widget/inputdialog")
    
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    
    local current_key = self.ai_helper.providers.gemini.api_key or ""
    
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("gemini_key_title"), 
        input = current_key,
        input_hint = self.loc:t("gemini_key_hint"), 
        description = self.loc:t("gemini_key_desc"), 
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local api_key = input_dialog:getInputText()
                        if api_key and #api_key > 0 then
                            if not self.ai_helper then
                                local AIHelper = require("aihelper")
                                self.ai_helper = AIHelper
                            end
                            
                            self.ai_helper:setAPIKey("gemini", api_key)
                            self.ai_provider = "gemini"
                            
                            UIManager:show(InfoMessage:new{
                                text = self.loc:t("gemini_key_saved"), 
                                timeout = 3,
                            })                            
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            }
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:setChatGPTAPIKey()
    local InputDialog = require("ui/widget/inputdialog")
    
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    
    local current_key = self.ai_helper.providers.chatgpt.api_key or ""
    
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("chatgpt_key_title"), 
        input = current_key,
        input_hint = self.loc:t("chatgpt_key_hint"), 
        description = self.loc:t("chatgpt_key_desc"), 
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local api_key = input_dialog:getInputText()
                        if api_key and #api_key > 0 then
                            if not self.ai_helper then
                                local AIHelper = require("aihelper")
                                self.ai_helper = AIHelper
                            end
                            self.ai_helper:setAPIKey("chatgpt", api_key)
                            self.ai_provider = "chatgpt"
                            
                            UIManager:show(InfoMessage:new{
                                text = self.loc:t("chatgpt_key_saved"), 
                                timeout = 3,
                            })
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            }
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:setOpenAICompatibleAPIKey()
    local InputDialog = require("ui/widget/inputdialog")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider = "openai_compatible"
    local current_key = self.ai_helper.providers[provider].api_key or ""

    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("openai_compatible_key_title"),
        input = current_key,
        input_hint = self.loc:t("openai_compatible_key_hint"),
        description = self.loc:t("openai_compatible_key_desc"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local api_key = input_dialog:getInputText()
                        if api_key and #api_key > 0 then
                            self.ai_helper:setAPIKey(provider, api_key)
                            self.ai_provider = provider
                            UIManager:show(InfoMessage:new{
                                text = self.loc:t("openai_compatible_key_saved"),
                                timeout = 3,
                            })
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            }
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:setProviderModelDialog(provider, loc_prefix)
    local InputDialog = require("ui/widget/inputdialog")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider_config = self.ai_helper.providers[provider]
    if not provider_config then
        return
    end

    local current_model = provider_config.model or "gpt-4o-mini"
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t(loc_prefix .. "_title"),
        input = current_model,
        input_hint = self.loc:t(loc_prefix .. "_hint"),
        description = self.loc:t(loc_prefix .. "_desc"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local model = input_dialog:getInputText()
                        if model and #model > 0 then
                            local success = self.ai_helper:setProviderModel(provider, model)
                            if success then
                                self.ai_provider = provider
                                UIManager:show(InfoMessage:new{
                                    text = self.loc:t(loc_prefix .. "_saved"),
                                    timeout = 3,
                                })
                            end
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            }
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:setOpenAICompatibleModel()
    self:setProviderModelDialog("openai_compatible", "openai_model")
end

function XRayPlugin:selectOpenAIThinkingMode()
    local ButtonDialog = require("ui/widget/buttondialog")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider = "openai_compatible"
    local current = self.ai_helper:getThinkingMode(self.ai_helper.providers[provider])
    local thinking_dialog
    local function saveThinking(mode)
        local success = self.ai_helper:setProviderThinking(provider, mode)
        if success then
            self.ai_provider = provider
            local message = self.loc:t("openai_thinking_omitted")
            if mode == "enabled" then
                message = self.loc:t("openai_thinking_enabled")
            elseif mode == "disabled" then
                message = self.loc:t("openai_thinking_disabled")
            end
            UIManager:show(InfoMessage:new{
                text = message,
                timeout = 3,
            })
        end
        UIManager:close(thinking_dialog)
    end

    thinking_dialog = ButtonDialog:new{
        title = self.loc:t("openai_thinking_title"),
        buttons = {
            {
                {
                    text = self.loc:t("openai_thinking_omit") .. (current == "omit" and " ✓" or ""),
                    callback = function() saveThinking("omit") end,
                },
            },
            {
                {
                    text = self.loc:t("openai_thinking_on") .. (current == "enabled" and " ✓" or ""),
                    callback = function() saveThinking("enabled") end,
                },
            },
            {
                {
                    text = self.loc:t("openai_thinking_off") .. (current == "disabled" and " ✓" or ""),
                    callback = function() saveThinking("disabled") end,
                },
            },
        },
    }
    UIManager:show(thinking_dialog)
end

function XRayPlugin:selectOpenAIReasoningEffort()
    local ButtonDialog = require("ui/widget/buttondialog")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider = "openai_compatible"
    local current = self.ai_helper.providers[provider].reasoning_effort or "high"
    local effort_dialog
    local function saveEffort(effort)
        local success = self.ai_helper:setProviderReasoningEffort(provider, effort)
        if success then
            self.ai_provider = provider
            UIManager:show(InfoMessage:new{
                text = string.format(self.loc:t("openai_effort_saved"), effort),
                timeout = 3,
            })
        end
        UIManager:close(effort_dialog)
    end

    effort_dialog = ButtonDialog:new{
        title = self.loc:t("openai_effort_title"),
        buttons = {
            {
                {
                    text = "high" .. (current == "high" and " ✓" or ""),
                    callback = function() saveEffort("high") end,
                },
            },
            {
                {
                    text = "max" .. (current == "max" and " ✓" or ""),
                    callback = function() saveEffort("max") end,
                },
            },
        },
    }
    UIManager:show(effort_dialog)
end

function XRayPlugin:toggleAutoMetadataOnOpen()
    local ButtonDialog = require("ui/widget/buttondialog")
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local settings = self.ai_helper.settings or {}
    local enabled = settings.auto_metadata_on_open ~= false
    local silent = settings.auto_metadata_silent ~= false
    local dialog
    local function save(auto_enabled, silent_enabled)
        self.ai_helper.settings = self.ai_helper.settings or {}
        self.ai_helper.settings.auto_metadata_on_open = auto_enabled
        self.ai_helper.settings.auto_metadata_silent = silent_enabled
        self.ai_helper:saveRuntimeSetting("auto_metadata_on_open", auto_enabled and "enabled" or "disabled")
        self.ai_helper:saveRuntimeSetting("auto_metadata_silent", silent_enabled and "enabled" or "disabled")
        UIManager:close(dialog)
        UIManager:show(InfoMessage:new{text = self.loc:t("auto_metadata_saved"), timeout = 3})
    end

    dialog = ButtonDialog:new{
        title = self.loc:t("menu_auto_metadata"),
        buttons = {
            {
                {
                    text = self.loc:t("auto_metadata_silent") .. (enabled and silent and " ✓" or ""),
                    callback = function() save(true, true) end,
                },
            },
            {
                {
                    text = self.loc:t("auto_metadata_visible") .. (enabled and not silent and " ✓" or ""),
                    callback = function() save(true, false) end,
                },
            },
            {
                {
                    text = self.loc:t("auto_metadata_disabled") .. (not enabled and " ✓" or ""),
                    callback = function() save(false, silent) end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function XRayPlugin:setContextCharLimit()
    local InputDialog = require("ui/widget/inputdialog")
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local current = tonumber(self.ai_helper.settings and self.ai_helper.settings.context_char_limit) or 500
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("menu_context_char_limit"),
        input = tostring(current),
        input_hint = "500",
        description = self.loc:t("context_char_limit_desc"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function() UIManager:close(input_dialog) end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local value = tonumber(input_dialog:getInputText())
                        if value then
                            value = math.max(100, math.min(5000, math.floor(value)))
                            self.ai_helper.settings = self.ai_helper.settings or {}
                            self.ai_helper.settings.context_char_limit = value
                            self.ai_helper:saveRuntimeSetting("context_char_limit", value)
                            UIManager:show(InfoMessage:new{text = string.format(self.loc:t("context_char_limit_saved"), value), timeout = 3})
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:setOpenAICompatibleEndpoint()
    local InputDialog = require("ui/widget/inputdialog")

    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider = "openai_compatible"
    local current_endpoint = self.ai_helper.providers[provider].endpoint or "https://api.openai.com/v1/chat/completions"

    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("openai_endpoint_title"),
        input = current_endpoint,
        input_hint = self.loc:t("openai_endpoint_hint"),
        description = self.loc:t("openai_endpoint_desc"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local endpoint = input_dialog:getInputText()
                        if endpoint and #endpoint > 0 then
                            local success = self.ai_helper:setProviderEndpoint(provider, endpoint)
                            if success then
                                self.ai_provider = provider
                                UIManager:show(InfoMessage:new{
                                    text = self.loc:t("openai_endpoint_saved"),
                                    timeout = 3,
                                })
                            end
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            }
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:showCustomProviderMenu()
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end

    local provider_menu
    local items = {
        {
            text = self.loc:t("custom_provider_add"),
            callback = function()
                if provider_menu then UIManager:close(provider_menu) end
                self:showCustomProviderEditor()
            end,
        },
    }

    for id, provider in pairs(self.ai_helper.providers) do
        if id:match("^custom:") then
            table.insert(items, {
                text = (provider.name or id) .. "\n" .. (provider.endpoint or "") .. "\n" .. (provider.model or ""),
                callback = function()
                    if provider_menu then UIManager:close(provider_menu) end
                    self:showCustomProviderActions(id)
                end,
            })
        end
    end

    provider_menu = Menu:new{
        title = self.loc:t("menu_custom_providers"),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    UIManager:show(provider_menu)
end

function XRayPlugin:showCustomProviderActions(provider_id)
    local ButtonDialog = require("ui/widget/buttondialog")
    local provider = self.ai_helper.providers[provider_id]
    if not provider then return end
    local dialog
    dialog = ButtonDialog:new{
        title = provider.name or provider_id,
        buttons = {
            {
                {
                    text = self.loc:t("provider_select_title"),
                    callback = function()
                        self.ai_provider = provider_id
                        self.ai_helper:setDefaultProvider(provider_id)
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{text = string.format(self.loc:t("provider_selected"), provider.name or provider_id), timeout = 2})
                    end,
                },
            },
            {
                {
                    text = self.loc:t("custom_provider_edit"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showCustomProviderEditor(provider_id)
                    end,
                },
            },
            {
                {
                    text = self.loc:t("delete"),
                    callback = function()
                        self.ai_helper:deleteCustomProvider(provider_id)
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{text = self.loc:t("custom_provider_deleted"), timeout = 2})
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function XRayPlugin:showCustomProviderEditor(provider_id)
    local InputDialog = require("ui/widget/inputdialog")
    local provider = provider_id and self.ai_helper.providers[provider_id] or {}
    local thinking_mode = self.ai_helper:getThinkingMode(provider)
    local current = table.concat({
        provider.name or "Custom Provider",
        provider.endpoint or "https://api.openai.com/v1/chat/completions",
        provider.model or "gpt-4o-mini",
        provider.api_key or "",
        thinking_mode,
        provider.reasoning_effort or "high",
    }, "|")

    local input_dialog
    input_dialog = InputDialog:new{
        title = provider_id and self.loc:t("custom_provider_edit") or self.loc:t("custom_provider_add"),
        input = current,
        input_hint = "Name|Endpoint|Model|APIKey|thinking|effort",
        description = self.loc:t("custom_provider_editor_desc"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function() UIManager:close(input_dialog) end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local raw = input_dialog:getInputText() or ""
                        local fields = {}
                        raw = raw .. "|"
                        for field in raw:gmatch("(.-)|") do
                            table.insert(fields, field)
                            if #fields >= 6 then break end
                        end
                        local thinking, thinking_mode_value = self.ai_helper:normalizeThinkingMode(fields[5])
                        local data = {
                            name = fields[1],
                            endpoint = fields[2],
                            model = fields[3],
                            api_key = fields[4],
                            thinking_mode = thinking_mode_value,
                            thinking_enabled = thinking,
                            reasoning_effort = fields[6] or "high",
                        }
                        if provider_id then
                            self.ai_helper:updateCustomProvider(provider_id, data)
                        else
                            provider_id = self.ai_helper:createCustomProvider(data)
                        end
                        self.ai_provider = provider_id or self.ai_provider
                        if provider_id then self.ai_helper:setDefaultProvider(provider_id) end
                        UIManager:close(input_dialog)
                        UIManager:show(InfoMessage:new{text = self.loc:t("custom_provider_saved"), timeout = 2})
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:selectAIProvider()
    if not self.ai_helper then
        local AIHelper = require("aihelper")
        self.ai_helper = AIHelper
        self.ai_helper:init()
    end
    
    if not self.ai_provider and self.ai_helper.default_provider then
        self.ai_provider = self.ai_helper.default_provider
    end
    
    local provider_menu
    local providers = {}

    local ids = {}
    for id in pairs(self.ai_helper.providers) do
        table.insert(ids, id)
    end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local provider = self.ai_helper.providers[id]
        if provider and provider.enabled ~= false then
            local has_key = provider.api_key and #provider.api_key > 0
            local active = self.ai_provider == id or self.ai_helper.default_provider == id
            table.insert(providers, {
                text = (has_key and "✅ " or "❌ ") .. (provider.name or id) .. " - " .. (provider.model or "") .. (active and " ✓" or ""),
                callback = function()
                    if not has_key then
                        UIManager:show(InfoMessage:new{text = self.loc:t("set_key_first"), timeout = 3})
                        return
                    end
                    self.ai_provider = id
                    self.ai_helper:setDefaultProvider(id)
                    UIManager:show(InfoMessage:new{text = string.format(self.loc:t("provider_selected"), provider.name or id), timeout = 2})
                    if provider_menu then UIManager:close(provider_menu) end
                end,
            })
        end
    end

    provider_menu = Menu:new{
        title = self.loc:t("provider_select_title"),
        item_table = providers,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(provider_menu)
end



function XRayPlugin:showSummary()
    if not self.summary or #self.summary == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_summary_data"),
            timeout = 3,
        })
        return
    end
    
    UIManager:show(InfoMessage:new{
        text = "📖 " .. self.loc:t("summary_title") .. "\n\n" .. self.summary .. "\n\n(Spoiler-free)", 
        timeout = 15,
    })
end

function XRayPlugin:showThemes()
    if not self.themes or #self.themes == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_theme_data"),
            timeout = 3,
        })
        return
    end
    
    local text = "🎨 " .. self.loc:t("themes_title") .. "\n\n" 
    for i, theme in ipairs(self.themes) do
        text = text .. i .. ". " .. theme .. "\n"
    end
    
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = 10,
    })
end

function XRayPlugin:showTimeline(page)
    if not self.timeline or #self.timeline == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_timeline_data"),
            timeout = 5,
        })
        return
    end

    local page_size = 50
    page = page or 1
    local current_page, total_pages, start_index, end_index = self:getMenuPageBounds(#self.timeline, page, page_size)
    local items = {}
    for i = start_index, end_index do
        local event = self.timeline[i]
        local text = ""

        if event.chapter then
            text = text .. "📖 " .. self:clampText(event.chapter, 70) .. "\n"
        end

        if event.event then
            text = text .. self:clampText(event.event, 140)
        end

        if event.characters and #event.characters > 0 then
            text = text .. "\n👥 " .. self:clampText(table.concat(event.characters, ", "), 100)
        end
        
        table.insert(items, {
            text = text,
            callback = function()
                local detail_text = string.format(self.loc:t("timeline_event"), i) .. "\n\n"
                
                if event.chapter then
                    detail_text = detail_text .. self.loc:t("chapter") .. " " .. event.chapter .. "\n\n"
                end
                
                if event.event then
                    detail_text = detail_text .. event.event .. "\n\n"
                end
                
                if event.characters and #event.characters > 0 then
                    detail_text = detail_text .. self.loc:t("characters_involved") .. "\n"
                    for _, char in ipairs(event.characters) do
                        detail_text = detail_text .. "  • " .. char .. "\n"
                    end
                end
                
                if event.importance then
                    detail_text = detail_text .. "\n" .. self.loc:t("importance") .. "\n" .. event.importance
                end
                
                UIManager:show(InfoMessage:new{
                    text = detail_text,
                    timeout = 15,
                })
            end,
        })
    end

    self:addPagingItems(items, #self.timeline, current_page, total_pages, function(next_page)
        self:showTimeline(next_page)
    end)

    local timeline_menu = Menu:new{
        title = self:getPagedMenuTitle(self.loc:t("menu_timeline") .. " " .. self.loc:t("events"), #self.timeline, current_page, total_pages),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(timeline_menu)
end

function XRayPlugin:showHistoricalFigures(page)
    if not self.historical_figures or #self.historical_figures == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_historical_data"),
            timeout = 5,
        })
        return
    end

    local page_size = 50
    page = page or 1
    local current_page, total_pages, start_index, end_index = self:getMenuPageBounds(#self.historical_figures, page, page_size)
    local items = {}
    for i = start_index, end_index do
        local figure = self.historical_figures[i]
        local text = ""
        
        if figure.name then
            text = text .. "👤 " .. figure.name
        end
        
        if figure.birth_year or figure.death_year then
            text = text .. "\n   "
            if figure.birth_year then
                text = text .. figure.birth_year
            end
            if figure.death_year then
                text = text .. " - " .. figure.death_year
            elseif figure.birth_year then
                text = text .. " - ?"
            end
        end
        
        if figure.role then
            text = text .. "\n   " .. self:clampText(figure.role, 100)
        end
        
        table.insert(items, {
            text = text,
            callback = function()
                self:showHistoricalFigureDetails(figure)
            end,
        })
    end

    self:addPagingItems(items, #self.historical_figures, current_page, total_pages, function(next_page)
        self:showHistoricalFigures(next_page)
    end)

    local figures_menu = Menu:new{
        title = self:getPagedMenuTitle(self.loc:t("menu_historical_figures"), #self.historical_figures, current_page, total_pages),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(figures_menu)
end

function XRayPlugin:showHistoricalFigureDetails(figure)
    local text = "📜 " .. (figure.name or "Unknown") .. "\n\n"
    
    if figure.birth_year or figure.death_year then
        text = text .. "📅 "
        if figure.birth_year then
            text = text .. figure.birth_year
        end
        if figure.death_year then
            text = text .. " - " .. figure.death_year
        elseif figure.birth_year then
            text = text .. " - ?"
        end
        text = text .. "\n\n"
    end
    
    if figure.role then
        text = text .. "👔 " .. self.loc:t("role") .. ": " .. figure.role .. "\n\n"
    end
    
    
    if figure.biography then
        text = text .. "📖 " .. self.loc:t("hist_bio") .. ":\n" .. figure.biography .. "\n\n"
    end
    
    if figure.importance_in_book then
        text = text .. "📚 " .. self.loc:t("hist_importance") .. ":\n" .. figure.importance_in_book .. "\n\n"
    end
    
    if figure.context_in_book then
        text = text .. "💡 " .. self.loc:t("hist_context") .. ":\n" .. figure.context_in_book
    end
    
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = 20,
    })
end

function XRayPlugin:showChapterCharacters(page, cached_result)
    if not self.characters or #self.characters == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_char_data_fetch"),
            timeout = 3,
        })
        return
    end

    local found_chars
    local chapter_title
    if cached_result then
        found_chars = cached_result.found_chars or {}
        chapter_title = cached_result.chapter_title
    else
        if not self.chapter_analyzer then
            local ChapterAnalyzer = require("chapteranalyzer")
            self.chapter_analyzer = ChapterAnalyzer:new()
        end

        UIManager:show(InfoMessage:new{
            text = self.loc:t("analyzing_chapter"),
            timeout = 1,
        })

        local chapter_text
        local ok, text_result, title_result = pcall(function()
            return self.chapter_analyzer:getCurrentChapterText(self.ui)
        end)
        if ok then
            chapter_text = text_result
            chapter_title = title_result
        else
            logger.warn("XRayPlugin: chapter text extraction failed:", tostring(text_result))
        end

        if not chapter_text or #chapter_text == 0 then
            UIManager:show(InfoMessage:new{
                text = self.loc:t("chapter_text_error"),
                timeout = 3,
            })
            return
        end

        found_chars = self.chapter_analyzer:findCharactersInText(chapter_text, self.characters)
    end

    if #found_chars == 0 then
        UIManager:show(InfoMessage:new{
            text = string.format(self.loc:t("no_characters_in_chapter"), chapter_title or self.loc:t("this_chapter")),
            timeout = 5,
        })
        return
    end

    local page_size = 60
    page = page or 1
    local current_page, total_pages, start_index, end_index = self:getMenuPageBounds(#found_chars, page, page_size)
    local result_cache = {
        found_chars = found_chars,
        chapter_title = chapter_title,
    }
    local items = {}
    for i = start_index, end_index do
        local char_info = found_chars[i]
        local char = char_info.character
        local count = char_info.count
        
        local gender_icon = ""
        if char.gender == "male" or char.gender == "erkek" then
            gender_icon = "👨 "
        elseif char.gender == "female" or char.gender == "kadın" then
            gender_icon = "👩 "
        else
            gender_icon = "👤 "
        end
        
        table.insert(items, {
            text = string.format("%s%s (%dx)", gender_icon, char.name, count),
            callback = function()
                self:showCharacterInfo(char)
            end,
        })
    end

    self:addPagingItems(items, #found_chars, current_page, total_pages, function(next_page)
        self:showChapterCharacters(next_page, result_cache)
    end)

    local menu = Menu:new{
        title = string.format("📖 %s\n👥 %d %s%s",
                             chapter_title or self.loc:t("this_chapter"),
                             #found_chars,
                             self.loc:t("chapter_chars_title"),
                             total_pages > 1 and (" " .. current_page .. "/" .. total_pages) or ""),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(menu)
    
    logger.info("XRayPlugin: Showed chapter characters -", #found_chars, "found")
end

function XRayPlugin:showCharacterNotes()
    if not self.characters or #self.characters == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_char_data_fetch"), 
            timeout = 3,
        })
        return
    end
    
    if not self.notes_manager then
        local CharacterNotes = require("characternotes")
        self.notes_manager = CharacterNotes:new()
    end
    
    local book_path = self.ui.document.file
    self.character_notes = self.notes_manager:loadNotes(book_path)
    
    local items = {}
    local notes_count = 0
    
    for _, char in ipairs(self.characters) do
        local char_name = char.name or self.loc:t("unknown_character")
        local note = self.notes_manager:getNote(self.character_notes, char.name)
        if note then
            notes_count = notes_count + 1
            
            local note_preview = note.text or ""
            if #note_preview > 50 then
                note_preview = string.sub(note_preview, 1, 50) .. "..."
            end
            
            table.insert(items, {
                text = "📝 " .. char_name .. "\n   " .. note_preview,
                callback = function()
                    self:showCharacterWithNote(char, note)
                end,
            })
        end
    end
    
    if notes_count > 0 then
        table.insert(items, {            
            separator = true,
        })
    end
    
    for _, char in ipairs(self.characters) do
        local char_name = char.name or self.loc:t("unknown_character")
        local note = self.notes_manager:getNote(self.character_notes, char.name)
        if not note then
            table.insert(items, {
                text = "➕ " .. char_name .. " (" .. self.loc:t("add_note") .. ")",
                callback = function()
                    self:addCharacterNote(char)
                end,
            })
        end
    end
    
    local menu = Menu:new{
        title = string.format(self.loc:t("character_notes_title"), notes_count),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    
    UIManager:show(menu)
end

function XRayPlugin:showCharacterWithNote(char, note)
    local InputDialog = require("ui/widget/inputdialog")
    
    local input_dialog
    input_dialog = InputDialog:new{
        title = "📝 " .. char.name,
        input = note.text,
        input_hint = self.loc:t("note_hint"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("delete"),
                    callback = function()
                        self:deleteCharacterNote(char)
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local new_note = input_dialog:getInputText()
                        self:updateCharacterNote(char, new_note)
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:addCharacterNote(char)
    local InputDialog = require("ui/widget/inputdialog")
    
    local input_dialog
    input_dialog = InputDialog:new{
        title = string.format(self.loc:t("add_note_title"), char.name),
        input = "",
        input_hint = self.loc:t("note_hint"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("save"),
                    is_enter_default = true,
                    callback = function()
                        local note_text = input_dialog:getInputText()
                        if note_text and #note_text > 0 then
                            self:updateCharacterNote(char, note_text)
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:updateCharacterNote(char, note_text)
    if not self.notes_manager then
        return
    end
    
    self.notes_manager:setNote(self.character_notes, char.name, note_text)
    
    local book_path = self.ui.document.file
    self.notes_manager:saveNotes(book_path, self.character_notes)
    
    UIManager:show(InfoMessage:new{
        text = string.format(self.loc:t("note_saved"), char.name),
        timeout = 2,
    })
end

function XRayPlugin:deleteCharacterNote(char)
    if not self.notes_manager then
        return
    end
    
    self.notes_manager:deleteNote(self.character_notes, char.name)
    
    local book_path = self.ui.document.file
    self.notes_manager:saveNotes(book_path, self.character_notes)
    
    UIManager:show(InfoMessage:new{
        text = string.format(self.loc:t("note_deleted"), char.name),
        timeout = 2,
    })
    
    self:showCharacterNotes()
end

function XRayPlugin:showQuickXRayMenu()
    local ButtonDialog = require("ui/widget/buttondialog")
    
    local buttons = {
        {
            {
                text = self.loc:t("menu_characters"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showCharacters()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_chapter_characters"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showChapterCharacters()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_timeline"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showTimeline()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_historical_figures"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showHistoricalFigures()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_character_notes"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showCharacterNotes()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_ai_qa"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showAIQuestionDialog()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_fetch_ai"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:fetchFromAI()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_enrich_nearby_context"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:enrichFromNearbyContext()
                end,
            },
        },
        {
            {
                text = self.loc:t("menu_advanced_scan"),
                callback = function()
                    UIManager:close(self.quick_dialog)
                    self:showAdvancedAnalysisMenu()
                end,
            },
        },
    }
    
    self.quick_dialog = ButtonDialog:new{
        title = self.loc:t("quick_menu_title"),
        buttons = buttons,
    }
    
    UIManager:show(self.quick_dialog)
end

function XRayPlugin:showCharacterSearch()
    if not self.characters or #self.characters == 0 then
        UIManager:show(InfoMessage:new{
            text = self.loc:t("no_character_data"),
            timeout = 3,
        })
        return
    end
    
    local InputDialog = require("ui/widget/inputdialog")
    local plugin = self
    
    local input_dialog
    input_dialog = InputDialog:new{
        title = self.loc:t("search_character_title"),
        input = "",
        input_hint = self.loc:t("search_hint"),
        buttons = {
            {
                {
                    text = self.loc:t("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = self.loc:t("search_button"),
                    is_enter_default = true,
                    callback = function()
                        local search_text = input_dialog:getInputText()
                        UIManager:close(input_dialog)
                        
                        if search_text and #search_text > 0 then
                            local found_char = plugin:findCharacterByName(search_text)
                            if found_char then
                                plugin:showCharacterInfo(found_char)
                            else
                                UIManager:show(InfoMessage:new{
                                    text = string.format(self.loc:t("character_not_found"), search_text),
                                    timeout = 3,
                                })
                            end
                        end
                    end,
                },
            },
        },
    }
    
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function XRayPlugin:showFullXRayMenu()
    local menu_items = {}
    self:addToMainMenu(menu_items)
    
    if menu_items.xray and menu_items.xray.sub_item_table then
        self.full_menu = Menu:new{
            title = self.loc:t("menu_xray"),
            item_table = menu_items.xray.sub_item_table,
            is_borderless = true,
            is_popout = false,
            title_bar_fm_style = true,
            width = Screen:getWidth(),
            height = Screen:getHeight(),
        }
        UIManager:show(self.full_menu)
    end
end


function XRayPlugin:onShowXRayMenu()
    self:showQuickXRayMenu()
    return true
end

return XRayPlugin

