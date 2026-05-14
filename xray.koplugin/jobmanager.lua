-- JobManager - cooperative background AI analysis jobs for X-Ray
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local DocSettings = require("docsettings")

local JobManager = {}

function JobManager:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.state = o.state or { status = "idle" }
    return o
end

function JobManager:getStatePath(book_path)
    if not book_path then return nil end
    return DocSettings:getSidecarDir(book_path) .. "/xray_job_state.lua"
end

function JobManager:serialize(obj, indent, seen)
    indent = indent or ""
    seen = seen or {}
    local t = type(obj)
    if t == "table" then
        if seen[obj] then return "{--[[circular]]}" end
        seen[obj] = true
        local s = "{\n"
        for k, v in pairs(obj) do
            if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                s = s .. indent .. "  "
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    s = s .. k .. " = "
                elseif type(k) == "string" then
                    s = s .. "[" .. string.format("%q", k) .. "] = "
                else
                    s = s .. "[" .. tostring(k) .. "] = "
                end
                s = s .. self:serialize(v, indent .. "  ", seen) .. ",\n"
            end
        end
        return s .. indent .. "}"
    elseif t == "string" then
        return string.format("%q", obj)
    elseif t == "number" or t == "boolean" then
        return tostring(obj)
    end
    return "nil"
end

function JobManager:saveState(book_path)
    local path = self:getStatePath(book_path)
    if not path then return false end
    local dir = path:match("(.+)/[^/]+$")
    if dir then
        local lfs = require("libs/libkoreader-lfs")
        if not lfs.attributes(dir) then
            lfs.mkdir(dir)
        end
    end
    local f = io.open(path, "w")
    if not f then return false end
    f:write("-- X-Ray background job state\nreturn ")
    f:write(self:serialize(self.state))
    f:close()
    return true
end

function JobManager:loadState(book_path)
    local path = self:getStatePath(book_path)
    if not path then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    f:close()
    local ok, data = pcall(dofile, path)
    if ok and type(data) == "table" then
        self.state = data
        return data
    end
    return nil
end

function JobManager:clearState(book_path)
    local path = self:getStatePath(book_path)
    if path then os.remove(path) end
end

function JobManager:isRunning()
    local status = self.state and self.state.status
    return status == "scanning" or status == "calling_ai" or status == "merging" or status == "saving"
end

function JobManager:cancel()
    if self.state then
        self.state.cancel_requested = true
    end
end

function JobManager:getStatusText()
    local s = self.state or { status = "idle" }
    local lines = {
        "Status: " .. tostring(s.status or "idle"),
        "Mode: " .. tostring(s.analysis_mode or "-"),
        "Provider: " .. tostring(s.provider_name or s.provider_id or "-"),
        "Model: " .. tostring(s.model or "-"),
    }
    if s.stage then table.insert(lines, "Stage: " .. tostring(s.stage)) end
    if s.source_stats and s.source_stats.method then
        table.insert(lines, "Text source: " .. tostring(s.source_stats.method))
    elseif s.source_stats and s.source_stats.error then
        table.insert(lines, "Text source error: " .. tostring(s.source_stats.error))
    end
    if s.candidates then table.insert(lines, "Candidates: " .. tostring(#s.candidates)) end
    if s.chapter_summaries then table.insert(lines, "Text excerpts: " .. tostring(#s.chapter_summaries)) end
    if s.total_chunks and s.total_chunks > 0 then
        table.insert(lines, "Progress: " .. tostring(s.current_chunk or 0) .. "/" .. tostring(s.total_chunks))
    end
    if s.last_error then table.insert(lines, "Error: " .. tostring(s.last_error)) end
    return table.concat(lines, "\n")
end

function JobManager:finish(plugin, book_data)
    self.state.status = "saving"
    self.state.stage = "saving"
    self.state.job_completed_at = os.time()
    self:saveState(self.state.book_path)

    book_data.analysis_mode = self.state.analysis_mode
    book_data.provider_id = self.state.provider_id
    book_data.provider_name = self.state.provider_name
    book_data.model = self.state.model
    book_data.source_stats = self.state.source_stats or {}
    book_data.job_completed_at = self.state.job_completed_at

    if not plugin.cache_manager then
        local CacheManager = require("cachemanager")
        plugin.cache_manager = CacheManager:new()
    end
    plugin:applyBookData(book_data)
    local saved = plugin.cache_manager:saveCache(self.state.book_path, book_data)
    self.state.status = saved and "done" or "failed"
    self.state.stage = self.state.status
    if not saved then
        self.state.last_error = "cache_save_failed"
        self:saveState(self.state.book_path)
    else
        self:clearState(self.state.book_path)
    end

    if not self.state.silent then
        UIManager:show(InfoMessage:new{
            text = saved and plugin.loc:t("background_job_done") or plugin.loc:t("cache_save_failed"),
            timeout = 6,
        })
    end
end

function JobManager:fail(plugin, message)
    self.state.status = self.state.cancel_requested and "cancelled" or "failed"
    self.state.stage = self.state.status
    self.state.last_error = message
    self:saveState(self.state.book_path)
    if not self.state.silent then
        UIManager:show(InfoMessage:new{
            text = (self.state.status == "cancelled" and plugin.loc:t("background_job_cancelled") or plugin.loc:t("background_job_failed")) .. "\n\n" .. tostring(message or ""),
            timeout = 7,
        })
    end
end

function JobManager:buildBaseContext()
    return {
        reading_percent = self.state.reading_percent,
        spoiler_free = self.state.reading_percent < 100,
        source_mode = self.state.analysis_mode,
        character_candidates = self.state.candidates,
        chapter_summaries = self.state.chapter_summaries,
        nearby_text = self.state.nearby_text,
        nearby_context_stats = self.state.nearby_context_stats,
        source_stats = self.state.source_stats,
        existing_data = self.state.existing_data,
        token_budget_hint = self.state.analysis_mode == "chunked_fulltext" and "chunked" or "compact",
    }
end

function JobManager:setPromptPreview(plugin, context, label)
    local prompt = plugin.ai_helper:createPrompt(self.state.title, self.state.author, context)
    self.state.last_prompt_label = label or self.state.stage or "prompt"
    self.state.last_prompt_preview = prompt
    self.state.last_prompt_updated_at = os.time()
    if #self.state.last_prompt_preview > 30000 then
        self.state.last_prompt_preview = self.state.last_prompt_preview:sub(1, 30000) .. "\n\n[Prompt truncated for checkpoint preview]"
    end
    self:saveState(self.state.book_path)
    return prompt
end

function JobManager:getPromptPreview()
    if self.state and self.state.last_prompt_preview and #self.state.last_prompt_preview > 0 then
        return self.state.last_prompt_preview, self.state.last_prompt_label or "Prompt"
    end
    return nil, nil
end

function JobManager:preparePromptPreview(plugin)
    if not plugin.ai_helper then
        local AIHelper = require("aihelper")
        plugin.ai_helper = AIHelper
        plugin.ai_helper:init()
    end
    if not self.state or not self.state.title then
        return nil, nil
    end
    local context = self:buildBaseContext()
    local prompt = self:setPromptPreview(plugin, context, "Current final prompt")
    return prompt, self.state.last_prompt_label
end

function JobManager:callFinalAI(plugin)
    if self.state.cancel_requested then
        self:fail(plugin, "cancelled")
        return
    end

    self.state.status = "calling_ai"
    self.state.stage = "final_ai"
    self:saveState(self.state.book_path)

    local context = self:buildBaseContext()
    self:setPromptPreview(plugin, context, "Final X-Ray prompt")
    local data, err, detail = plugin.ai_helper:getBookData(
        self.state.title,
        self.state.author,
        self.state.provider_id,
        context
    )

    if not data then
        self:fail(plugin, detail or err or "ai_failed")
        return
    end

    self:finish(plugin, data)
end

function JobManager:processMetadata(plugin)
    UIManager:scheduleIn(0.1, function()
        self.state.candidates = {}
        self.state.chapter_summaries = {}
        self:callFinalAI(plugin)
    end)
end

function JobManager:processNearbyContext(plugin)
    local TextAnalyzer = require("textanalyzer")
    local analyzer = TextAnalyzer:new()

    UIManager:scheduleIn(0.05, function()
        self.state.status = "scanning"
        self.state.stage = "nearby_context"
        local text, stats = analyzer:getNearbyContext(plugin.ui, self.state.context_char_limit or 500)
        self.state.nearby_text = text
        self.state.nearby_context_stats = stats
        self.state.source_stats = stats
        self.state.chapter_summaries = {}
        self.state.candidates = analyzer:rankCandidates(analyzer:extractCandidatesFromText(text or "", {}), 40)
        if not text or #text == 0 then
            self:fail(plugin, "Could not extract nearby reading context.")
            return
        end
        self:saveState(self.state.book_path)
        self:callFinalAI(plugin)
    end)
end

function JobManager:processLocalCandidates(plugin)
    local TextAnalyzer = require("textanalyzer")
    local analyzer = TextAnalyzer:new()

    self.state.status = "scanning"
    self.state.stage = "building_chunks"
    local chunks, stats = analyzer:buildChunks(plugin.ui, self.state.reading_percent)
    self.state.source_stats = stats or {}
    self.state.total_chunks = #chunks
    self.state.current_chunk = 0
    self.state.candidate_map = self.state.candidate_map or {}
    self:saveState(self.state.book_path)

    if #chunks == 0 then
        self.state.source_stats = stats or { error = "no_text" }
        self:fail(plugin, "Could not extract book text for local candidate mode. Use Light mode for title-only analysis.")
        return
    end

    local function step()
        if self.state.cancel_requested then
            self:fail(plugin, "cancelled")
            return
        end

        self.state.current_chunk = (self.state.current_chunk or 0) + 1
        local chunk = chunks[self.state.current_chunk]
        if not chunk then
            self.state.candidates = analyzer:rankCandidates(self.state.candidate_map, 40)
            self.state.chapter_summaries = analyzer:summarizeChunks(chunks, 12)
            self.state.candidate_map = nil
            self:saveState(self.state.book_path)
            self:callFinalAI(plugin)
            return
        end

        self.state.stage = "scanning"
        analyzer:extractCandidatesFromText(chunk.text or "", self.state.candidate_map)
        self:saveState(self.state.book_path)
        UIManager:scheduleIn(0.05, step)
    end

    UIManager:scheduleIn(0.05, step)
end

function JobManager:processChunkedFullText(plugin)
    local TextAnalyzer = require("textanalyzer")
    local analyzer = TextAnalyzer:new()

    self.state.status = "scanning"
    self.state.stage = "building_chunks"
    local chunks, stats = analyzer:buildChunks(plugin.ui, self.state.reading_percent)
    self.state.source_stats = stats or {}
    self.state.total_chunks = #chunks
    self.state.current_chunk = #(self.state.partial_results or {})
    self.state.partial_results = self.state.partial_results or {}
    self.state.candidate_map = self.state.candidate_map or {}
    self:saveState(self.state.book_path)

    if #chunks == 0 then
        self.state.source_stats = stats or { error = "no_text" }
        self:fail(plugin, "Could not extract book text for chunked mode. Use Light mode for title-only analysis.")
        return
    end

    local function step()
        if self.state.cancel_requested then
            self:fail(plugin, "cancelled")
            return
        end

        self.state.current_chunk = (self.state.current_chunk or 0) + 1
        local chunk = chunks[self.state.current_chunk]
        if not chunk then
            self.state.stage = "merging"
            self.state.candidates = analyzer:rankCandidates(self.state.candidate_map, 40)
            self.state.chapter_summaries = {}
            for i, partial in ipairs(self.state.partial_results or {}) do
                table.insert(self.state.chapter_summaries, {
                    index = i,
                    title = partial.title,
                    summary = partial.summary,
                    characters = partial.characters,
                })
            end
            self.state.candidate_map = nil
            self:saveState(self.state.book_path)
            self:callFinalAI(plugin)
            return
        end

        self.state.status = "calling_ai"
        self.state.stage = "chunk_ai"
        analyzer:extractCandidatesFromText(chunk.text or "", self.state.candidate_map)
        self:saveState(self.state.book_path)

        local context = {
            reading_percent = self.state.reading_percent,
            spoiler_free = self.state.reading_percent < 100,
            source_mode = "text_chunk",
            chunk_title = chunk.title,
            book_text = chunk.text,
            token_budget_hint = "chunk",
        }
        self:setPromptPreview(plugin, context, "Chunk prompt " .. tostring(self.state.current_chunk) .. "/" .. tostring(self.state.total_chunks))
        local data, err, detail = plugin.ai_helper:getBookData(self.state.title, self.state.author, self.state.provider_id, context)
        if not data then
            self:fail(plugin, detail or err or "chunk_ai_failed")
            return
        end

        table.insert(self.state.partial_results, {
            title = chunk.title,
            summary = data.summary or "",
            characters = data.characters or {},
        })
        self:saveState(self.state.book_path)
        UIManager:scheduleIn(0.1, step)
    end

    UIManager:scheduleIn(0.1, step)
end

function JobManager:start(plugin, params)
    if self:isRunning() then
        return false, "job_running"
    end

    self.state = {
        status = "queued",
        stage = "queued",
        started_at = os.time(),
        book_path = params.book_path,
        title = params.title,
        author = params.author,
        provider_id = params.provider_id,
        provider_name = params.provider_name,
        model = params.model,
        analysis_mode = params.analysis_mode or "local_candidates",
        reading_percent = params.reading_percent or 100,
        existing_data = params.existing_data,
        initial_metadata = params.initial_metadata == true,
        silent = params.silent == true,
        context_char_limit = params.context_char_limit,
        cancel_requested = false,
    }
    self:saveState(params.book_path)

    if not self.state.silent then
        UIManager:show(InfoMessage:new{
            text = plugin.loc:t("background_job_started"),
            timeout = 4,
        })
    end

    if self.state.analysis_mode == "metadata" then
        self:processMetadata(plugin)
    elseif self.state.analysis_mode == "nearby_context" then
        self:processNearbyContext(plugin)
    elseif self.state.analysis_mode == "chunked_fulltext" then
        self:processChunkedFullText(plugin)
    else
        self:processLocalCandidates(plugin)
    end

    return true
end

function JobManager:resume(plugin)
    if not self.state or not self.state.book_path then
        return false, "no_job"
    end
    if self.state.status == "done" or self.state.status == "cancelled" then
        return false, "not_resumable"
    end
    if not plugin.ai_helper then
        local AIHelper = require("aihelper")
        plugin.ai_helper = AIHelper
        plugin.ai_helper:init()
    end
    if not plugin.cache_manager then
        local CacheManager = require("cachemanager")
        plugin.cache_manager = CacheManager:new()
    end
    self.state.cancel_requested = false
    if self.state.analysis_mode == "metadata" then
        self:processMetadata(plugin)
    elseif self.state.analysis_mode == "nearby_context" then
        self:processNearbyContext(plugin)
    elseif self.state.analysis_mode == "chunked_fulltext" then
        self:processChunkedFullText(plugin)
    else
        self:processLocalCandidates(plugin)
    end
    return true
end

return JobManager
