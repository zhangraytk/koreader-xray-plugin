return {
    -- System instruction
    system_instruction = "你是一位文学评论专家。你的回答必须仅使用有效的 JSON 格式。不要使用 Markdown、开场白或额外说明。请使用简体中文回答。",
    
    -- Main prompt (Full book analysis)
    main = [[书名："%s" - 作者：%s
请为这本书生成详细的 X-Ray 数据。完整填写下方 JSON 格式。

规则：
1. 不要偏离 JSON 格式。
2. "author_bio" 字段是必填项；请用 2-3 句话介绍作者。
3. 角色：至少列出 15-20 个角色（主角和配角）。
4. 历史人物：找出书中提到或影响该时代的真实历史人物。如果没有，不要留空；请添加该时代的国王/领袖作为“时代人物”。
5. 细节："importance_in_book" 和 "context_in_book" 字段不得为空。请结合书中语境进行分析。

必须使用以下 JSON 格式：
{
  "book_title": "书名",
  "author": "作者名",
  "author_bio": "作者生平与文学风格的详细信息（必填）",
  "summary": "本书的完整摘要（不剧透）",
  "characters": [
    {
      "name": "角色名",
      "role": "主角 / 配角 / 反派",
      "gender": "男 / 女 / 不明确",
      "occupation": "职业或身份",
      "description": "角色的详细分析与性格特征"
    }
  ],
  "historical_figures": [
    {
      "name": "历史人物姓名",
      "role": "其在真实历史中的身份（如皇帝、哲学家）",
      "biography": "简短传记",
      "importance_in_book": "此人在书中的重要性是什么？为什么被提及？",
      "context_in_book": "书中人物如何提到此人？出现于什么语境？"
    }
  ],
  "locations": [
    {"name": "地点名称", "description": "地点描述", "importance": "在故事中的意义"}
  ],
  "themes": ["主题1", "主题2", "主题3", "主题4", "主题5"],
  "timeline": [
    {"event": "事件标题", "chapter": "相关章节/部分", "importance": "事件的重要性"}
  ]
}]],

    -- Spoiler-free prompt (Based on reading progress)
    spoiler_free = [[书名："%s" - 作者：%s
重要：读者已阅读本书的 %d%%。请仅基于该阅读进度之前的内容生成 X-Ray 数据。

防剧透规则：
1. 不要包含在该进度之后才出现的角色。
2. 不要提及在该进度之后发生的剧情事件。
3. 不要透露角色后续发展。
4. 时间线只能包含读者已读到的事件。
5. 角色描述应反映当前阅读进度下的状态，而不是后续变化。
6. 摘要只能覆盖读者目前已读内容。

附加规则：
1. 作者简介是必填（该内容不涉及剧透）。
2. 历史人物仅在已读部分被提及时可包含。
3. 地点仅包含目前已访问/提及的地点。
4. 主题应反映截至当前进度已显现的内容。

必须使用以下 JSON 格式：
{
  "book_title": "书名",
  "author": "作者名",
  "author_bio": "作者生平与文学风格的详细信息（必填）",
  "summary": "仅覆盖读者目前已读内容的摘要",
  "characters": [
    {
      "name": "角色名（仅限已出场）",
      "role": "主角 / 配角 / 反派",
      "gender": "男 / 女 / 不明确",
      "occupation": "职业或身份",
      "description": "当前阅读进度下的角色状态 - 不要透露后续发展"
    }
  ],
  "historical_figures": [
    {
      "name": "历史人物姓名",
      "role": "其在真实历史中的身份",
      "biography": "简短传记",
      "importance_in_book": "其与当前阅读进度相关的重要性",
      "context_in_book": "其在已读部分中的提及语境"
    }
  ],
  "locations": [
    {"name": "地点名称（仅限目前已访问/提及）", "description": "描述", "importance": "截至当前进度的重要性"}
  ],
  "themes": ["仅包含目前故事中已明显呈现的主题"],
  "timeline": [
    {"event": "事件标题（仅限已发生事件）", "chapter": "相关章节/部分", "importance": "重要性"}
  ]
}]],

    -- Fallback strings
    fallback = {
        unknown_book = "未知书籍",
        unknown_author = "未知作者",
        unnamed_character = "未命名角色",
        not_specified = "未说明",
        no_description = "无描述",
        unnamed_person = "未命名人物",
        no_biography = "无传记信息"
    }
}
