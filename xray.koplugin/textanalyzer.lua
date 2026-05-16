-- TextAnalyzer - lightweight document chunking and local character candidates
local logger = require("logger")

local TextAnalyzer = {}

TextAnalyzer.max_chunk_chars = 14000
TextAnalyzer.max_candidate_contexts = 2

function TextAnalyzer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

local function trim(text)
    if type(text) ~= "string" then return "" end
    return text:match("^%s*(.-)%s*$") or ""
end

local function compact(text)
    text = trim(text)
    text = text:gsub("%s+", " ")
    return text
end

local function firstText(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "table" then
        return value.text or value.title or ""
    end
    return ""
end

function TextAnalyzer:getBookRange(ui, reading_percent)
    local page_count = 0
    local ok, pages = pcall(function()
        return ui and ui.document and ui.document:getPageCount()
    end)
    if ok and tonumber(pages) and tonumber(pages) > 0 then
        page_count = tonumber(pages)
    end

    local percent = tonumber(reading_percent) or 100
    if percent < 1 then percent = 1 end
    if percent > 100 then percent = 100 end

    local end_page = page_count
    if page_count > 0 and percent < 100 then
        end_page = math.max(1, math.floor(page_count * percent / 100))
    end

    return 1, end_page, page_count
end

function TextAnalyzer:splitLongText(text, title, chunks)
    text = trim(text)
    if #text == 0 then return end

    local start_pos = 1
    while start_pos <= #text do
        local end_pos = math.min(#text, start_pos + self.max_chunk_chars - 1)
        if end_pos < #text then
            local search_start = math.max(start_pos, end_pos - 1200)
            local paragraph_break = nil
            local pos = search_start
            while pos <= end_pos do
                local found = text:find("\n%s*\n", pos)
                if not found or found > end_pos then break end
                paragraph_break = found
                pos = found + 1
            end
            if paragraph_break and paragraph_break >= start_pos then
                end_pos = paragraph_break
            end
        end
        local part = trim(text:sub(start_pos, end_pos))
        if #part > 0 then
            table.insert(chunks, {
                index = #chunks + 1,
                title = title or ("Part " .. tostring(#chunks + 1)),
                text = part,
                char_count = #part,
            })
        end
        start_pos = end_pos + 1
    end
end

function TextAnalyzer:getTextFromPages(ui, start_page, end_page)
    local parts = {}
    if not ui or not ui.document or type(ui.document.getPageText) ~= "function" then
        return ""
    end

    for page = start_page, end_page do
        local ok, page_text = pcall(function()
            return ui.document:getPageText(page)
        end)
        page_text = ok and firstText(page_text) or ""
        if #page_text > 0 then
            table.insert(parts, page_text)
        end
    end

    return table.concat(parts, "\n\n")
end

function TextAnalyzer:buildChunks(ui, reading_percent)
    local chunks = {}
    if not ui or not ui.document then
        return chunks, { error = "no_document" }
    end

    local start_page, end_page, page_count = self:getBookRange(ui, reading_percent)
    local doc = ui.document
    local book_path = doc.file or (doc.getFileName and doc:getFileName()) or ""

    local ok_toc, toc = pcall(function()
        return doc:getToc()
    end)
    local attempts = {}

    if ok_toc and type(toc) == "table" and #toc > 0 and type(doc.getPageText) == "function" then
        for i, chapter in ipairs(toc) do
            local chapter_page = tonumber(chapter.page) or 1
            if chapter_page <= end_page then
                local next_page = end_page + 1
                if toc[i + 1] and tonumber(toc[i + 1].page) then
                    next_page = math.min(end_page + 1, tonumber(toc[i + 1].page))
                end
                local chapter_end = math.max(chapter_page, next_page - 1)
                if chapter_end >= start_page then
                    local text = self:getTextFromPages(ui, math.max(start_page, chapter_page), chapter_end)
                    self:splitLongText(text, chapter.title or ("Chapter " .. tostring(i)), chunks)
                end
            end
        end
        if #chunks > 0 then
            return chunks, { method = "toc_pages", page_count = page_count, end_page = end_page, attempts = attempts }
        end
        table.insert(attempts, "toc_pages:0")
    end

    if type(doc.getPageText) == "function" and page_count > 0 then
        local page = start_page
        while page <= end_page do
            local chunk_end = math.min(end_page, page + 9)
            local text = self:getTextFromPages(ui, page, chunk_end)
            self:splitLongText(text, "Pages " .. tostring(page) .. "-" .. tostring(chunk_end), chunks)
            page = chunk_end + 1
        end
        if #chunks > 0 then
            return chunks, { method = "pages", page_count = page_count, end_page = end_page, attempts = attempts }
        end
        table.insert(attempts, "pages:0")
    end

    if type(doc.getFullText) == "function" then
        local ok_full, full_text = pcall(function()
            return doc:getFullText()
        end)
        if ok_full and type(full_text) == "string" and #full_text > 0 then
            if reading_percent and reading_percent < 100 then
                full_text = full_text:sub(1, math.max(1, math.floor(#full_text * reading_percent / 100)))
            end
            self:splitLongText(full_text, "Book text", chunks)
            if #chunks > 0 then
                return chunks, { method = "full_text", page_count = page_count, end_page = end_page, attempts = attempts }
            end
        end
        table.insert(attempts, "getFullText:" .. tostring(ok_full and #(full_text or "") or "error"))
    end

    if type(doc.getTextFromPositions) == "function" then
        local ok_pos, pos_text = pcall(function()
            return doc:getTextFromPositions(0, 120000)
        end)
        if ok_pos and type(pos_text) == "string" and #pos_text > 0 then
            if reading_percent and reading_percent < 100 then
                pos_text = pos_text:sub(1, math.max(1, math.floor(#pos_text * reading_percent / 100)))
            end
            self:splitLongText(pos_text, "Book text", chunks)
            if #chunks > 0 then
                return chunks, { method = "positions", page_count = page_count, end_page = end_page, attempts = attempts }
            end
        end
        table.insert(attempts, "getTextFromPositions:" .. tostring(ok_pos and #(pos_text or "") or "error"))
    end

    if ui.view and ui.view.document and type(ui.view.document.extractText) == "function" then
        local ok_view, view_text = pcall(function()
            return ui.view.document:extractText()
        end)
        if ok_view and type(view_text) == "string" and #view_text > 0 then
            self:splitLongText(view_text, "Visible text", chunks)
            if #chunks > 0 then
                return chunks, { method = "view_extract_text", page_count = page_count, end_page = end_page, attempts = attempts }
            end
        end
        table.insert(attempts, "view.extractText:" .. tostring(ok_view and #(view_text or "") or "error"))
    end

    local ok_chapter, ChapterAnalyzer = pcall(require, "chapteranalyzer")
    if ok_chapter and ChapterAnalyzer then
        local analyzer = ChapterAnalyzer:new()
        local ok_current, current_text, current_title = pcall(function()
            return analyzer:getCurrentChapterText(ui)
        end)
        if ok_current and type(current_text) == "string" and #current_text > 0 then
            self:splitLongText(current_text, current_title or "Current section", chunks)
            if #chunks > 0 then
                return chunks, { method = "current_section", page_count = page_count, end_page = end_page, attempts = attempts }
            end
        end
        table.insert(attempts, "current_section:" .. tostring(ok_current and #(current_text or "") or "error"))
    end

    if book_path:lower():match("%.epub$") then
        local epub_text, epub_stats = self:getTextFromEpubFile(book_path, reading_percent)
        if #epub_text > 0 then
            self:splitLongText(epub_text, "EPUB text", chunks)
            if #chunks > 0 then
                epub_stats.page_count = page_count
                epub_stats.end_page = end_page
                epub_stats.attempts = attempts
                return chunks, epub_stats
            end
        end
        table.insert(attempts, tostring(epub_stats.method or "epub_zip") .. ":" .. tostring(epub_stats.error or #epub_text))
    end

    logger.warn("TextAnalyzer: Could not build text chunks")
    return chunks, { error = "no_text", page_count = page_count, end_page = end_page, attempts = attempts, book_path = book_path }
end

function TextAnalyzer:getCurrentPage(ui)
    if not ui then return nil end
    local methods = {
        function() return ui.getCurrentPage and ui:getCurrentPage() end,
        function() return ui.paging and ui.paging.getCurrentPage and ui.paging:getCurrentPage() end,
        function() return ui.rolling and ui.rolling.getCurrentPage and ui.rolling:getCurrentPage() end,
        function() return ui.document and ui.document.getCurrentPage and ui.document:getCurrentPage() end,
        function() return ui.view and ui.view.state and ui.view.state.page end,
    }
    for _, method in ipairs(methods) do
        local ok, page = pcall(method)
        page = ok and tonumber(page) or nil
        if page and page > 0 then return math.floor(page) end
    end
    return nil
end

function TextAnalyzer:trimAroundCenter(text, limit)
    text = compact(text)
    limit = tonumber(limit) or 500
    if limit < 100 then limit = 100 end
    if #text <= limit then return text end
    local center = math.floor(#text / 2)
    local start_pos = math.max(1, center - math.floor(limit / 2))
    local excerpt = text:sub(start_pos, start_pos + limit - 1)
    if start_pos > 1 then excerpt = "..." .. excerpt end
    if start_pos + limit <= #text then excerpt = excerpt .. "..." end
    return excerpt
end

function TextAnalyzer:getNearbyContext(ui, char_limit)
    local stats = { method = "nearby_context", char_limit = char_limit or 500 }
    if not ui or not ui.document then
        stats.error = "no_document"
        return "", stats
    end

    char_limit = tonumber(char_limit) or 500
    if char_limit < 100 then char_limit = 100 end
    if char_limit > 5000 then char_limit = 5000 end

    local doc = ui.document
    local page = self:getCurrentPage(ui) or 1
    local page_count = 0
    local ok_pages, pages = pcall(function() return doc:getPageCount() end)
    if ok_pages and tonumber(pages) then page_count = tonumber(pages) end
    stats.current_page = page
    stats.page_count = page_count

    if type(doc.getPageText) == "function" then
        local parts = {}
        local start_page = math.max(1, page - 1)
        local end_page = page_count > 0 and math.min(page_count, page + 1) or page + 1
        for p = start_page, end_page do
            local ok, page_text = pcall(function() return doc:getPageText(p) end)
            page_text = ok and firstText(page_text) or ""
            if #page_text > 0 then
                table.insert(parts, page_text)
            end
        end
        local text = table.concat(parts, "\n\n")
        if #text > 0 then
            stats.method = "nearby_pages"
            stats.raw_char_count = #text
            return self:trimAroundCenter(text, char_limit), stats
        end
    end

    local ok_chapter, ChapterAnalyzer = pcall(require, "chapteranalyzer")
    if ok_chapter and ChapterAnalyzer then
        local analyzer = ChapterAnalyzer:new()
        local ok_current, chapter_text, chapter_title = pcall(function()
            return analyzer:getCurrentChapterText(ui)
        end)
        if ok_current and type(chapter_text) == "string" and #chapter_text > 0 then
            stats.method = "current_chapter"
            stats.chapter_title = chapter_title
            stats.raw_char_count = #chapter_text
            return self:trimAroundCenter(chapter_text, char_limit), stats
        end
    end

    local reading_percent = 100
    if page_count > 0 then
        reading_percent = math.max(1, math.min(100, math.floor(page / page_count * 100)))
    end
    local chunks, chunk_stats = self:buildChunks(ui, reading_percent)
    if chunks and #chunks > 0 then
        local chunk = chunks[#chunks]
        stats.method = "nearby_chunk"
        stats.source_method = chunk_stats and chunk_stats.method
        stats.raw_char_count = #(chunk.text or "")
        return self:trimAroundCenter(chunk.text or "", char_limit), stats
    end

    stats.error = "no_text"
    return "", stats
end

function TextAnalyzer:getTextFromEpubFile(book_path, reading_percent)
    local stats = {
        method = "epub_zip_unavailable",
        book_path = book_path,
        files = 0,
        error = "no_portable_epub_zip_reader",
    }
    if not book_path or #book_path == 0 then return "", stats end

    -- Avoid shelling out to platform-specific unzip binaries from the reader
    -- process. This fallback should be re-enabled only through a KOReader zip API.
    stats.detail = "No portable KOReader EPUB zip reader is wired for this fallback"
    return "", stats
end

function TextAnalyzer:diagnose(ui)
    local lines = {}
    if not ui or not ui.document then
        return "No document available"
    end

    local doc = ui.document
    local book_path = doc.file or (doc.getFileName and doc:getFileName()) or ""
    table.insert(lines, "Book: " .. tostring(book_path))

    local methods = {
        "getToc", "getPageCount", "getPageText", "getFullText",
        "getTextFromPositions", "getCurrentPage", "getFileName",
    }
    for _, name in ipairs(methods) do
        table.insert(lines, name .. ": " .. tostring(type(doc[name])))
    end

    local chunks, stats = self:buildChunks(ui, 100)
    table.insert(lines, "")
    table.insert(lines, "buildChunks method: " .. tostring(stats and stats.method or "none"))
    table.insert(lines, "buildChunks error: " .. tostring(stats and stats.error or "none"))
    table.insert(lines, "chunks: " .. tostring(#chunks))
    if stats and stats.attempts then
        table.insert(lines, "attempts: " .. table.concat(stats.attempts, ", "))
    end
    if chunks[1] then
        table.insert(lines, "first chunk chars: " .. tostring(#(chunks[1].text or "")))
        table.insert(lines, "first chunk preview:\n" .. (chunks[1].text or ""):sub(1, 1000))
    end
    return table.concat(lines, "\n")
end

function TextAnalyzer:addCandidate(map, name, context, position)
    name = compact(name)
    if #name < 2 or #name > 48 then return end

    local lower = name:lower()
    local stopwords = {
        ["the"] = true, ["and"] = true, ["chapter"] = true, ["book"] = true,
        ["this"] = true, ["that"] = true, ["with"] = true,
    }
    if stopwords[lower] then return end

    local entry = map[name]
    if not entry then
        map._size = map._size or 0
        if map._size > 600 then return end
        entry = {
            name = name,
            count = 0,
            first_seen = position or 0,
            contexts = {},
        }
        map[name] = entry
        map._size = map._size + 1
    end

    entry.count = entry.count + 1
    if position and (entry.first_seen == 0 or position < entry.first_seen) then
        entry.first_seen = position
    end

    context = compact(context)
    if #context > 180 then
        context = context:sub(1, 180)
    end
    if #context > 0 and #entry.contexts < self.max_candidate_contexts then
        table.insert(entry.contexts, context)
    end
end

function TextAnalyzer:extractAsciiNames(text, map)
    for pos, name in text:gmatch("()(%u[%a'%-]+%s+%u[%a'%-]+)") do
        local start_pos = math.max(1, pos - 70)
        local end_pos = math.min(#text, pos + #name + 70)
        self:addCandidate(map, name, text:sub(start_pos, end_pos), pos)
    end

    for pos, name in text:gmatch("()(%u[%a'%-][%a'%-]+)") do
        local start_pos = math.max(1, pos - 60)
        local end_pos = math.min(#text, pos + #name + 60)
        self:addCandidate(map, name, text:sub(start_pos, end_pos), pos)
    end
end

local function utf8Chars(text)
    local chars = {}
    local i = 1
    while i <= #text do
        local b = text:byte(i)
        local len = 1
        if b and b >= 240 then len = 4
        elseif b and b >= 224 then len = 3
        elseif b and b >= 192 then len = 2 end
        table.insert(chars, text:sub(i, i + len - 1))
        i = i + len
    end
    return chars
end

local function utf8Codepoint(ch)
    local b1, b2, b3, b4 = ch:byte(1, 4)
    if not b1 then return nil end
    if b1 < 0x80 then
        return b1
    elseif b1 >= 0xC2 and b1 <= 0xDF and b2 and b2 >= 0x80 and b2 <= 0xBF then
        return (b1 - 0xC0) * 0x40 + (b2 - 0x80)
    elseif b1 >= 0xE0 and b1 <= 0xEF and b2 and b3
        and b2 >= 0x80 and b2 <= 0xBF
        and b3 >= 0x80 and b3 <= 0xBF then
        return (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
    elseif b1 >= 0xF0 and b1 <= 0xF4 and b2 and b3 and b4
        and b2 >= 0x80 and b2 <= 0xBF
        and b3 >= 0x80 and b3 <= 0xBF
        and b4 >= 0x80 and b4 <= 0xBF then
        return (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
    end
    return nil
end

local function isCJKChar(ch)
    local code = utf8Codepoint(ch)
    if not code then return false end
    return (code >= 0x4E00 and code <= 0x9FFF)
        or (code >= 0x3400 and code <= 0x4DBF)
        or (code >= 0x20000 and code <= 0x2A6DF)
        or (code >= 0x2A700 and code <= 0x2B73F)
        or (code >= 0x2B740 and code <= 0x2B81F)
        or (code >= 0x2B820 and code <= 0x2CEAF)
        or (code >= 0x2CEB0 and code <= 0x2EBEF)
        or (code >= 0x30000 and code <= 0x3134F)
end

function TextAnalyzer:extractCJKNames(text, map)
    local chars = utf8Chars(text)
    local byte_positions = {}
    local byte_pos = 1
    for i, ch in ipairs(chars) do
        byte_positions[i] = byte_pos
        byte_pos = byte_pos + #ch
    end
    local common = {
        ["一个"] = true, ["自己"] = true, ["他们"] = true, ["我们"] = true, ["这个"] = true,
        ["没有"] = true, ["什么"] = true, ["时候"] = true, ["先生"] = true, ["太太"] = true,
    }

    for i = 1, #chars - 1 do
        if isCJKChar(chars[i]) and isCJKChar(chars[i + 1]) then
            for len = 2, 4 do
                if i + len - 1 <= #chars then
                    local name = table.concat(chars, "", i, i + len - 1)
                    if not common[name] then
                        byte_pos = byte_positions[i] or 1
                        local context = text:sub(math.max(1, byte_pos - 80), math.min(#text, byte_pos + 120))
                        self:addCandidate(map, name, context, byte_pos)
                    end
                end
            end
        end
    end
end

function TextAnalyzer:extractCandidatesFromText(text, existing_map)
    local map = existing_map or {}
    text = text or ""
    if #text == 0 then return map end
    self:extractAsciiNames(text, map)
    self:extractCJKNames(text, map)
    return map
end

function TextAnalyzer:rankCandidates(map, limit)
    local candidates = {}
    for _, entry in pairs(map or {}) do
        if type(entry) == "table" and entry.count >= 2 then
            table.insert(candidates, entry)
        end
    end
    table.sort(candidates, function(a, b)
        if a.count == b.count then
            return (a.first_seen or 0) < (b.first_seen or 0)
        end
        return a.count > b.count
    end)

    limit = limit or 40
    while #candidates > limit do
        table.remove(candidates)
    end
    return candidates
end

function TextAnalyzer:summarizeChunks(chunks, limit)
    local summaries = {}
    for i, chunk in ipairs(chunks or {}) do
        if limit and i > limit then break end
        local text = compact(chunk.text or "")
        table.insert(summaries, {
            index = i,
            title = chunk.title,
            excerpt = text:sub(1, 900),
            char_count = #text,
        })
    end
    return summaries
end

return TextAnalyzer
