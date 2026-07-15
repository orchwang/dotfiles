-- Mermaid 다이어그램을 이미지가 아닌 ASCII 아트로 미리보는 자체 모듈.
--
-- 이미지 프로토콜(kitty/sixel)·헤드리스 브라우저(puppeteer)가 필요 없어 SSH·tmux에서
-- 그대로 동작한다. 백엔드는 `mermaid-ascii`(Go 정적 바이너리, `make set-go-packages`로 설치).
--
-- 서드파티 mermaid-nvim 플러그인은 cache.hash가 NUL(\0)이 섞인 문자열을 vim.fn.sha256에
-- 넘겨 Neovim 0.11.x에서 E976(Blob as String)로 죽기 때문에 쓰지 않고 직접 구현한다.
--
-- 사용: 커서를 ```mermaid 블록 안(또는 근처)에 두고 :MermaidAscii 또는 <leader>mm.

local M = {}

local BACKEND = "mermaid-ascii"

-- 커서 기준으로 감싸는(또는 가장 가까운) ```mermaid 펜스 블록의 내용을 추출한다.
-- 반환: source(문자열) 또는 nil.
local function extract_block(buf, cursor_row)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local fence = "^%s*```+%s*mermaid%s*$"
  local close = "^%s*```+%s*$"

  -- 모든 mermaid 블록의 [start, end] 범위(0-indexed, 내용 경계)를 수집.
  local blocks = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match(fence) then
      local content_start = i + 1
      local j = content_start
      while j <= #lines and not lines[j]:match(close) do
        j = j + 1
      end
      -- content: [content_start, j-1], 펜스는 i(open), j(close)
      table.insert(blocks, { open = i, first = content_start, last = j - 1, close = j })
      i = j + 1
    else
      i = i + 1
    end
  end

  if #blocks == 0 then
    return nil
  end

  -- 커서를 감싸는 블록 우선, 없으면 가장 가까운 블록.
  local row = cursor_row -- 1-indexed
  local best, best_dist
  for _, b in ipairs(blocks) do
    if row >= b.open and row <= b.close then
      best = b
      break
    end
    local dist = math.min(math.abs(row - b.open), math.abs(row - b.close))
    if not best_dist or dist < best_dist then
      best_dist = dist
      best = b
    end
  end

  if best.first > best.last then
    return nil -- 빈 블록
  end
  local content = {}
  for k = best.first, best.last do
    table.insert(content, lines[k])
  end
  return table.concat(content, "\n")
end

-- ASCII 결과를 스크롤 가능한 플로팅 스크래치 창에 띄운다.
local function open_float(output_lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "text"

  local width = 0
  for _, l in ipairs(output_lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local ui = vim.api.nvim_list_uis()[1]
  local max_w = ui and math.floor(ui.width * 0.9) or 100
  local max_h = ui and math.floor(ui.height * 0.85) or 30
  width = math.min(math.max(width + 2, 20), max_w)
  local height = math.min(math.max(#output_lines, 3), max_h)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor(((ui and ui.height or 40) - height) / 2),
    col = math.floor(((ui and ui.width or 120) - width) / 2),
    style = "minimal",
    border = "rounded",
    title = title or " mermaid ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

function M.render()
  if vim.fn.executable(BACKEND) ~= 1 then
    vim.notify(
      "[mermaid] '" .. BACKEND .. "' 미설치. `make set-go-packages`로 설치하세요.",
      vim.log.levels.ERROR
    )
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  local source = extract_block(buf, cursor_row)
  if not source or source == "" then
    vim.notify("[mermaid] 커서 근처에 ```mermaid 블록이 없습니다.", vim.log.levels.WARN)
    return
  end

  vim.system({ BACKEND }, { stdin = source, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = (result.stderr and result.stderr ~= "" and result.stderr) or result.stdout or "unknown error"
        vim.notify("[mermaid] 렌더링 실패:\n" .. msg, vim.log.levels.ERROR)
        return
      end
      local out = vim.split(result.stdout or "", "\n", { plain = true })
      -- 후행 빈 줄 정리
      while #out > 1 and out[#out] == "" do
        table.remove(out)
      end
      if #out == 0 then
        vim.notify("[mermaid] 출력이 비어 있습니다.", vim.log.levels.WARN)
        return
      end
      open_float(out, " mermaid (ASCII) ")
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("MermaidAscii", function()
    M.render()
  end, { desc = "Render nearest mermaid block as ASCII in a float" })
end

return M
