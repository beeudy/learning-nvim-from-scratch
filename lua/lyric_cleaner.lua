-- lyric_clean.lua
-- 萌娘百科日文歌词清理：去注音括号 + 截断行末中文翻译
-- 核心思路：日文句子必然夹杂假名；找最后一个假名字符，
--           其后若无假名的纯汉字串 → 中文追加，截掉。

local M = {}

-- ── UTF-8 字符迭代器 ──────────────────────────
local function each_char(s)
  local i = 1
  return function()
    if i > #s then return nil end
    local b = s:byte(i)
    local len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    local c = s:sub(i, i + len - 1)
    i = i + len
    return c
  end
end

local function chars_to_array(s)
  local t = {}
  for c in each_char(s) do t[#t+1] = c end
  return t
end

-- ── 字符分类 ─────────────────────────────────
local function is_kana(c)
  -- 平假名 U+3040-U+309F / 片假名 U+30A0-U+30FF → UTF-8 \xe3\x81~\xe3\x83
  return #c == 3 and c:byte(1) == 0xe3
    and c:byte(2) >= 0x81 and c:byte(2) <= 0x83
end

local function is_cjk(c)
  -- CJK U+4E00-U+9FFF → UTF-8 首字节 \xe4~\xe9
  return #c == 3 and c:byte(1) >= 0xe4 and c:byte(1) <= 0xe9
end

-- ── 去注音括号（只删括号内无汉字的括号对）────
local function strip_ruby(s)
  -- 萌百模板 {{ruby|漢字|かんじ}} → 漢字
  s = s:gsub("{{[Rr]uby|(.-)|(.-)}}", "%1")
  -- HTML <ruby>漢<rt>かん</rt></ruby> → 漢
  s = s:gsub("<ruby>(.-)<rt>.-</rt></ruby>", "%1")
  s = s:gsub("<rt>.-</rt>", "")
  s = s:gsub("</?ruby>", "")
  -- 全角括号（あなた）→ 删（若括号内无汉字）
  s = s:gsub("\xef\xbc\x88(.-)\xef\xbc\x89", function(inner)
    return is_cjk(inner:sub(1,3)) and "\xef\xbc\x88"..inner.."\xef\xbc\x89" or ""
  end)
  -- 半角括号
  s = s:gsub("%b()", function(m)
    local inner = m:sub(2, -2)
    return is_cjk(inner:sub(1,3)) and m or ""
  end)
  return s
end

-- ── 核心：截断假名锚点之后的中文尾巴 ──────────
local function strip_trailing_chinese(s)
  local arr = chars_to_array(s)
  local n = #arr

  -- 从右找最后一个假名的位置
  local last_kana = 0
  for i = n, 1, -1 do
    if is_kana(arr[i]) then last_kana = i; break end
  end

  if last_kana == 0 then
    -- 无假名：含汉字 → 纯中文行，丢弃；否则保留（符号/罗马字行）
    for i = 1, n do
      if is_cjk(arr[i]) then return "" end
    end
    return s
  end

  -- 检查 last_kana 之后是否还有假名
  local tail_has_kana = false
  for i = last_kana + 1, n do
    if is_kana(arr[i]) then tail_has_kana = true; break end
  end

  if not tail_has_kana then
    -- 尾部无假名 → 截断，只保留到最后一个假名
    local out = {}
    for i = 1, last_kana do out[#out+1] = arr[i] end
    return table.concat(out):match("^%s*(.-)%s*$")
  end

  return s:match("^%s*(.-)%s*$")
end

-- ── 单行完整处理 ──────────────────────────────
local function clean_line(line)
  local s = strip_ruby(line)
  s = strip_trailing_chinese(s)
  return s
end

-- ── Buffer 范围处理 ───────────────────────────
local function process_range(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local result, changed = {}, 0
  for _, line in ipairs(lines) do
    local cleaned = clean_line(line)
    if cleaned ~= "" then
      result[#result+1] = cleaned
    end
    if cleaned ~= line then changed = changed + 1 end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, result)
  vim.notify(
    ("[LyricClean] %d → %d 行，修改 %d 处"):format(#lines, #result, changed),
    vim.log.levels.INFO
  )
end

-- ── 注册命令与快捷键 ──────────────────────────
function M.setup(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command("LyricClean", function(o)
    process_range(o.line1 - 1, o.line2)
  end, { range = "%", desc = "清理萌娘百科日文歌词" })

  local key = opts.keymap ~= nil and opts.keymap or "<leader>lc"
  if key then
    vim.keymap.set("n", key, "<cmd>LyricClean<cr>", { desc = "LyricClean", silent = true })
    vim.keymap.set("v", key, ":LyricClean<cr>",     { desc = "LyricClean", silent = true })
  end
end

M.setup()
return M
