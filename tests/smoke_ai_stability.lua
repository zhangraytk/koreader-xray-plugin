#!/usr/bin/env lua

package.path = "../xray.koplugin/?.lua;xray.koplugin/?.lua;" .. package.path

package.loaded.logger = {
    info = function() end,
    warn = function() end,
    error = function() end,
}
package.loaded.socket = {
    sleep = function() end,
    gettime = function() return os.time() end,
}
package.loaded["socket.http"] = {}
package.loaded["ssl.https"] = {}
package.loaded.ssl = {}
package.loaded.ltn12 = {}
package.loaded.datastorage = {
    getSettingsDir = function() return "/tmp/xray-test-settings" end,
}
package.loaded["libs/libkoreader-lfs"] = {
    mkdir = function() return true end,
    attributes = function() return nil end,
}
package.loaded.docsettings = {
    getSidecarDir = function() return "/tmp/xray-test-sidecar" end,
}
package.loaded.gettext = function(text) return text end
package.loaded["ui/uimanager"] = {
    show = function() end,
    close = function() end,
    scheduleIn = function(_, callback) callback() end,
}
package.loaded["ui/widget/infomessage"] = {
    new = function(_, o) return o end,
}
package.loaded["ui/widget/menu"] = {
    new = function(_, o) return o end,
}
package.loaded["ui/widget/buttondialog"] = {
    new = function(_, o) return o end,
}
package.loaded["ui/widget/textviewer"] = {
    new = function(_, o) return o end,
}
package.loaded["ui/widget/container/widgetcontainer"] = {
    new = function(_, o)
        o = o or {}
        setmetatable(o, { __index = package.loaded["ui/widget/container/widgetcontainer"] })
        return o
    end,
}
package.loaded.device = {
    screen = {
        getWidth = function() return 600 end,
        getHeight = function() return 800 end,
    },
}

local ok_json, json = pcall(require, "json")
if not ok_json then
    local function make_parser(text)
        local pos = 1
        local function skip_ws()
            while text:sub(pos, pos):match("%s") do pos = pos + 1 end
        end
        local parse_value
        local function parse_string()
            assert(text:sub(pos, pos) == '"', "expected string")
            pos = pos + 1
            local out = {}
            while pos <= #text do
                local ch = text:sub(pos, pos)
                if ch == '"' then
                    pos = pos + 1
                    return table.concat(out)
                elseif ch == "\\" then
                    local next_ch = text:sub(pos + 1, pos + 1)
                    local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                    table.insert(out, escapes[next_ch] or next_ch)
                    pos = pos + 2
                else
                    table.insert(out, ch)
                    pos = pos + 1
                end
            end
            error("unterminated string")
        end
        local function parse_number()
            local start = pos
            while text:sub(pos, pos):match("[%d%+%-%.eE]") do pos = pos + 1 end
            return tonumber(text:sub(start, pos - 1))
        end
        local function parse_array()
            pos = pos + 1
            local arr = {}
            skip_ws()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
            while true do
                table.insert(arr, parse_value())
                skip_ws()
                local ch = text:sub(pos, pos)
                if ch == "]" then pos = pos + 1; return arr end
                assert(ch == ",", "expected array comma")
                pos = pos + 1
            end
        end
        local function parse_object()
            pos = pos + 1
            local obj = {}
            skip_ws()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                skip_ws()
                local key = parse_string()
                skip_ws()
                assert(text:sub(pos, pos) == ":", "expected object colon")
                pos = pos + 1
                obj[key] = parse_value()
                skip_ws()
                local ch = text:sub(pos, pos)
                if ch == "}" then pos = pos + 1; return obj end
                assert(ch == ",", "expected object comma")
                pos = pos + 1
            end
        end
        function parse_value()
            skip_ws()
            local ch = text:sub(pos, pos)
            if ch == '"' then return parse_string() end
            if ch == "{" then return parse_object() end
            if ch == "[" then return parse_array() end
            if text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
            if text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
            if text:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil end
            return parse_number()
        end
        return parse_value
    end
    json = {
        decode = function(text)
            return make_parser(text)()
        end,
        encode = function() return "{}" end,
    }
    package.loaded.json = json
end

local AIHelper = require("aihelper")
AIHelper.prompts = {
    fallback = {
        unknown_book = "Unknown",
        unknown_author = "Unknown",
        unnamed_character = "Unnamed",
        no_description = "",
        not_specified = "",
        unnamed_person = "Unnamed",
        no_biography = "",
    },
}

local function assert_true(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local parsed = AIHelper:decodeJSONObject([[Here is JSON:
```json
{"name":"Anna","role":"Lead","aliases":["A"]}
```
Thanks.]])
assert_eq(parsed.name, "Anna", "fenced JSON should parse")

local nested = AIHelper:decodeJSONObject([[prefix {"character":{"name":"Bob","meta":{"ok":true}}} suffix]])
assert_eq(nested.character.name, "Bob", "nested object should parse")

local later_valid = AIHelper:parseAIResponse([[Example:
{"foo":"bar"}
Final:
{"book_title":"Later Book","author":"Tester","characters":[{"name":"Eli"}]}]])
assert_eq(later_valid.book_title, "Later Book", "book parser should skip unrelated earlier JSON")

local later_character = AIHelper:decodeCharacterCandidate([[{"foo":"bar"} then {"character":{"name":"Zed","aliases":["Z"]}}]])
assert_eq(later_character.name, "Zed", "character parser should skip unrelated earlier JSON")

local candidate = AIHelper:normalizeCharacterCandidate({
    character = {
        name = "Clara",
        aliases = {"C"},
        description = "A witness",
    },
})
assert_eq(candidate.name, "Clara", "character wrapper should normalize")
assert_eq(candidate.aliases[1], "C", "aliases should normalize")

local main_text = AIHelper:parseAIResponse([[```json
{
  "book_title": "Test Book",
  "author": "Tester",
  "characters": [{"name": "Dana", "description": "Main"}],
  "timeline": []
}
```]])
assert_eq(main_text.book_title, "Test Book", "book JSON should parse")
assert_eq(main_text.characters[1].name, "Dana", "character list should survive validation")

local plugin = dofile("xray.koplugin/main.lua")
assert_true(plugin:shouldSkipAutoSeed("/books/sample.pdf", {}), "pdf extension should skip auto seed")
assert_true(not plugin:shouldSkipAutoSeed("/books/sample.epub", {}), "epub extension should not skip auto seed")
assert_true(plugin:shouldSkipAutoSeed("/books/noext", {
    document = {
        getProps = function()
            return { format = "PDF" }
        end,
    },
}), "pdf document format should skip auto seed")

assert_true(not plugin:shouldSkipAutoSeed("/books/noext", {
    document = {
        getProps = function()
            error("backend props failed")
        end,
    },
}), "throwing getProps should not crash auto-skip check")

plugin.loc = { t = function(_, key) return key end }
plugin.ui = {
    document = {
        file = "/books/no-props.epub",
        getProps = function() error("getProps should not be called by metadata startup") end,
        getPageCount = function() error("page count failed") end,
    },
}
plugin.ai_helper = {
    settings = { auto_metadata_on_open = true, auto_metadata_silent = true },
    default_provider = "gemini",
    providers = { gemini = { api_key = "key", name = "Gemini", model = "test", type = "gemini" } },
}
local started_params
plugin.getJobManager = function()
    return {
        loadState = function() return nil end,
        start = function(_, _, params)
            started_params = params
            return true
        end,
    }
end
local ok_auto, auto_err = pcall(function() plugin:maybeStartInitialMetadataJob() end)
assert_true(ok_auto, "metadata auto-start should not crash when getProps throws: " .. tostring(auto_err))
assert_eq(started_params.analysis_mode, "metadata", "auto-start should still use metadata mode")

local ok_spoiler, spoiler_err = pcall(function()
    plugin:askSpoilerPreference()
end)
assert_true(ok_spoiler, "spoiler menu should survive page API failures: " .. tostring(spoiler_err))

local TextAnalyzer = require("textanalyzer")
local analyzer = TextAnalyzer:new()
analyzer.buildChunks = function()
    error("diagnose should not call buildChunks")
end
local diagnose_text = analyzer:diagnose({
    document = {
        file = "/books/sample.pdf",
        getPageCount = function() return 500 end,
        getPageText = function(page)
            if page == 1 then error("page text failed") end
            return "sample page text"
        end,
    },
    paging = { getCurrentPage = function() return 1 end },
})
assert_true(diagnose_text:match("sample pages") ~= nil, "diagnose should report sampled pages")
assert_true(diagnose_text:match("sample errors") ~= nil, "diagnose should report page extraction errors")

local chunks, stats = TextAnalyzer:new():buildChunks({
    document = {
        file = "/books/large.pdf",
        getPageCount = function() return 500 end,
        getPageText = function(page) return "Alice Bob page " .. tostring(page) .. "\n" end,
        getToc = function() return {} end,
    },
}, 100)
assert_true(#chunks > 0, "PDF limited scan should still build chunks")
assert_true(stats.limited, "large PDF scan should report limit")
assert_eq(stats.page_limit, TextAnalyzer.max_pdf_scan_pages, "PDF scan should use PDF page cap")

local ChapterAnalyzer = require("chapteranalyzer")
local chapter_analyzer = ChapterAnalyzer:new()
local text, title = chapter_analyzer:getCurrentPageTextPDF({
    paging = { getCurrentPage = function() error("current page failed") end },
    document = {
        getPageCount = function() error("page count failed") end,
        getPageText = function(page)
            if page == 1 then error("page text failed") end
            return "Alice appears"
        end,
    },
})
assert_true(type(text) == "string", "PDF page text fallback should not crash")
assert_eq(title, "Bu Sayfa", "PDF fallback title should be preserved")

local found = chapter_analyzer:findCharactersInText(string.rep("Alice ", 20000), {
    { name = "Alice" },
    { name = "Bob" },
})
assert_eq(found[1].character.name, "Alice", "chapter character scan should find limited text matches")

local JobManager = require("jobmanager")
local jm = JobManager:new()
jm.state = {
    status = "calling_ai",
    request_size = 12,
    response_size = 34,
    status_code = 500,
    compatibility_retry = true,
    last_error_code = "error_500",
    last_error_detail = "old",
}
assert_true(not jm:isRunning(), "stale sidecar running state should not count as active job")
assert_true(jm:isStateResumable(), "stale running sidecar state should be resumable")
jm:clearRequestDiagnostics(true)
assert_true(jm.state.status_code == nil and jm.state.last_error_code == nil, "request diagnostics should clear before resumed scans")

print("smoke_ai_stability: ok")
