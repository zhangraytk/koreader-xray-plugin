# 📖 KOReader X-Ray 插件

像亚马逊 Kindle X-Ray 一样，通过 AI 驱动的书籍分析提升您的阅读体验！

---

## 🎯 什么是 X-Ray 插件？

X-Ray 插件将亚马逊 Kindle 深受喜爱的 X-Ray 功能带到了 KOReader 中。它使用 Google Gemini 或 OpenAI 兼容 Chat Completions API 自动提取并整理书籍上下文，生成后数据会保存在本地：

  👥 **角色** - 姓名、描述、身份、职业
  📍 **地点** - 重要地点及其意义
  🛡️ **无剧透** - 智能摘要，避免泄露重大剧情转折
  ⏱️ **时间轴** - 按时间顺序排列的关键事件
  📜 **历史人物** - 书中提到的真实历史人物
  🎨 **主题** - 核心主题与思想
  📝 **笔记** - 您的个人角色笔记

所有数据均在本地缓存，初始获取后即可离线使用，无需联网！

---

## ✨ 核心功能

### 🤖 AI 集成

* **Google Gemini 3.1 Flash-Lite / 3 Flash / 3.1 Pro Preview**，并保留 Gemini 2.5 fallback 选项
* **OpenAI 兼容 Chat Completions**，支持 OpenAI、本地网关、代理和自托管兼容服务
* **自定义 Provider**，可分别配置 endpoint、model、API key、thinking mode 和 reasoning effort
* **AI 问答**，可从 X-Ray 菜单或选中文本高亮菜单发起
* **后台 AI 任务**，分析运行时可以继续阅读
* **当前位置上下文增强**，用当前阅读位置附近文本补充角色信息
* 支持错误恢复的智能 JSON 解析
* 语言感知提示词（支持中文、土耳其语、英语、葡萄牙语等）

### 👥 角色管理

* 根据书名自动提取角色
* 详细档案：姓名、描述、角色、性别、职业
* 支持模糊匹配的**角色搜索**
* **章节分析**：查看当前章节中出现了哪些角色
* **个人笔记**：为每个角色添加您自己的笔记
* **📊 智能菜单计数**：实时显示数量（例如：“角色 (12)”）

### 📖 深度分析

* **时间轴**：按时间顺序记录的重要事件
* **历史人物**：书中提到的真实人物（附带人物传记！）
* **地点**：重要地点及其象征意义
* **主题**：由 AI 提取的核心思想
* **防剧透**：AI 经过专门训练，自动避开关键剧透
* **🔍 增强型历史分析**：检测直接和间接的历史引用

### 💾 缓存系统

* **永久有效**：缓存永不过期
* **离线使用**：仅在初始获取数据时需要网络
* **单书存储**：每本书拥有独立的缓存
* **自动加载**：打开书籍时自动加载缓存
* **缓存 v7 元数据**：保存 provider、model、分析模式和文本来源统计
* **🌍 多语言支持**：界面 + AI 提示词均支持多语言

---

## 🚀 快速入门

### 1. 安装

```bash
# 将插件复制到 KOReader 插件目录
cp -r xray.koplugin ~/.config/koreader/plugins/

# 重启 KOReader

```

### 2. 获取免费 API 密钥

**Google Gemini (推荐 - 免费)**

1. 访问 [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)
2. 使用 Google 账号登录
3. 点击 "Create API Key"
4. 复制密钥（以 `AIza...` 开头）

**备选方案：ChatGPT (付费)**

1. 访问 [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. 创建 API 密钥（以 `sk-...` 开头）

### 3. 配置插件

1. 在 KOReader 中打开任意书籍
2. 进入 **菜单 → X-Ray → AI 设置 (AI Settings)**
3. 选择 **Google Gemini API Key**
4. 粘贴您的 API 密钥
5. 完成！ ✅

### 4. 获取首本书籍数据

1. 进入 **菜单 → X-Ray → 获取 AI 数据 (Fetch AI Data)**
2. 分析会作为后台任务启动
3. 可以继续阅读，也可以进入 **菜单 → X-Ray → 后台 AI 任务** 查看状态、Prompt 预览、诊断、恢复或取消
4. 完成！所有数据现已离线缓存 ✨

---

## 📱 使用指南

### 快速访问

* **Alt + X**: 快速 X-Ray 菜单
* **菜单 → X-Ray**: 包含所有功能的完整菜单
* **手势**: 可分配 X-Ray 及各项功能至手势操作

### 主要功能

#### 👥 角色 (Characters)

* 查看所有角色及其描述
* 点击任意角色查看详细信息
* 搜索特定角色

#### 📖 本章内容 (This Chapter)

* 查看当前章节中出现的角色
* 显示出现频率（例如：“约翰 (5次)”）
* 快速跳转至角色详情

#### ⏱️ 时间轴 (Timeline)

* 按顺序排列的重要事件
* 章节引用
* 每个事件涉及的角色

#### 📜 历史人物 (Historical Figures)

* 书中提到的真实人物
* 传记与生卒年
* 在书中的背景脉络

#### 📝 角色笔记 (Character Notes)

* 为每个角色添加个人见解
* 编辑或删除现有笔记
* 笔记按书籍分别保存

#### 🤖 AI 问答 (AI Q&A)

* 从 **菜单 → X-Ray → AI 问答** 直接提问
* 选中文本后可从高亮菜单对选中文本提问
* 使用当前选择的 AI provider 和模型

#### 🔍 当前位置上下文增强

* 从当前阅读位置附近提取文本
* 将紧凑上下文发送给 AI
* 与已有缓存的 X-Ray 数据合并，补充角色别名、身份、关系和描述

#### ⏳ 后台 AI 任务

* 显示当前阶段、provider、model、文本来源和进度
* 可以查看本次 AI 请求生成的 Prompt 预览
* 提供文本提取诊断
* 支持取消和恢复可恢复的任务状态

---

## 🛠️ 高级配置

### config.lua (可选)

创建 `xray.koplugin/config.lua` 进行永久设置：

```lua
return {
    -- API 密钥
    gemini_api_key = "AIzaSy...",
    chatgpt_api_key = "sk-...",

    -- 可选：OpenAI 兼容端点
    chatgpt_endpoint = "https://api.openai.com/v1/chat/completions",
    chatgpt_model = "gpt-4o-mini",
    chatgpt_thinking_mode = "omit", -- "omit"、"enabled" 或 "disabled"
    chatgpt_reasoning_effort = "high", -- "high" 或 "max"

    -- 默认 AI 提供商
    default_provider = "gemini",  -- 或 "chatgpt"

    -- Gemini 模型选择
    gemini_model = "gemini-3.1-flash-lite",

    -- 可选：额外的 OpenAI 兼容 Provider
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

    -- 设置
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

### 文件位置

* `~/.config/koreader/cache/xray/`: 书籍数据缓存
* `~/.config/koreader/settings/xray/`: 插件设置、API key、模型偏好、自定义 Provider 与角色笔记
* 书籍 sidecar 目录：X-Ray 缓存、角色笔记和后台任务状态
* `~/.config/koreader/plugins/xray.koplugin/`: 插件程序文件

---

## 💡 小技巧

1. **使用原版书名**：使用“罪与罚”或“Crime and Punishment”比“book1.epub”效果更好。
2. **包含作者名**：有助于 AI 更准确地识别书籍。
3. **Gemini Flash 表现出色**：对于大多数书籍，它既免费又快速准确。
4. **一次缓存，永久使用**：除非你想更新数据，否则无需重新获取。
5. **读到新角色后使用上下文增强**：可以用当前位置附近文本改善已有角色数据。
6. **本地模型或代理使用自定义 Provider**：只要兼容 OpenAI Chat Completions 即可配置。

---

## 🌍 支持语言

### 界面语言

* 简体中文 (🇨🇳)
* 英语 (🇬🇧)
* 土耳其语 (🇹🇷)
* 巴西葡萄牙语 (🇵🇹)

### AI 数据语言

AI 会自动根据您选择的界面语言提供数据（例如：界面设为中文，AI 则返回中文内容）。

---

## 🔧 技术细节

### 核心模块

* `main.lua`: 插件核心、菜单和阅读器交互
* `aihelper.lua`: Gemini 与 OpenAI 兼容 API 调用、Prompt 和响应解析
* `jobmanager.lua`: 后台 AI 任务、状态保存、恢复、取消和最终缓存写入
* `textanalyzer.lua`: 本地文本提取、分块、附近上下文和角色候选
* `cachemanager.lua`: X-Ray 缓存读写和 v6/v7 兼容
* `localization_xray.lua`: 多语言加载和 fallback

### 支持的 AI 模型

* Gemini 3.1 Flash-Lite、Gemini 3 Flash Preview、Gemini 3.1 Pro Preview
* Gemini 2.5 Flash / Pro fallback
* 任意 OpenAI 兼容 Chat Completions 模型

### 缓存元数据

新缓存会记录 `cache_version = "7.0"`，并包含 `analysis_mode`、`provider_id`、`provider_name`、`model` 和 `source_stats`，方便排障和复用。

---

## ❓ 常见问题 (FAQ)

**问：API 密钥安全吗？**
答：安全，密钥仅保存在 KOReader 本地，绝不会向外泄露。

**问：需要多少费用？**
答：Google Gemini 拥有非常宽裕的免费层级，大多数用户无需付费。

**问：支持剧透保护吗？**
答：是的！AI 收到明确指令，严禁提供剧透内容。

**问：可以编辑数据吗？**
答：可以，缓存文件是 KOReader sidecar 目录里的 Lua table 文件，可用文本编辑器谨慎修改。

**问：可以使用本地 LLM 或代理服务吗？**
答：可以。配置 OpenAI 兼容 endpoint，或新增自定义 Provider 并填写 endpoint、model 和 API key。

**问：Thinking mode 是什么？**
答：它控制是否向 OpenAI 兼容接口发送 `thinking` 参数。兼容性优先时建议使用 `omit`。

**问：打开书时自动生成 X-Ray 种子是什么意思？**
答：开启后，如果当前书没有缓存且已配置 API key，插件会在打开书时静默启动一次轻量标题/作者分析任务。

**问：后台任务失败怎么办？**
答：进入 **菜单 → X-Ray → 后台 AI 任务** 查看状态、Prompt 预览和文本提取诊断；必要时取消后用轻量模式重试。

---

## 🐛 排障

### API key 未设置

进入 **菜单 → X-Ray → AI 设置**，设置 Gemini 或 OpenAI 兼容 API key。

### AI 数据获取失败

* 检查网络连接和 API key
* 检查 provider 配额
* OpenAI 兼容服务请确认 endpoint 指向 `/v1/chat/completions`
* 如果服务不支持额外参数，将 thinking mode 设为 `omit`

### 后台任务失败

* 打开 **后台 AI 任务** 查看错误
* 查看文本提取诊断
* 如果当前文档无法提取正文，改用轻量标题分析

### 缓存未加载

* 检查书籍 sidecar 目录是否可写
* 清理缓存后重新获取
* 确认缓存文件没有手动编辑导致 Lua 语法错误

---

## 📜 许可协议

基于 **MIT License** 协议开源。

---

**为全球书友倾情打造 ❤️**
*祝阅读愉快！📖✨*
