-- lyric_clean.lua
-- 萌娘百科日文歌词清理：因为网页源头已剔除中文，此处仅做格式净化

local M = {}

-- ── 去注音标签与空括号 ────────────────────────
local function clean_line(line)
  local s = line
  -- 1. 移除萌百模板 {{ruby|漢字|かんじ}} → 漢字
  s = s:gsub("{{[Rr]uby|(.-)|(.-)}}", "%1")
  -- 2. 移除 HTML <ruby>漢<rt>かん</rt></ruby> → 漢
  s = s:gsub("<ruby>(.-)<rt>.-</rt></ruby>", "%1")
  s = s:gsub("<rt>.-</rt>", "")
  s = s:gsub("</?ruby>", "")
  -- 3. 移除因为中文消失而可能变空或只剩符号的半角/全角括号 ( ) （ ）
  s = s:gsub("%b()", "")
  s = s:gsub("\xef\xbc\x88(.-)\xef\xbc\x89", "")
  
  -- 返回去掉两端空格后的文本
  return s:match("^%s*(.-)%s*$")
end

-- ── Buffer 范围处理 ───────────────────────────
local function process_range(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local result, changed = {}, 0
  for _, line in ipairs(lines) do
    local cleaned = clean_line(line)
    -- 过滤掉纯空行
    if cleaned ~= "" then
      result[#result+1] = cleaned
    end
    if cleaned ~= line then changed = changed + 1 end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, result)
  vim.notify(
    ("[LyricClean] 处理 %d 行，修改 %d 处"):format(#lines, changed),
    vim.log.levels.INFO
  )
end

-- ── 注册命令与快捷键 ──────────────────────────
function M.setup(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command("LyricClean", function(o)
    process_range(o.line1 - 1, o.line2)
  end, { range = "%", desc = "清理萌娘百科日文歌词格式" })

  local key = opts.keymap ~= nil and opts.keymap or "<leader>lc"
  if key then
    vim.keymap.set("n", key, "<cmd>LyricClean<cr>", { desc = "LyricClean", silent = true })
    vim.keymap.set("v", key, ":LyricClean<cr>",     { desc = "LyricClean", silent = true })
  end
end

M.setup()
return M
