-- ChapterAnalyzer - Analyze which characters appear in current chapter/page
local logger = require("logger")

local ChapterAnalyzer = {}

ChapterAnalyzer.max_text_chars = 60000
ChapterAnalyzer.max_page_text_chars = 40000
ChapterAnalyzer.max_scan_characters = 250

local function firstText(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "table" then
        return value.text or value.title or ""
    end
    return ""
end

function ChapterAnalyzer:call(method_owner, method_name, ...)
    if not method_owner or type(method_owner[method_name]) ~= "function" then
        return nil
    end
    local args = {...}
    local ok, result = pcall(function()
        return method_owner[method_name](method_owner, unpack(args))
    end)
    if ok then return result end
    logger.warn("ChapterAnalyzer:", method_name, "failed:", tostring(result))
    return nil
end

function ChapterAnalyzer:getSafeCurrentPage(ui)
    local page = self:call(ui and ui.paging, "getCurrentPage")
        or self:call(ui and ui.rolling, "getCurrentPage")
        or self:call(ui and ui.document, "getCurrentPage")
        or (ui and ui.view and ui.view.state and ui.view.state.page)
        or 1
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    return math.floor(page)
end

function ChapterAnalyzer:getSafePageCount(ui)
    local pages = self:call(ui and ui.document, "getPageCount")
    pages = tonumber(pages) or 0
    if pages < 0 then pages = 0 end
    return math.floor(pages)
end

function ChapterAnalyzer:getSafeToc(ui)
    local toc = self:call(ui and ui.document, "getToc")
    if type(toc) == "table" then return toc end
    return nil
end

function ChapterAnalyzer:getSafePageText(ui, page)
    local text = self:call(ui and ui.document, "getPageText", page)
    return firstText(text)
end

function ChapterAnalyzer:limitText(text, limit)
    text = type(text) == "string" and text or ""
    limit = tonumber(limit) or self.max_text_chars
    if #text > limit then
        return text:sub(1, limit)
    end
    return text
end

function ChapterAnalyzer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Get current chapter/section text
function ChapterAnalyzer:getCurrentChapterText(ui)
    if not ui or not ui.document then
        logger.warn("ChapterAnalyzer: No document available")
        return nil
    end

    -- Check if it's a reflowable document (EPUB, etc.) or page-based (PDF, etc.)
    local is_reflowable = ui.rolling ~= nil
    local is_paged = ui.paging ~= nil

    logger.info("ChapterAnalyzer: Reflowable:", is_reflowable, "Paged:", is_paged)

    if is_reflowable then
        return self:getReflowableText(ui)
    elseif is_paged then
        return self:getPageBasedText(ui)
    else
        logger.warn("ChapterAnalyzer: Unknown document type")
        return self:getFallbackText(ui)
    end
end

-- Get text from reflowable documents (EPUB, HTML, FB2)
function ChapterAnalyzer:getReflowableText(ui)
    -- Get current position - different methods for different versions
    local current_pos = nil

    -- Try different methods to get current position
    if ui.rolling and ui.rolling.current_page then
        current_pos = ui.rolling.current_page
    elseif ui.rolling and ui.rolling.getCurrentPos then
        current_pos = self:call(ui.rolling, "getCurrentPos")
    elseif ui.document.getCurrentPos then
        current_pos = self:call(ui.document, "getCurrentPos")
    elseif ui.view and ui.view.state and ui.view.state.page then
        current_pos = ui.view.state.page
    else
        -- Last resort: use page 1
        current_pos = 1
    end
    current_pos = tonumber(current_pos) or 1

    logger.info("ChapterAnalyzer: Current position:", current_pos)

    -- Try to get chapter from TOC
    local toc = self:getSafeToc(ui)
    if not toc or #toc == 0 then
        logger.info("ChapterAnalyzer: No TOC, using visible text")
        return self:getVisibleTextReflowable(ui), "Bu Bölüm"
    end

    -- Find current chapter
    local current_chapter = nil
    local chapter_title = "Bu Bölüm"

    for i, chapter in ipairs(toc) do
        local chapter_page = tonumber(chapter.page) or 0
        if chapter_page <= current_pos then
            current_chapter = chapter
            chapter_title = chapter.title or "Bu Bölüm"
        else
            break
        end
    end

    if not current_chapter then
        logger.warn("ChapterAnalyzer: No current chapter found")
        return self:getVisibleTextReflowable(ui), "Bu Bölüm"
    end

    logger.info("ChapterAnalyzer: Current chapter:", chapter_title)

    -- For EPUB, we'll try to get text from the document
    -- Method 1: Try getTextFromPositions if available
    local text = ""
    local text_length = 50000  -- ~50k characters

    if ui.document.getTextFromPositions then
        local success, result = pcall(function()
            return ui.document:getTextFromPositions(current_pos, current_pos + text_length)
        end)

        if success and result and #result > 100 then
            text = self:limitText(result)
            logger.info("ChapterAnalyzer: Got", #text, "characters from positions")
            return text, chapter_title
        end
    end

    -- Method 2: Try to extract text from current chapter xpointer
    if ui.document.getTextFromXPointer and current_chapter.xpointer then
        local success, result = pcall(function()
            return ui.document:getTextFromXPointer(current_chapter.xpointer)
        end)

        if success and result and #result > 100 then
            text = self:limitText(result)
            logger.info("ChapterAnalyzer: Got", #text, "characters from xpointer")
            return text, chapter_title
        end
    end

    -- Method 3: Get visible text (fallback)
    text = self:getVisibleTextReflowable(ui)
    logger.info("ChapterAnalyzer: Using visible text fallback")

    return self:limitText(text), chapter_title
end

-- Get currently visible text (reflowable)
function ChapterAnalyzer:getVisibleTextReflowable(ui)
    -- Try multiple methods to get text
    local text = ""

    -- Method 1: Try getting text from view
    if ui.view and ui.view.document and ui.view.document.extractText then
        local success, result = pcall(function()
            return ui.view.document:extractText()
        end)
        if success and result and #result > 100 then
            logger.info("ChapterAnalyzer: Got text from view.document.extractText")
            return self:limitText(result)
        end
    end

    -- Method 2: Try document getFullText
    if ui.document.getFullText then
        local success, result = pcall(function()
            return ui.document:getFullText()
        end)
        if success and result and #result > 100 then
            logger.info("ChapterAnalyzer: Got text from getFullText")
            -- Limit size
            return self:limitText(result)
        end
    end

    -- Method 3: Try to read from pages (if document has pages)
    if ui.document.getPageCount and ui.document.getPageText then
        local page_count = self:getSafePageCount(ui)
        local max_pages = math.min(page_count, 20)
        local parts = {}
        local total_chars = 0

        for i = 1, max_pages do
            local page_text = self:getSafePageText(ui, i)
            if #page_text > 0 then
                local remaining = self.max_page_text_chars - total_chars
                if remaining <= 0 then break end
                if #page_text > remaining then
                    page_text = page_text:sub(1, remaining)
                end
                table.insert(parts, page_text)
                total_chars = total_chars + #page_text
            end
        end
        text = table.concat(parts, " ")

        if #text > 100 then
            logger.info("ChapterAnalyzer: Got text from pages")
            return text
        end
    end

    -- If nothing worked, return empty
    logger.warn("ChapterAnalyzer: Could not extract any text")
    return ""
end

-- Get text from page-based documents (PDF, DJVU)
function ChapterAnalyzer:getPageBasedText(ui)
    -- Try to get chapter from TOC
    local toc = self:getSafeToc(ui)
    if not toc or #toc == 0 then
        logger.info("ChapterAnalyzer: No TOC, using current page only")
        return self:getCurrentPageTextPDF(ui)
    end

    -- Find current chapter based on page
    local current_page = self:getSafeCurrentPage(ui)
    local current_chapter = nil
    local next_chapter = nil

    for i, chapter in ipairs(toc) do
        local chapter_page = tonumber(chapter.page) or 0
        if chapter_page <= current_page then
            current_chapter = chapter
            if i < #toc then
                next_chapter = toc[i + 1]
            end
        else
            break
        end
    end

    if not current_chapter then
        logger.warn("ChapterAnalyzer: No current chapter found")
        return self:getCurrentPageTextPDF(ui)
    end

    logger.info("ChapterAnalyzer: Current chapter:", current_chapter.title)

    -- Keep page-based scans close to the current page. Large PDF chapters can
    -- otherwise block low-power readers while concatenating dozens of pages.
    local doc_page_count = self:getSafePageCount(ui)
    local chapter_start = tonumber(current_chapter.page) or current_page
    local chapter_end = next_chapter and (tonumber(next_chapter.page) or current_page) - 1 or doc_page_count
    if doc_page_count <= 0 then doc_page_count = current_page + 4 end
    local window_before = 2
    local window_after = 4
    local start_page = math.max(chapter_start, current_page - window_before)
    local end_page = math.min(chapter_end, current_page + window_after)

    logger.info("ChapterAnalyzer: Analyzing pages", start_page, "to", end_page)

    -- Collect text from pages
    local parts = {}
    local total_chars = 0
    for page = start_page, end_page do
        local page_text = self:getSafePageText(ui, page)
        if #page_text > 0 then
            local remaining = self.max_page_text_chars - total_chars
            if remaining <= 0 then break end
            if #page_text > remaining then
                page_text = page_text:sub(1, remaining)
            end
            table.insert(parts, page_text)
            total_chars = total_chars + #page_text
        end
    end

    return table.concat(parts, " "), current_chapter.title
end

-- Get current page text (PDF/page-based) - fallback
function ChapterAnalyzer:getCurrentPageTextPDF(ui)
    local current_page = self:getSafeCurrentPage(ui)

    -- Try to get text from a small current-page window.
    local parts = {}
    local page_count = self:getSafePageCount(ui)
    if page_count <= 0 then page_count = current_page + 3 end
    for page = math.max(1, current_page - 1), math.min(page_count, current_page + 3) do
        local page_text = self:getSafePageText(ui, page)
        if #page_text > 0 then
            table.insert(parts, page_text)
        end
    end

    return self:limitText(table.concat(parts, " "), self.max_page_text_chars), "Bu Sayfa"
end

-- Fallback for unknown document types
function ChapterAnalyzer:getFallbackText(ui)
    logger.warn("ChapterAnalyzer: Using fallback text extraction")

    -- Try different methods
    local text = ""

    -- Method 1: Try to get selection text or visible text
    if ui.highlight and ui.highlight.selected_text then
        text = ui.highlight.selected_text.text or ""
    end

    -- Method 2: Try document getTextFromPositions if available
    if #text < 100 and ui.document.getTextFromPositions then
        local success, result = pcall(function()
            return ui.document:getTextFromPositions(0, 10000)
        end)
        if success and result then
            text = result
        end
    end

    -- Method 3: Just show a message
    if #text < 100 then
        logger.warn("ChapterAnalyzer: Could not extract text")
        return nil, nil
    end

    return text, "Bu Sayfa"
end

-- Find characters mentioned in text
function ChapterAnalyzer:findCharactersInText(text, characters)
    if not text or not characters then
        return {}
    end

    local found_characters = {}
    local limited_text = self:limitText(text, self.max_text_chars)
    local text_lower = string.lower(limited_text)
    local scanned = 0

    for _, char in ipairs(characters) do
        scanned = scanned + 1
        if scanned > self.max_scan_characters then
            break
        end
        local name = char.name
        if name and #name > 2 then
            -- Check full name
            local name_lower = string.lower(name)
            if string.find(text_lower, name_lower, 1, true) then
                table.insert(found_characters, {
                    character = char,
                    count = self:countMentions(text_lower, name_lower)
                })
            else
                -- Check first name only
                local first_name = string.match(name, "^(%S+)")
                if first_name and #first_name > 2 then
                    local first_name_lower = string.lower(first_name)
                    if string.find(text_lower, first_name_lower, 1, true) then
                        table.insert(found_characters, {
                            character = char,
                            count = self:countMentions(text_lower, first_name_lower)
                        })
                    end
                end
            end
        end
    end

    -- Sort by mention count
    table.sort(found_characters, function(a, b)
        return a.count > b.count
    end)

    logger.info("ChapterAnalyzer: Found", #found_characters, "characters in text")

    return found_characters
end

-- Count how many times a name appears
function ChapterAnalyzer:countMentions(text, name)
    local count = 0
    local pos = 1

    while true do
        local start_pos = string.find(text, name, pos, true)
        if not start_pos then break end
        count = count + 1
        pos = start_pos + 1
    end

    return count
end

return ChapterAnalyzer
