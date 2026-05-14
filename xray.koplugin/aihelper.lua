-- AIHelper - Google Gemini & ChatGPT for X-Ray
local http = require("socket.http")
local https = require("ssl.https")
local socket = require("socket")
local ssl = require("ssl")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")

local AIHelper = {}

-- AI Provider settings (default values)
AIHelper.providers = {
    gemini = {
        name = "Google Gemini",
        type = "gemini",
        enabled = true,
        api_key = nil,
        model = "gemini-3.1-flash-lite",
    },
    chatgpt = {
        name = "OpenAI Compatible",
        type = "openai_compatible",
        enabled = true,
        api_key = nil,
        endpoint = "https://api.openai.com/v1/chat/completions",
        model = "gpt-4o-mini",
        thinking_enabled = nil,
        reasoning_effort = "high",
    }
}

AIHelper.model_override = nil

function AIHelper:normalizeReasoningEffort(effort)
    if effort == "high" or effort == "max" then
        return effort
    elseif effort == "low" or effort == "medium" then
        return "high"
    elseif effort == "xhigh" then
        return "max"
    end
    return nil
end

function AIHelper:normalizeThinkingMode(value)
    if type(value) == "string" then
        value = self:trimText(value):lower()
        if value == "enabled" or value == "true" or value == "on" or value == "yes" then
            return true, "enabled"
        elseif value == "disabled" or value == "false" or value == "off" or value == "no" then
            return false, "disabled"
        elseif value == "omit" or value == "none" or value == "default" or value == "" then
            return nil, "omit"
        end
    elseif value == true then
        return true, "enabled"
    elseif value == false then
        return false, "disabled"
    elseif value == nil then
        return nil, "omit"
    end
    return nil, "omit"
end

function AIHelper:getThinkingMode(provider)
    provider = provider or {}
    if provider.thinking_enabled == true then
        return "enabled"
    elseif provider.thinking_enabled == false then
        return "disabled"
    end
    return "omit"
end

function AIHelper:trimText(text)
    if type(text) ~= "string" then return "" end
    return text:match("^%s*(.-)%s*$") or ""
end

function AIHelper:ensureSettingsDir()
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    return xray_dir
end

function AIHelper:loadRuntimeSettingsFromFile()
    self.settings = self.settings or {}
    local xray_dir = self:ensureSettingsDir()

    local auto_file = io.open(xray_dir .. "/auto_metadata_on_open.txt", "r")
    if auto_file then
        local value = auto_file:read("*a"):match("^%s*(.-)%s*$")
        auto_file:close()
        if value == "enabled" or value == "true" then
            self.settings.auto_metadata_on_open = true
        elseif value == "disabled" or value == "false" then
            self.settings.auto_metadata_on_open = false
        end
    end

    local silent_file = io.open(xray_dir .. "/auto_metadata_silent.txt", "r")
    if silent_file then
        local value = silent_file:read("*a"):match("^%s*(.-)%s*$")
        silent_file:close()
        if value == "enabled" or value == "true" then
            self.settings.auto_metadata_silent = true
        elseif value == "disabled" or value == "false" then
            self.settings.auto_metadata_silent = false
        end
    end

    local context_file = io.open(xray_dir .. "/context_char_limit.txt", "r")
    if context_file then
        local value = tonumber(context_file:read("*a"):match("^%s*(.-)%s*$"))
        context_file:close()
        if value and value >= 100 then
            self.settings.context_char_limit = math.min(5000, math.floor(value))
        end
    end
end

function AIHelper:saveRuntimeSetting(name, value)
    local xray_dir = self:ensureSettingsDir()
    local file = io.open(xray_dir .. "/" .. name .. ".txt", "w")
    if not file then return false end
    file:write(tostring(value))
    file:close()
    return true
end

function AIHelper:normalizeProviderId(id)
    id = self:trimText(id)
    if #id == 0 then return nil end
    id = id:gsub("%s+", "_"):gsub("[^%w_:%-]", "")
    if #id == 0 then return nil end
    return id
end

function AIHelper:getProvider(provider_id)
    provider_id = provider_id or self.default_provider or "gemini"
    if provider_id == "openai" then provider_id = "chatgpt" end
    local provider = self.providers[provider_id]
    if provider then return provider_id, provider end
    return nil, nil
end

function AIHelper:isOpenAICompatibleProvider(provider)
    return provider and (provider.type == "openai_compatible" or provider.endpoint)
end

-- Set Gemini model
function AIHelper:setGeminiModel(model_name)
    if not model_name or #model_name == 0 then return false end
    self.providers.gemini.model = model_name
    self:saveModelToConfig(model_name)
    return true
end

-- Set ChatGPT model
function AIHelper:setChatGPTModel(model_name)
    if not model_name or #model_name == 0 then return false end
    model_name = model_name:match("^%s*(.-)%s*$")
    if not model_name or #model_name == 0 then return false end
    self.providers.chatgpt.model = model_name
    self:saveModelToConfig(model_name, "chatgpt")
    return true
end

function AIHelper:setChatGPTThinking(mode)
    local enabled, normalized = self:normalizeThinkingMode(mode)
    self.providers.chatgpt.thinking_enabled = enabled
    return self:saveProviderSettingToFile("chatgpt", "thinking_enabled", normalized)
end

function AIHelper:setChatGPTReasoningEffort(effort)
    effort = self:normalizeReasoningEffort(effort)
    if not effort then return false end
    self.providers.chatgpt.reasoning_effort = effort
    return self:saveProviderSettingToFile("chatgpt", "reasoning_effort", effort)
end

-- Set default provider 
function AIHelper:setDefaultProvider(provider_name)
    provider_name = provider_name == "openai" and "chatgpt" or provider_name
    if not provider_name or not self.providers[provider_name] then
        return false
    end
    self.default_provider = provider_name
    self:saveProviderToConfig(provider_name)
    logger.info("AIHelper: Default provider changed to:", provider_name)
    return true
end

-- Save model preference to config file
function AIHelper:saveModelToConfig(model_name, provider)
    provider = provider or "gemini"
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local model_file = xray_dir .. "/" .. provider .. "_model.txt"
    local file = io.open(model_file, "w")
    if file then
        file:write(model_name)
        file:close()
        return true
    end
    return false
end

-- Save provider preference to config file 
function AIHelper:saveProviderToConfig(provider_name)
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local provider_file = xray_dir .. "/default_provider.txt"
    local file = io.open(provider_file, "w")
    if file then
        file:write(provider_name)
        file:close()
        logger.info("AIHelper: Saved default provider:", provider_name)
        return true
    end
    logger.warn("AIHelper: Failed to save provider preference")
    return false
end

-- Initialize AIHelper
function AIHelper:init()
    self:loadConfig()
    self:loadRuntimeSettingsFromFile()
    self:loadModelFromFile()
    self:loadLanguage()
    logger.info("AIHelper: Initialized with Gemini model:", self.providers.gemini.model)
    logger.info("AIHelper: ChatGPT model:", self.providers.chatgpt.model)
end

-- Load configuration
function AIHelper:loadConfig()
    local success, config = pcall(require, "config")
    if success and config then
        if config.gemini_api_key then self.providers.gemini.api_key = config.gemini_api_key end
        if config.gemini_model then self.providers.gemini.model = config.gemini_model end
        if config.chatgpt_api_key then self.providers.chatgpt.api_key = config.chatgpt_api_key end
        if config.chatgpt_model then self.providers.chatgpt.model = config.chatgpt_model end
        if config.chatgpt_endpoint then self.providers.chatgpt.endpoint = config.chatgpt_endpoint end
        if config.openai_compatible_name then self.providers.chatgpt.name = config.openai_compatible_name end
        if config.chatgpt_thinking_mode ~= nil then
            local enabled = self:normalizeThinkingMode(config.chatgpt_thinking_mode)
            self.providers.chatgpt.thinking_enabled = enabled
        elseif config.chatgpt_thinking_enabled ~= nil then
            local enabled = self:normalizeThinkingMode(config.chatgpt_thinking_enabled)
            self.providers.chatgpt.thinking_enabled = enabled
        end
        local reasoning_effort = self:normalizeReasoningEffort(config.chatgpt_reasoning_effort)
        if reasoning_effort then
            self.providers.chatgpt.reasoning_effort = reasoning_effort
        end
        if type(config.custom_providers) == "table" then
            for id, provider in pairs(config.custom_providers) do
                id = self:normalizeProviderId(id)
                if id and type(provider) == "table" then
                    provider.type = "openai_compatible"
                    provider.enabled = provider.enabled ~= false
                    provider.name = provider.name or id
                    provider.endpoint = self:normalizeChatCompletionsEndpoint(provider.endpoint)
                    provider.model = provider.model or "gpt-4o-mini"
                    provider.thinking_enabled = self:normalizeThinkingMode(provider.thinking_mode ~= nil and provider.thinking_mode or provider.thinking_enabled)
                    provider.thinking_mode = nil
                    self.providers[id] = provider
                end
            end
        end
        if config.default_provider then
            local provider = config.default_provider == "openai" and "chatgpt" or config.default_provider
            if self.providers[provider] then
                self.default_provider = provider
            end
        end
        if config.settings then self.settings = config.settings end
    end
end

-- Load model preference
function AIHelper:loadModelFromFile()
    local DataStorage = require("datastorage")
    self:loadCustomProvidersFromFile()
    
    -- Gemini model
    local gemini_file = DataStorage:getSettingsDir() .. "/xray/gemini_model.txt"
    local file = io.open(gemini_file, "r")
    if file then
        local model = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if model and #model > 0 then
            self.providers.gemini.model = model
        end
    end
    
    -- ChatGPT model
    local chatgpt_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_model.txt"
    file = io.open(chatgpt_file, "r")
    if file then
        local model = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if model and #model > 0 then
            self.providers.chatgpt.model = model
        end
    end

    -- ChatGPT endpoint (OpenAI-compatible)
    local chatgpt_endpoint_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_endpoint.txt"
    file = io.open(chatgpt_endpoint_file, "r")
    if file then
        local endpoint = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if endpoint and #endpoint > 0 then
            self.providers.chatgpt.endpoint = endpoint
            logger.info("AIHelper: Loaded ChatGPT endpoint from file")
        end
    end

    -- ChatGPT/OpenAI-compatible thinking toggle
    local chatgpt_thinking_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_thinking_enabled.txt"
    file = io.open(chatgpt_thinking_file, "r")
    if file then
        local value = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        self.providers.chatgpt.thinking_enabled = self:normalizeThinkingMode(value)
    end

    -- ChatGPT/OpenAI-compatible reasoning effort
    local chatgpt_effort_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_reasoning_effort.txt"
    file = io.open(chatgpt_effort_file, "r")
    if file then
        local effort = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        effort = self:normalizeReasoningEffort(effort)
        if effort then
            self.providers.chatgpt.reasoning_effort = effort
        end
    end
    
    -- Default provider (YENI)
    local provider_file = DataStorage:getSettingsDir() .. "/xray/default_provider.txt"
    file = io.open(provider_file, "r")
    if file then
        local provider = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if provider and self.providers[provider] then
            self.default_provider = provider
            logger.info("AIHelper: Loaded default provider from file:", provider)
        end
    end
        -- Gemini API Key
    local gemini_key_file = DataStorage:getSettingsDir() .. "/xray/gemini_api_key.txt"
    file = io.open(gemini_key_file, "r")
    if file then
        local key = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if key and #key > 0 then
            self.providers.gemini.api_key = key
            logger.info("AIHelper: Loaded Gemini API key from file")
        end
    end
    
    -- ChatGPT API Key
    local chatgpt_key_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_api_key.txt"
    file = io.open(chatgpt_key_file, "r")
    if file then
        local key = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if key and #key > 0 then
            self.providers.chatgpt.api_key = key
            logger.info("AIHelper: Loaded ChatGPT API key from file")
        end
    end
end


-- Save API Key preference to file
function AIHelper:saveAPIKeyToFile(provider, api_key)
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local key_file = xray_dir .. "/" .. provider .. "_api_key.txt"
    local file = io.open(key_file, "w")
    if file then
        file:write(api_key)
        file:close()
        logger.info("AIHelper: Saved", provider, "API key to file")
        return true
    end
    logger.warn("AIHelper: Failed to save", provider, "API key")
    return false
end

function AIHelper:saveProviderSettingToFile(provider, setting_name, value)
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)

    local setting_file = xray_dir .. "/" .. provider .. "_" .. setting_name .. ".txt"
    local file = io.open(setting_file, "w")
    if file then
        file:write(value)
        file:close()
        logger.info("AIHelper: Saved", provider, setting_name, "to file")
        return true
    end
    logger.warn("AIHelper: Failed to save", provider, setting_name)
    return false
end

function AIHelper:normalizeChatCompletionsEndpoint(endpoint)
    if type(endpoint) ~= "string" then return nil end
    endpoint = endpoint:match("^%s*(.-)%s*$")
    if not endpoint or #endpoint == 0 then return nil end
    endpoint = endpoint:gsub("/+$", "")
    if not endpoint:match("/chat/completions$") then
        endpoint = endpoint .. "/chat/completions"
    end
    return endpoint
end

function AIHelper:setChatGPTEndpoint(endpoint)
    endpoint = self:normalizeChatCompletionsEndpoint(endpoint)
    if not endpoint then return false end
    self.providers.chatgpt.endpoint = endpoint
    self:saveProviderSettingToFile("chatgpt", "endpoint", endpoint)
    return true
end

function AIHelper:getCustomProvidersPath()
    return self:ensureSettingsDir() .. "/custom_providers.json"
end

function AIHelper:loadCustomProvidersFromFile()
    local path = self:getCustomProvidersPath()
    local file = io.open(path, "r")
    if not file then return false end
    local text = file:read("*a")
    file:close()
    local ok, providers = pcall(json.decode, text)
    if not ok or type(providers) ~= "table" then
        logger.warn("AIHelper: Failed to parse custom providers")
        return false
    end

    for id, provider in pairs(providers) do
        id = self:normalizeProviderId(id)
        if id and type(provider) == "table" then
            provider.type = "openai_compatible"
            provider.enabled = provider.enabled ~= false
            provider.name = provider.name or id
            provider.endpoint = self:normalizeChatCompletionsEndpoint(provider.endpoint)
            provider.model = provider.model or "gpt-4o-mini"
            provider.thinking_enabled = self:normalizeThinkingMode(provider.thinking_mode ~= nil and provider.thinking_mode or provider.thinking_enabled)
            provider.thinking_mode = nil
            self.providers[id] = provider
        end
    end
    return true
end

function AIHelper:saveCustomProvidersToFile()
    local custom = {}
    for id, provider in pairs(self.providers) do
        if id:match("^custom:") and self:isOpenAICompatibleProvider(provider) then
            custom[id] = {
                name = provider.name,
                type = "openai_compatible",
                enabled = provider.enabled ~= false,
                api_key = provider.api_key,
                endpoint = provider.endpoint,
                model = provider.model,
                thinking_mode = self:getThinkingMode(provider),
                thinking_enabled = provider.thinking_enabled,
                reasoning_effort = provider.reasoning_effort,
            }
        end
    end

    local file = io.open(self:getCustomProvidersPath(), "w")
    if not file then return false end
    file:write(json.encode(custom))
    file:close()
    return true
end

function AIHelper:createCustomProvider(provider)
    provider = provider or {}
    local name = self:trimText(provider.name)
    if #name == 0 then name = "Custom Provider" end
    local id = self:normalizeProviderId(provider.id or ("custom:" .. name:lower()))
    if not id then return nil end
    if not id:match("^custom:") then id = "custom:" .. id end

    local suffix = 1
    local base_id = id
    while self.providers[id] do
        suffix = suffix + 1
        id = base_id .. "_" .. tostring(suffix)
    end

    local thinking_enabled = self:normalizeThinkingMode(provider.thinking_mode ~= nil and provider.thinking_mode or provider.thinking_enabled)
    self.providers[id] = {
        name = name,
        type = "openai_compatible",
        enabled = true,
        api_key = self:trimText(provider.api_key),
        endpoint = self:normalizeChatCompletionsEndpoint(provider.endpoint),
        model = self:trimText(provider.model) ~= "" and self:trimText(provider.model) or "gpt-4o-mini",
        thinking_enabled = thinking_enabled,
        reasoning_effort = self:normalizeReasoningEffort(provider.reasoning_effort) or "high",
    }
    self:saveCustomProvidersToFile()
    return id
end

function AIHelper:updateCustomProvider(id, updates)
    id = self:normalizeProviderId(id)
    local provider = id and self.providers[id]
    if not provider or not id:match("^custom:") then return false end
    updates = updates or {}
    if updates.name ~= nil then provider.name = self:trimText(updates.name) end
    if updates.api_key ~= nil then provider.api_key = self:trimText(updates.api_key) end
    if updates.endpoint ~= nil then provider.endpoint = self:normalizeChatCompletionsEndpoint(updates.endpoint) end
    if updates.model ~= nil then provider.model = self:trimText(updates.model) end
    if updates.thinking_mode ~= nil then
        provider.thinking_enabled = self:normalizeThinkingMode(updates.thinking_mode)
    elseif updates.thinking_enabled ~= nil then
        provider.thinking_enabled = self:normalizeThinkingMode(updates.thinking_enabled)
    end
    if updates.reasoning_effort ~= nil then
        provider.reasoning_effort = self:normalizeReasoningEffort(updates.reasoning_effort) or provider.reasoning_effort
    end
    provider.type = "openai_compatible"
    return self:saveCustomProvidersToFile()
end

function AIHelper:deleteCustomProvider(id)
    id = self:normalizeProviderId(id)
    if not id or not id:match("^custom:") or not self.providers[id] then return false end
    self.providers[id] = nil
    if self.default_provider == id then
        self:setDefaultProvider("chatgpt")
    end
    return self:saveCustomProvidersToFile()
end

function AIHelper:isLocalEndpoint(url)
    return url:match("^https?://localhost[:/]")
        or url:match("^https?://127%.")
        or url:match("^https?://10%.")
        or url:match("^https?://192%.168%.")
        or url:match("^https?://172%.1[6-9]%.")
        or url:match("^https?://172%.2[0-9]%.")
        or url:match("^https?://172%.3[0-1]%.")
end

function AIHelper:parseURL(url)
    local scheme, rest = url:match("^(https?)://(.+)$")
    if not scheme then return nil end

    local authority, path = rest:match("^([^/]*)(/.*)$")
    if not authority then
        authority = rest
        path = "/"
    end

    local host, port = authority:match("^%[([^%]]+)%]:(%d+)$")
    if not host then
        host, port = authority:match("^([^:]+):(%d+)$")
    end
    if not host then
        host = authority
    end

    return {
        scheme = scheme,
        host = host,
        port = tonumber(port) or (scheme == "https" and 443 or 80),
        path = path,
    }
end

function AIHelper:parseProxyURL(proxy)
    if type(proxy) ~= "string" or #proxy == 0 then return nil end
    proxy = proxy:gsub("^%s+", ""):gsub("%s+$", "")
    proxy = proxy:gsub("^https?://", "")
    proxy = proxy:gsub("/.*$", "")

    local auth = proxy:match("^(.-)@")
    if auth then
        proxy = proxy:gsub("^.-@", "")
    end

    local host, port = proxy:match("^%[([^%]]+)%]:(%d+)$")
    if not host then
        host, port = proxy:match("^([^:]+):(%d+)$")
    end
    if not host or not port then return nil end

    return {
        host = host,
        port = tonumber(port),
        auth = auth,
    }
end

function AIHelper:base64Encode(input)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    local padding = ({ "", "==", "=" })[(#input % 3) + 1]

    input = input .. string.rep("\0", (3 - #input % 3) % 3)
    for i = 1, #input, 3 do
        local b1, b2, b3 = input:byte(i, i + 2)
        local n = b1 * 65536 + b2 * 256 + b3
        table.insert(result, chars:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1))
        table.insert(result, chars:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        table.insert(result, chars:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
        table.insert(result, chars:sub(n % 64 + 1, n % 64 + 1))
    end

    local encoded = table.concat(result)
    if #padding > 0 then
        encoded = encoded:sub(1, -#padding - 1) .. padding
    end
    return encoded
end

function AIHelper:getProxyForURL(url)
    if self:isLocalEndpoint(url) then
        return nil
    end

    return https.PROXY or http.PROXY
end

function AIHelper:isRetryableSocketError(err)
    return err == "wantread" or err == "wantwrite" or err == "timeout"
end

function AIHelper:retrySocketOperation(operation, timeout)
    timeout = timeout or 120
    local started = socket.gettime and socket.gettime() or os.time()

    while true do
        local ok, result, err, partial = pcall(operation)
        if not ok then
            return nil, tostring(result)
        end
        if result then
            return result, err, partial
        end
        if not self:isRetryableSocketError(err) then
            return nil, err, partial
        end

        local now = socket.gettime and socket.gettime() or os.time()
        if now - started >= timeout then
            return nil, err, partial
        end
        socket.sleep(0.05)
    end
end

function AIHelper:receiveLine(sock)
    local parts = {}
    while true do
        local line, err, partial = self:retrySocketOperation(function()
            return sock:receive("*l")
        end)
        if line then
            if #parts > 0 then
                return table.concat(parts) .. line
            end
            return line
        end
        if partial and #partial > 0 then
            table.insert(parts, partial)
        end
        if #parts > 0 then
            return table.concat(parts)
        end
        return nil, err
    end
end

function AIHelper:receiveBytes(sock, size)
    local parts = {}
    local remaining = size

    while remaining > 0 do
        local data, err, partial = self:retrySocketOperation(function()
            return sock:receive(remaining)
        end)
        if data then
            table.insert(parts, data)
            break
        end
        if partial and #partial > 0 then
            table.insert(parts, partial)
            remaining = remaining - #partial
        end
        if err then
            break
        end
    end

    return table.concat(parts)
end

function AIHelper:sendAll(sock, data)
    local index = 1
    while index <= #data do
        local sent, err, last = self:retrySocketOperation(function()
            return sock:send(data, index)
        end)
        if sent then
            index = sent + 1
        elseif last and last >= index then
            index = last + 1
        else
            return nil, err
        end
    end
    return true
end

function AIHelper:receiveHeaders(sock)
    local status_line, err = self:receiveLine(sock)
    if not status_line then
        return nil, nil, err or "missing response status"
    end

    local headers = {}
    while true do
        local line
        line, err = self:receiveLine(sock)
        if not line then
            return status_line, headers, err or "failed to read response headers"
        end
        if line == "" then break end

        local key, value = line:match("^([^:]+):%s*(.*)$")
        if key then
            headers[key:lower()] = value
        end
    end

    return status_line, headers
end

function AIHelper:readResponseBody(sock, headers)
    local transfer_encoding = headers["transfer-encoding"]
    if transfer_encoding and transfer_encoding:lower():find("chunked", 1, true) then
        local chunks = {}
        while true do
            local size_line = self:receiveLine(sock)
            if not size_line then break end
            local size = tonumber(size_line:match("^%s*([%da-fA-F]+)"), 16)
            if not size or size == 0 then
                while true do
                    local trailer = self:receiveLine(sock)
                    if not trailer or trailer == "" then break end
                end
                break
            end
            local chunk = self:receiveBytes(sock, size)
            if chunk then
                table.insert(chunks, chunk)
            end
            self:receiveBytes(sock, 2)
        end
        return table.concat(chunks)
    end

    local content_length = tonumber(headers["content-length"])
    if content_length then
        local body = self:receiveBytes(sock, content_length)
        return body or ""
    end

    local chunks = {}
    while true do
        local chunk, err, partial = self:retrySocketOperation(function()
            return sock:receive(1024)
        end)
        if chunk and #chunk > 0 then
            table.insert(chunks, chunk)
        elseif partial and #partial > 0 then
            table.insert(chunks, partial)
        elseif self:isRetryableSocketError(err) then
            -- retrySocketOperation already waited until timeout for retryable errors.
            break
        else
            break
        end
    end
    return table.concat(chunks)
end

function AIHelper:requestHTTPSViaProxy(url, request_body, api_key, proxy_url)
    local target = self:parseURL(url)
    local proxy = self:parseProxyURL(proxy_url)
    if not target then
        return nil, nil, nil, "Invalid HTTPS URL: " .. tostring(url), ""
    end
    if not proxy then
        return nil, nil, nil, "Invalid proxy URL: " .. tostring(proxy_url), ""
    end

    local tcp = socket.tcp()
    tcp:settimeout(120)
    local ok, err = tcp:connect(proxy.host, proxy.port)
    if not ok then
        return nil, nil, nil, "Proxy connect failed: " .. tostring(err), ""
    end

    local connect_host = target.host .. ":" .. tostring(target.port)
    local connect_request = "CONNECT " .. connect_host .. " HTTP/1.1\r\n" ..
        "Host: " .. connect_host .. "\r\n" ..
        "Proxy-Connection: Keep-Alive\r\n"
    if proxy.auth then
        connect_request = connect_request ..
            "Proxy-Authorization: Basic " .. self:base64Encode(proxy.auth) .. "\r\n"
    end
    ok, err = self:sendAll(tcp, connect_request .. "\r\n")
    if not ok then
        tcp:close()
        return nil, nil, nil, "Proxy CONNECT send failed: " .. tostring(err), ""
    end

    local connect_status, _, header_err = self:receiveHeaders(tcp)
    local connect_code = connect_status and tonumber(connect_status:match("^HTTP/%S+%s+(%d+)"))
    if connect_code ~= 200 then
        tcp:close()
        return nil, connect_code, nil, "Proxy CONNECT failed: " .. tostring(connect_status or header_err), ""
    end

    local params = {
        mode = "client",
        protocol = "tlsv1_2",
        verify = "none",
        options = "all",
    }
    if target.host then
        params.server = target.host
    end

    local tls_sock
    tls_sock, err = ssl.wrap(tcp, params)
    if not tls_sock then
        tcp:close()
        return nil, nil, nil, "TLS wrap failed: " .. tostring(err), ""
    end
    tls_sock:settimeout(120)

    ok, err = self:retrySocketOperation(function()
        return tls_sock:dohandshake()
    end)
    if not ok then
        tls_sock:close()
        return nil, nil, nil, "TLS handshake failed: " .. tostring(err), ""
    end

    local request = "POST " .. target.path .. " HTTP/1.1\r\n" ..
        "Host: " .. target.host .. "\r\n" ..
        "Content-Type: application/json\r\n" ..
        "Authorization: Bearer " .. api_key .. "\r\n" ..
        "Content-Length: " .. tostring(#request_body) .. "\r\n" ..
        "Connection: close\r\n\r\n" ..
        request_body

    ok, err = self:sendAll(tls_sock, request)
    if not ok then
        tls_sock:close()
        return nil, nil, nil, "HTTPS request send failed: " .. tostring(err), ""
    end

    local status_line, headers
    status_line, headers, err = self:receiveHeaders(tls_sock)
    if not status_line then
        tls_sock:close()
        return nil, nil, nil, "HTTPS response failed: " .. tostring(err), ""
    end

    local body = self:readResponseBody(tls_sock, headers)
    tls_sock:close()

    local code = tonumber(status_line:match("^HTTP/%S+%s+(%d+)"))
    return 1, code, headers, status_line, body
end

function AIHelper:requestChatCompletions(url, request_body, api_key)
    local request = {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. api_key,
            ["Content-Length"] = tostring(#request_body),
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table({}),
        timeout = 120
    }
    local response_body = {}
    request.sink = ltn12.sink.table(response_body)

    local client
    local proxy = self:getProxyForURL(url)
    if url:match("^http://") then
        client = http
        if self:isLocalEndpoint(url) then
            request.proxy = false
        elseif proxy then
            request.proxy = proxy
            local proxy_info = self:parseProxyURL(proxy)
            if proxy_info and proxy_info.auth then
                request.headers["Proxy-Authorization"] = "Basic " .. self:base64Encode(proxy_info.auth)
            end
        end
    elseif url:match("^https://") then
        if proxy then
            return self:requestHTTPSViaProxy(url, request_body, api_key, proxy)
        end
        client = https
    else
        return nil, nil, nil, "Unsupported endpoint scheme: " .. tostring(url), ""
    end

    local previous_proxy
    if client == http then
        previous_proxy = http.PROXY
        if self:isLocalEndpoint(url) then
            http.PROXY = nil
        end
    elseif client == https then
        previous_proxy = https.PROXY
        https.PROXY = nil
    end

    local ok, res, code, headers, status = pcall(client.request, request)

    if client == http then
        http.PROXY = previous_proxy
    elseif client == https then
        https.PROXY = previous_proxy
    end

    local response_text = table.concat(response_body)
    if not ok then
        local err = tostring(res)
        if err:match("proxy not supported") then
            err = err .. " (disable KOReader/system proxy for HTTPS OpenAI-compatible endpoints)"
        end
        return nil, nil, nil, err, response_text
    end

    return res, code, headers, status, response_text
end

function AIHelper:getAPIErrorMessage(response_text)
    if type(response_text) ~= "string" or #response_text == 0 then
        return nil
    end

    local success, data = pcall(json.decode, response_text)
    if success and data then
        if type(data.error) == "table" and data.error.message then
            return data.error.message
        elseif type(data.error) == "string" then
            return data.error
        elseif data.message then
            return data.message
        end
    end

    return response_text:sub(1, 500)
end

function AIHelper:addOpenAICompatibilityParams(request_data, config)
    if config.thinking_enabled ~= nil then
        request_data.thinking = {
            type = config.thinking_enabled and "enabled" or "disabled"
        }
        if config.thinking_enabled then
            request_data.reasoning_effort = config.reasoning_effort or "high"
        end
    end
end

function AIHelper:stripOpenAICompatibilityParams(request_data)
    request_data.thinking = nil
    request_data.reasoning_effort = nil
    request_data.response_format = nil
end

function AIHelper:shouldRetryWithoutCompatibilityParams(code_num, response_text, request_data)
    if code_num ~= 400 and code_num ~= 422 then return false end
    if not request_data.thinking and not request_data.reasoning_effort and not request_data.response_format then
        return false
    end
    local detail = self:getAPIErrorMessage(response_text) or ""
    detail = detail:lower()
    return detail:match("parsing the body")
        or detail:match("parse the body")
        or detail:match("invalid.*body")
        or detail:match("unknown.*field")
        or detail:match("unsupported.*field")
        or detail:match("response_format")
        or detail:match("thinking")
        or detail:match("reasoning")
end

function AIHelper:sanitizeJSONText(text)
    if type(text) ~= "string" then return "" end
    local out = {}
    local i = 1
    local len = #text

    local function is_continuation(byte)
        return byte and byte >= 0x80 and byte <= 0xBF
    end

    while i <= len do
        local b1 = text:byte(i)
        if not b1 then
            break
        elseif b1 < 0x80 then
            if b1 == 0x09 or b1 == 0x0A or b1 == 0x0D or b1 >= 0x20 then
                table.insert(out, string.char(b1))
            else
                table.insert(out, " ")
            end
            i = i + 1
        elseif b1 >= 0xC2 and b1 <= 0xDF and is_continuation(text:byte(i + 1)) then
            table.insert(out, text:sub(i, i + 1))
            i = i + 2
        elseif b1 == 0xE0 and text:byte(i + 1) and text:byte(i + 1) >= 0xA0 and text:byte(i + 1) <= 0xBF and is_continuation(text:byte(i + 2)) then
            table.insert(out, text:sub(i, i + 2))
            i = i + 3
        elseif b1 >= 0xE1 and b1 <= 0xEC and is_continuation(text:byte(i + 1)) and is_continuation(text:byte(i + 2)) then
            table.insert(out, text:sub(i, i + 2))
            i = i + 3
        elseif b1 == 0xED and text:byte(i + 1) and text:byte(i + 1) >= 0x80 and text:byte(i + 1) <= 0x9F and is_continuation(text:byte(i + 2)) then
            table.insert(out, text:sub(i, i + 2))
            i = i + 3
        elseif b1 >= 0xEE and b1 <= 0xEF and is_continuation(text:byte(i + 1)) and is_continuation(text:byte(i + 2)) then
            table.insert(out, text:sub(i, i + 2))
            i = i + 3
        elseif b1 == 0xF0 and text:byte(i + 1) and text:byte(i + 1) >= 0x90 and text:byte(i + 1) <= 0xBF and is_continuation(text:byte(i + 2)) and is_continuation(text:byte(i + 3)) then
            table.insert(out, text:sub(i, i + 3))
            i = i + 4
        elseif b1 >= 0xF1 and b1 <= 0xF3 and is_continuation(text:byte(i + 1)) and is_continuation(text:byte(i + 2)) and is_continuation(text:byte(i + 3)) then
            table.insert(out, text:sub(i, i + 3))
            i = i + 4
        elseif b1 == 0xF4 and text:byte(i + 1) and text:byte(i + 1) >= 0x80 and text:byte(i + 1) <= 0x8F and is_continuation(text:byte(i + 2)) and is_continuation(text:byte(i + 3)) then
            table.insert(out, text:sub(i, i + 3))
            i = i + 4
        else
            table.insert(out, " ")
            i = i + 1
        end
    end

    return table.concat(out)
end

function AIHelper:sanitizeChatMessages(request_data)
    if not request_data or type(request_data.messages) ~= "table" then return end
    for _, message in ipairs(request_data.messages) do
        if type(message) == "table" and type(message.content) == "string" then
            message.content = self:sanitizeJSONText(message.content)
        end
    end
end

-- Get book data from AI
function AIHelper:getBookData(title, author, provider_name, context)
    self:loadModelFromFile() -- Refresh model
    local provider, provider_config = self:getProvider(provider_name or "gemini")

    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        return nil, "error_no_api_key"
    end
    
    -- Context ile prompt oluştur
    local prompt = self:createPrompt(title, author, context)
    
    logger.info("AIHelper: Using provider:", provider, "Model:", provider_config.model)
    if context and context.spoiler_free then
        logger.info("AIHelper: Spoiler-free mode active, reading:", context.reading_percent, "%")
    end
    
    if provider_config.type == "gemini" or provider == "gemini" then
        return self:callGemini(prompt, provider_config)
    elseif self:isOpenAICompatibleProvider(provider_config) then
        return self:callChatGPT(prompt, provider_config)
    end
    return nil, "error_unknown_provider"
end

function AIHelper:createQuestionPrompt(question, context)
    context = context or {}
    local title = self:trimText(context.title)
    local author = self:trimText(context.author)
    local summary = self:trimText(context.summary)
    local selected_text = self:trimText(context.selected_text)
    local language = self:trimText(context.language)

    local parts = {
        "You are an AI reading assistant inside KOReader.",
        "Answer the user's question clearly and concisely. Use only the book information and selected text as context when they are provided. Do not invent facts about later parts of the book, and avoid spoilers beyond the provided context.",
    }

    if #language > 0 then
        table.insert(parts, "Answer in this interface language when possible: " .. language)
    end

    if #title > 0 or #author > 0 then
        table.insert(parts, "Book: " .. (#title > 0 and title or "Unknown") .. "\nAuthor: " .. (#author > 0 and author or "Unknown"))
    end

    if #summary > 0 then
        table.insert(parts, "Existing X-Ray summary:\n" .. summary)
    end

    if #selected_text > 0 then
        table.insert(parts, "Selected text:\n\"\"\"\n" .. selected_text .. "\n\"\"\"")
    end

    table.insert(parts, "User question:\n" .. self:trimText(question))
    return table.concat(parts, "\n\n")
end

function AIHelper:askQuestion(question, provider_name, context)
    self:loadModelFromFile()
    self:loadLanguage()

    local provider, provider_config = self:getProvider(provider_name or self.default_provider or "gemini")

    if not provider_config or not provider_config.api_key or #provider_config.api_key == 0 then
        return nil, "error_no_api_key"
    end

    local prompt = self:createQuestionPrompt(question, context)
    logger.info("AIHelper: Asking question with provider:", provider, "Model:", provider_config.model)

    if provider_config.type == "gemini" or provider == "gemini" then
        return self:callGeminiQuestion(prompt, provider_config)
    elseif self:isOpenAICompatibleProvider(provider_config) then
        return self:callChatGPTQuestion(prompt, provider_config)
    end

    return nil, "error_unknown_provider"
end

function AIHelper:callGeminiQuestion(prompt, config)
    logger.info("AIHelper: Calling Google Gemini API for Q&A")

    if not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "İnternet bağlantısı yok"
    end

    local model = config.model or "gemini-3.1-flash-lite"
    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. config.api_key
    local safety_settings = {
        { category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_NONE" }
    }

    local request_body = json.encode({
        contents = {{ parts = {{ text = prompt }} }},
        safetySettings = safety_settings,
        generationConfig = {
            temperature = 0.4,
            topK = 40,
            topP = 0.95,
            maxOutputTokens = 4096,
        }
    })

    local max_retries = 1
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
            socket.sleep(3)
        end

        local response_body = {}
        local res, code, headers, status = https.request{
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request_body),
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 120
        }

        local response_text = table.concat(response_body)
        local code_num = tonumber(code)
        logger.info("AIHelper: Gemini Q&A API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then return nil, "error_json_parse" end

            if data and data.candidates and data.candidates[1] then
                local candidate = data.candidates[1]
                if candidate.finishReason == "SAFETY" then
                    return nil, "error_safety", "Google Güvenlik Filtresi engelledi."
                end
                if candidate.content and candidate.content.parts then
                    local answer_parts = {}
                    for _, part in ipairs(candidate.content.parts) do
                        if part.text then
                            table.insert(answer_parts, part.text)
                        end
                    end
                    local answer = self:trimText(table.concat(answer_parts, "\n"))
                    if #answer > 0 then
                        return answer
                    end
                end
                return nil, "error_api", "API boş yanıt döndürdü."
            end
            return nil, "error_api", "Geçersiz yanıt formatı"
        elseif code_num == 503 then
            logger.warn("AIHelper: Gemini Q&A 503 Service Unavailable (Retrying...)")
        elseif not code_num then
            local detail = status or code or res or "unknown transport error"
            return nil, "error_network", "Request failed: " .. tostring(detail)
        else
            local detail = self:getAPIErrorMessage(response_text)
            return nil, "error_" .. tostring(code_num), "HTTP " .. tostring(code_num) .. (detail and (": " .. detail) or "")
        end
    end

    return nil, "error_timeout", "Zaman aşımı"
end

function AIHelper:callChatGPTQuestion(prompt, config)
    logger.info("AIHelper: Calling ChatGPT API for Q&A")

    local model = config.model or "gpt-4o-mini"
    local url = self:normalizeChatCompletionsEndpoint(config.endpoint) or "https://api.openai.com/v1/chat/completions"

    if not self:isLocalEndpoint(url) and not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "İnternet bağlantısı yok"
    end

    local request_data = {
        model = model,
        messages = {
            {
                role = "system",
                content = "You are a helpful literary reading assistant. Answer in plain text, not JSON or Markdown unless the user explicitly asks for formatting."
            },
            {
                role = "user",
                content = prompt
            }
        },
        temperature = 0.4,
        max_tokens = 4096,
        top_p = 0.95,
    }

    self:sanitizeChatMessages(request_data)
    self:addOpenAICompatibilityParams(request_data, config)

    local request_body = json.encode(request_data)
    logger.info("AIHelper: ChatGPT Q&A endpoint:", url)
    logger.info("AIHelper: ChatGPT Q&A model:", model)
    logger.info("AIHelper: ChatGPT Q&A request size:", #request_body)

    local max_retries = 1
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
            socket.sleep(3)
            logger.info("AIHelper: Retrying ChatGPT Q&A request (attempt " .. attempt .. ")")
        end

        local res, code, headers, status, response_text = self:requestChatCompletions(url, request_body, config.api_key)
        response_text = response_text or ""
        local code_num = tonumber(code)
        logger.info("AIHelper: ChatGPT Q&A API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then return nil, "error_json_parse" end

            if data and data.choices and data.choices[1] then
                local choice = data.choices[1]
                if choice.finish_reason == "content_filter" then
                    return nil, "error_safety", "OpenAI içerik filtresi engelledi."
                end
                if choice.message and choice.message.content then
                    local answer = self:trimText(choice.message.content)
                    if #answer > 0 then
                        return answer
                    end
                end
                return nil, "error_api", "API boş yanıt döndürdü."
            end
            if data and data.error then
                return nil, "error_api", data.error.message or "API Hatası"
            end
            return nil, "error_api", "Geçersiz yanıt formatı"
        elseif code_num == 429 then
            logger.warn("AIHelper: ChatGPT Q&A 429 Rate Limit (Retrying...)")
            if attempt <= max_retries then
                socket.sleep(5)
            end
        elseif code_num == 503 or code_num == 502 then
            logger.warn("AIHelper: ChatGPT Q&A " .. code_num .. " Service Error (Retrying...)")
        elseif code_num == 401 then
            return nil, "error_401", self:getAPIErrorMessage(response_text) or "API anahtarı geçersiz"
        elseif not code_num then
            local detail = status or code or res or "unknown transport error"
            return nil, "error_network", "Request failed: " .. tostring(detail)
        else
            if self:shouldRetryWithoutCompatibilityParams(code_num, response_text, request_data) and attempt <= max_retries then
                logger.warn("AIHelper: ChatGPT Q&A body parse error; retrying without thinking/response_format compatibility params")
                self:stripOpenAICompatibilityParams(request_data)
                request_body = json.encode(request_data)
            else
                local detail = self:getAPIErrorMessage(response_text)
                local context = "\nURL: " .. tostring(url) .. "\nModel: " .. tostring(model)
                return nil, "error_" .. tostring(code_num), "HTTP " .. tostring(code_num) .. (detail and (": " .. detail) or "") .. context
            end
        end
    end

    return nil, "error_timeout", "Zaman aşımı"
end

-- Check network
function AIHelper:checkNetworkConnectivity()
    local socket = require("socket")
    local success, err = pcall(function()
        local tcp = socket.tcp()
        tcp:settimeout(3)
        local result = tcp:connect("8.8.8.8", 53)
        tcp:close()
        return result
    end)
    return success
end

-- Load language
function AIHelper:loadLanguage()
    local DataStorage = require("datastorage")
    local f = io.open(DataStorage:getSettingsDir() .. "/xray/language.txt", "r")
    self.current_language = f and f:read("*a"):match("^%s*(.-)%s*$") or "tr"
    if f then f:close() end
    self:loadPrompts()
end

-- Load prompts
function AIHelper:loadPrompts()
    local success, prompts = pcall(require, "prompts/" .. self.current_language)
    if not success then 
        success, prompts = pcall(require, "prompts/tr") 
    end
    self.prompts = prompts or {}
end

-- Create prompt
function AIHelper:createPrompt(title, author, context)
    if not self.prompts then self:loadLanguage() end
    context = context or {}

    -- Context varsa ve spoiler_free modundaysa özel prompt kullan
    local prompt
    if context and context.spoiler_free then
        local template = self.prompts.spoiler_free or self.prompts.main
        -- Artık sadece 3 parametre: title, author, percent
        prompt = string.format(template, title, author or "Bilinmiyor", context.reading_percent)
    else
        -- Tam kitap için normal prompt
        local template = self.prompts.main
        prompt = string.format(template, title, author or "Bilinmiyor")
    end

    local additions = {}
    if context.source_mode then
        table.insert(additions, "X-Ray analysis source mode: " .. tostring(context.source_mode))
    end
    if context.source_stats then
        table.insert(additions, "Local text extraction stats: " .. self:formatSimpleTable(context.source_stats))
    end
    if type(context.existing_data) == "table" then
        table.insert(additions, "Existing cached X-Ray data. Improve and complete it with any new local book context; keep useful existing facts unless the new context disproves them:")
        table.insert(additions, self:formatExistingXRay(context.existing_data))
    end
    if context.source_mode == "local_candidates" and type(context.character_candidates) == "table" then
        table.insert(additions, "Local scan found these possible character names. Use them as candidates, merge aliases, and discard false positives. Keep the final JSON schema unchanged.")
        table.insert(additions, self:formatCandidates(context.character_candidates))
        if type(context.chapter_summaries) == "table" and #context.chapter_summaries > 0 then
            table.insert(additions, "Short excerpts from the locally extracted book text. Use them only to improve character coverage and avoid false positives:")
            table.insert(additions, self:formatChunkSummaries(context.chapter_summaries))
        end
    elseif context.source_mode == "nearby_context" then
        table.insert(additions, "The following excerpt is near the user's current reading position. Use it to complete or correct character entries, aliases, roles, and relationships. Keep existing X-Ray data when it is still useful, and do not invent plot beyond this excerpt.")
        if context.nearby_context_stats then
            table.insert(additions, "Nearby context stats: " .. self:formatSimpleTable(context.nearby_context_stats))
        end
        if type(context.character_candidates) == "table" and #context.character_candidates > 0 then
            table.insert(additions, "Possible local character names from this excerpt:")
            table.insert(additions, self:formatCandidates(context.character_candidates))
        end
        if context.nearby_text and #tostring(context.nearby_text) > 0 then
            table.insert(additions, "Nearby reading context:\n\"\"\"\n" .. tostring(context.nearby_text):sub(1, 6000) .. "\n\"\"\"")
        end
    elseif context.source_mode == "chunked_fulltext" then
        if type(context.character_candidates) == "table" then
            table.insert(additions, "Local scan candidate names:")
            table.insert(additions, self:formatCandidates(context.character_candidates))
        end
        if type(context.chapter_summaries) == "table" then
            table.insert(additions, "Chunk summaries from the book text. Build the final X-Ray JSON from these summaries without inventing later content:")
            table.insert(additions, self:formatChunkSummaries(context.chapter_summaries))
        end
    elseif context.source_mode == "text_chunk" then
        table.insert(additions, "Analyze only this book chunk. Return the same JSON schema, but include only characters, places, events, and themes visible in this chunk.")
        if context.chunk_title then
            table.insert(additions, "Chunk: " .. tostring(context.chunk_title))
        end
        if context.book_text then
            table.insert(additions, "Book chunk text:\n\"\"\"\n" .. tostring(context.book_text):sub(1, 18000) .. "\n\"\"\"")
        end
    end

    if #additions > 0 then
        prompt = prompt .. "\n\nAdditional book context:\n" .. table.concat(additions, "\n\n")
    end

    return prompt
end

function AIHelper:formatSimpleTable(value)
    if type(value) ~= "table" then return tostring(value or "") end
    local parts = {}
    for k, v in pairs(value) do
        if type(v) ~= "table" then
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

function AIHelper:formatExistingXRay(data)
    local lines = {}
    if data.summary and #tostring(data.summary) > 0 then
        table.insert(lines, "Summary: " .. tostring(data.summary):sub(1, 1200))
    end
    if type(data.characters) == "table" and #data.characters > 0 then
        table.insert(lines, "Existing characters:")
        for i, c in ipairs(data.characters) do
            if i > 40 then break end
            local line = "- " .. tostring(c.name or "")
            if c.role and #tostring(c.role) > 0 then line = line .. " | " .. tostring(c.role) end
            if c.description and #tostring(c.description) > 0 then
                line = line .. " | " .. tostring(c.description):sub(1, 180)
            end
            table.insert(lines, line)
        end
    end
    if type(data.locations) == "table" and #data.locations > 0 then
        local names = {}
        for i, loc in ipairs(data.locations) do
            if i > 20 then break end
            table.insert(names, tostring(loc.name or loc))
        end
        table.insert(lines, "Existing locations: " .. table.concat(names, ", "))
    end
    if type(data.themes) == "table" and #data.themes > 0 then
        local themes = {}
        for i, theme in ipairs(data.themes) do
            if i > 20 then break end
            table.insert(themes, tostring(theme))
        end
        table.insert(lines, "Existing themes: " .. table.concat(themes, ", "))
    end
    return table.concat(lines, "\n")
end

function AIHelper:formatCandidates(candidates)
    local lines = {}
    for i, c in ipairs(candidates or {}) do
        if i > 40 then break end
        local line = string.format("%d. %s (count: %s, first_seen: %s)", i, tostring(c.name or ""), tostring(c.count or 0), tostring(c.first_seen or 0))
        if c.contexts and c.contexts[1] then
            line = line .. "\n   context: " .. tostring(c.contexts[1])
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

function AIHelper:formatChunkSummaries(summaries)
    local lines = {}
    for i, s in ipairs(summaries or {}) do
        if i > 80 then break end
        local text = s.summary or s.excerpt or ""
        if #text > 900 then text = text:sub(1, 900) end
        local line = string.format("%d. %s\n%s", i, tostring(s.title or ("Chunk " .. i)), tostring(text))
        if type(s.characters) == "table" and #s.characters > 0 then
            local names = {}
            for j, c in ipairs(s.characters) do
                if j > 20 then break end
                table.insert(names, tostring(c.name or c))
            end
            line = line .. "\nCharacters: " .. table.concat(names, ", ")
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n\n")
end

function AIHelper:getFallbackStrings()
    if not self.prompts then self:loadPrompts() end
    return self.prompts.fallback or {}
end

-- Call Google Gemini API (FIXED VERSION)
function AIHelper:callGemini(prompt, config)
    logger.info("AIHelper: Calling Google Gemini API")
    
    if not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "İnternet bağlantısı yok"
    end
    
    local model = config.model or "gemini-3.1-flash-lite"
    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. config.api_key
    
    -- GÜVENLİK FİLTRELERİNİ KAPAT (Dostoyevski vb. için şart)
    local safety_settings = {
        { category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_NONE" }
    }

    local request_body = json.encode({
        contents = {{ parts = {{ text = prompt }} }},
        safetySettings = safety_settings,
        generationConfig = {
            temperature = 0.4,
            topK = 40,
            topP = 0.95,
            maxOutputTokens = 8192,
            responseMimeType = "application/json" -- JSON Modu
        }
    })
    
    -- RETRY LOGIC
    local max_retries = 1
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
             local socket = require("socket")
             socket.sleep(3) 
        end

        local response_body = {}
        local res, code, headers, status = https.request{
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request_body),
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 120
        }
        
        local response_text = table.concat(response_body)
        local code_num = tonumber(code)
        
        logger.info("AIHelper: API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then return nil, "error_json_parse" end
            
            -- CRASH PROTECTION: Null check yapısı
            if data and data.candidates and data.candidates[1] then
                local candidate = data.candidates[1]
                
                -- Güvenlik sebebiyle engellendi mi?
                if candidate.finishReason == "SAFETY" then
                     logger.warn("AIHelper: BLOCKED BY SAFETY FILTER")
                     return nil, "error_safety", "Google Güvenlik Filtresi engelledi."
                end

                if candidate.content and candidate.content.parts and candidate.content.parts[1] then
                    return self:parseAIResponse(candidate.content.parts[1].text)
                else
                    logger.warn("AIHelper: No text in response")
                    return nil, "error_api", "API boş yanıt döndürdü."
                end
            else
                return nil, "error_api", "Geçersiz yanıt formatı"
            end
        elseif code_num == 503 then
             logger.warn("AIHelper: 503 Service Unavailable (Retrying...)")
        elseif not code_num then
             local detail = status or code or res or "unknown transport error"
             logger.warn("AIHelper: Gemini request failed:", tostring(detail))
             return nil, "error_network", "Request failed: " .. tostring(detail)
        else
             local detail = self:getAPIErrorMessage(response_text)
             return nil, "error_" .. tostring(code_num), "HTTP " .. tostring(code_num) .. (detail and (": " .. detail) or "")
        end
    end
    
    return nil, "error_timeout", "Zaman aşımı"
end

-- Call ChatGPT API (COMPLETE IMPLEMENTATION)
function AIHelper:callChatGPT(prompt, config)
    logger.info("AIHelper: Calling ChatGPT API")
    
    local model = config.model or "gpt-4o-mini"
    local url = self:normalizeChatCompletionsEndpoint(config.endpoint) or "https://api.openai.com/v1/chat/completions"

    if not self:isLocalEndpoint(url) and not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "İnternet bağlantısı yok"
    end
    
    -- System instruction ekle (eğer prompts'ta varsa)
    local system_instruction = self.prompts and self.prompts.system_instruction or 
        "You are an expert literary critic. Respond ONLY with valid JSON format."
    
    local request_data = {
        model = model,
        messages = {
            {
                role = "system",
                content = system_instruction
            },
            {
                role = "user",
                content = prompt
            }
        },
        temperature = 0.4,
        max_tokens = 8192,
        top_p = 0.95,
    }

    if config.response_format_enabled == true then
        request_data.response_format = { type = "json_object" }
    end
    self:sanitizeChatMessages(request_data)
    self:addOpenAICompatibilityParams(request_data, config)

    local request_body = json.encode(request_data)
    
    logger.info("AIHelper: ChatGPT endpoint:", url)
    logger.info("AIHelper: ChatGPT model:", model)
    logger.info("AIHelper: ChatGPT thinking:", self:getThinkingMode(config))
    logger.info("AIHelper: ChatGPT reasoning effort:", config.reasoning_effort or "high")
    logger.info("AIHelper: ChatGPT request size:", #request_body)
    
    -- RETRY LOGIC
    local max_retries = 1
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
             local socket = require("socket")
             socket.sleep(3) 
             logger.info("AIHelper: Retrying ChatGPT request (attempt " .. attempt .. ")")
        end

        local res, code, headers, status, response_text = self:requestChatCompletions(url, request_body, config.api_key)
        response_text = response_text or ""
        local code_num = tonumber(code)
        
        logger.info("AIHelper: ChatGPT API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then 
                logger.warn("AIHelper: JSON parse error")
                return nil, "error_json_parse" 
            end
            
            -- CRASH PROTECTION: OpenAI response structure
            if data and data.choices and data.choices[1] then
                local choice = data.choices[1]
                
                -- Finish reason kontrolü
                if choice.finish_reason == "content_filter" then
                    logger.warn("AIHelper: BLOCKED BY CONTENT FILTER")
                    return nil, "error_safety", "OpenAI içerik filtresi engelledi."
                end
                
                if choice.message and choice.message.content then
                    local content = choice.message.content
                    logger.info("AIHelper: ChatGPT response received, parsing...")
                    return self:parseAIResponse(content)
                else
                    logger.warn("AIHelper: No content in ChatGPT response")
                    return nil, "error_api", "API boş yanıt döndürdü."
                end
            else
                -- Hata mesajı varsa logla
                if data and data.error then
                    logger.warn("AIHelper: ChatGPT API Error:", data.error.message or "Unknown")
                    return nil, "error_api", data.error.message or "API Hatası"
                end
                return nil, "error_api", "Geçersiz yanıt formatı"
            end
        elseif code_num == 429 then
            logger.warn("AIHelper: 429 Rate Limit (Retrying...)")
            -- Rate limit için daha uzun bekle
            if attempt <= max_retries then
                local socket = require("socket")
                socket.sleep(5)
            end
        elseif code_num == 503 or code_num == 502 then
            logger.warn("AIHelper: " .. code_num .. " Service Error (Retrying...)")
        elseif code_num == 401 then
            return nil, "error_401", self:getAPIErrorMessage(response_text) or "API anahtarı geçersiz"
        elseif not code_num then
            local detail = status or code or res or "unknown transport error"
            logger.warn("AIHelper: ChatGPT request failed:", tostring(detail))
            return nil, "error_network", "Request failed: " .. tostring(detail)
        else
            if self:shouldRetryWithoutCompatibilityParams(code_num, response_text, request_data) and attempt <= max_retries then
                logger.warn("AIHelper: ChatGPT body parse error; retrying without thinking/response_format compatibility params")
                self:stripOpenAICompatibilityParams(request_data)
                request_body = json.encode(request_data)
            else
                logger.warn("AIHelper: Unexpected error code:", code_num)
                local detail = self:getAPIErrorMessage(response_text)
                local context = "\nURL: " .. tostring(url) .. "\nModel: " .. tostring(model)
                return nil, "error_" .. tostring(code_num), "HTTP " .. tostring(code_num) .. (detail and (": " .. detail) or "") .. context
            end
        end
    end
    
    return nil, "error_timeout", "Zaman aşımı"
end

function AIHelper:parseAIResponse(text)
    -- Temizlik
    local json_text = text:gsub("```json", ""):gsub("```", ""):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Parse
    local success, data = pcall(json.decode, json_text)
    
    -- Eğer başarısızsa, {} arasını bulmaya çalış
    if not success then
        local first = json_text:find("{")
        local last_brace = nil
        for i = #json_text, 1, -1 do
            if json_text:sub(i,i) == "}" then last_brace = i; break end
        end
        if first and last_brace then
             json_text = json_text:sub(first, last_brace)
             success, data = pcall(json.decode, json_text)
        end
    end

    if success and data then
        return self:validateAndCleanData(data)
    end
    return nil
end

function AIHelper:validateAndCleanData(data)
    if not data then return nil end
    local strings = self:getFallbackStrings()
    
    local function ensureString(v, d)
        return (type(v) == "string" and #v > 0) and v or d or ""
    end

    -- 1. YAZAR & KİTAP (Akıllı Eşleşme)
    data.book_title = data.book_title or data.title or strings.unknown_book
    data.author = data.author or data.book_author or strings.unknown_author
    data.author_bio = data.author_bio or data.AuthorBio or data.bio or ""
    data.summary = data.summary or data.book_summary or ""

    -- 2. KARAKTERLER
    local chars = data.characters or data.Characters or {}
    local valid_chars = {}
    for _, c in ipairs(chars) do
        if type(c) == "table" then
            table.insert(valid_chars, {
                name = ensureString(c.name or c.Name, strings.unnamed_character),
                role = ensureString(c.role or c.Role, strings.not_specified),
                description = ensureString(c.description or c.desc, strings.no_description),
                gender = ensureString(c.gender, ""),
                occupation = ensureString(c.occupation, "")
            })
        end
    end
    data.characters = valid_chars

    -- 3. TARİHİ KİŞİLİKLER
    local hists = data.historical_figures or data.historicalFigures or {}
    local valid_hists = {}
    for _, h in ipairs(hists) do
        if type(h) == "table" then
            table.insert(valid_hists, {
                name = ensureString(h.name or h.Name, strings.unnamed_person),
                biography = ensureString(h.biography or h.bio, strings.no_biography),
                role = ensureString(h.role, ""),
                importance_in_book = ensureString(h.importance_in_book or h.importance, "Kitapta geçiyor"),
                context_in_book = ensureString(h.context_in_book or h.context, "Dönemsel referans")
            })
        end
    end
    data.historical_figures = valid_hists

    -- 4. DİĞERLERİ
    data.locations = data.locations or {}
    data.themes = data.themes or {}
    data.timeline = data.timeline or {}
    
    return data
end

function AIHelper:setAPIKey(provider, api_key)
    if self.providers[provider] then
        self.providers[provider].api_key = api_key:gsub("%s+", "")
        if provider:match("^custom:") then
            self:saveCustomProvidersToFile()
        else
            self:saveAPIKeyToFile(provider, api_key)
        end
        return true
    end
    return false
end

function AIHelper:testAPIKey(provider)
    local provider_config
    provider, provider_config = self:getProvider(provider)
    
    if not provider_config then
        return false, "Unknown provider"
    end
    
    if not provider_config.api_key or #provider_config.api_key == 0 then
        return false, "AI API Key not set"
    end
    
    if not self:checkNetworkConnectivity() then
        return false, "No internet connection!"
    end
    
    logger.info("AIHelper: Testing", provider, "API key")
    
    local test_prompt = "Test: 'OK'"
    
    if provider_config.type == "gemini" or provider == "gemini" then
        local result, error_code, error_msg = self:callGemini(test_prompt, provider_config)
        if result then
            return true, "Success"
        else
            return false, error_msg or ("Error: " .. (error_code or "Unknown"))
        end
        
    elseif self:isOpenAICompatibleProvider(provider_config) then
        local result, error_code, error_msg = self:callChatGPT(test_prompt, provider_config)
        if result then
            return true, "Success"
        else
            return false, error_msg or ("Error: " .. (error_code or "Unknown"))
        end
    end
    
    return false, "Unsupported provider"
end

return AIHelper
