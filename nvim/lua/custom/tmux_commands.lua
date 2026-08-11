local M = {}
local palette_guard
local palette_key_ns

local function debug(message)
  local path = vim.env.TMUX_COMMAND_PALETTE_DEBUG_LOG
  if path and path ~= '' then vim.fn.writefile({ message }, path, 'a') end
end

local function lines(text)
  local result = {}
  for line in (text or ''):gmatch '[^\r\n]+' do
    table.insert(result, line)
  end
  return result
end

local function normalize_command(command)
  return vim.trim((command or ''):gsub('%s+', ' '))
end

local function fit_column(value, width)
  value = tostring(value or '')
  if vim.fn.strdisplaywidth(value) > width then value = vim.fn.strcharpart(value, 0, width - 1) .. '…' end
  return value .. string.rep(' ', math.max(0, width - vim.fn.strdisplaywidth(value)))
end

local function display_entry(item)
  return table.concat({ fit_column(item.shortcut, 12), fit_column(item.description, 34), item.command }, ' │ ')
end

local function decode_key(key)
  return (key or ''):gsub('\\(.)', '%1')
end

local function parse_notes(output)
  local notes = {}
  for _, line in ipairs(lines(output)) do
    local key, description = line:match '^(%S+)%s+(.+)$'
    if key and description then notes[decode_key(key)] = vim.trim(description) end
  end
  return notes
end

local function parse_bindings(actual_output, notes_output, table_name, described_only)
  local notes = parse_notes(notes_output)
  local entries = {}
  local table_pattern = '%-T%s+' .. vim.pesc(table_name) .. '%s+'

  for _, line in ipairs(lines(actual_output)) do
    local _, table_end = line:find(table_pattern)
    if table_end then
      local key, command = line:sub(table_end + 1):match '^(%S+)%s+(.+)$'
      key = decode_key(key)
      command = normalize_command(command)
      local description = notes[key]
      if key and command ~= '' and (description or not described_only) then
        table.insert(entries, {
          source = table_name,
          shortcut = table_name == 'prefix' and ('C-a ' .. key) or key,
          description = description or '(no description)',
          command = command,
        })
      end
    end
  end

  return entries
end

local function flatten_catalog(data)
  local entries = {}
  local macros = {}

  for _, macro in ipairs(data.macros or {}) do
    if macro.name and type(macro.commands) == 'table' then macros[macro.name] = normalize_command(table.concat(macro.commands, ' ; ')) end
  end

  local function walk(items, parents)
    for _, item in ipairs(items or {}) do
      if item.name then
        local name = item.name:gsub('^%+', '')
        local path = vim.list_extend(vim.deepcopy(parents), { name })
        if type(item.menu) == 'table' then
          walk(item.menu, path)
        else
          local command = item.command or macros[item.macro]
          if command then
            table.insert(entries, {
              source = 'action',
              shortcut = '—',
              description = table.concat(path, ' › '),
              command = normalize_command(command),
            })
          end
        end
      end
    end
  end

  walk(data.items, {})
  return entries
end

local function run(command)
  local result = vim.system(command, { text = true }):wait()
  return result.code == 0 and result.stdout or ''
end

local function collect_catalog()
  if vim.fn.executable 'yq' ~= 1 then return {} end

  local path = vim.env.TMUX_COMMAND_PALETTE_CATALOG or (vim.env.HOME .. '/.config/tmux/which-key.yaml')
  if vim.fn.filereadable(path) ~= 1 then return {} end

  local encoded = run { 'yq', '-o=json', '.', path }
  if encoded == '' then return {} end

  local ok, data = pcall(vim.json.decode, encoded)
  if not ok or type(data) ~= 'table' then return {} end
  return flatten_catalog(data)
end

function M.collect()
  local entries = {}
  local function append(values)
    vim.list_extend(entries, values)
  end

  append(parse_bindings(run { 'tmux', 'list-keys', '-T', 'prefix' }, run { 'tmux', 'list-keys', '-N', '-T', 'prefix' }, 'prefix', false))
  append(parse_bindings(run { 'tmux', 'list-keys', '-T', 'root' }, run { 'tmux', 'list-keys', '-N', '-T', 'root' }, 'root', true))
  append(collect_catalog())

  table.sort(entries, function(left, right)
    if left.source ~= right.source then return left.source < right.source end
    if left.description ~= right.description then return left.description < right.description end
    return left.shortcut < right.shortcut
  end)
  return entries
end

local function stop_palette_guard()
  if palette_guard then
    palette_guard:stop()
    if not palette_guard:is_closing() then palette_guard:close() end
    palette_guard = nil
  end
end

local function stop_palette_key_watch()
  if palette_key_ns then
    vim.on_key(nil, palette_key_ns)
    palette_key_ns = nil
  end
end

local function quit_palette()
  debug 'quit'
  stop_palette_guard()
  stop_palette_key_watch()
  -- The palette owns this Neovim process, so force the whole process to exit.
  -- Closing only Telescope leaves its scratch buffers behind in the popup.
  vim.cmd 'qa!'
end

local function watch_palette_keys(choose, cancel)
  stop_palette_key_watch()
  palette_key_ns = vim.api.nvim_create_namespace 'tmux-command-palette-input'
  local handled = false

  vim.on_key(function(key, typed)
    if handled then return '' end

    -- Inspect the key the terminal actually sent, before Telescope's mapping
    -- expands it into a <Cmd> sequence. Under Ghostty/tmux's keyboard
    -- protocol that expansion can bypass the prompt buffer's <CR>/<Esc>
    -- callbacks even though ordinary text reaches Telescope correctly.
    local sent = vim.fn.keytrans(typed)
    if sent == '<CR>' or sent == '<Enter>' then
      handled = true
      debug('input=' .. sent)
      vim.schedule(choose)
      return ''
    end
    if sent == '<Esc>' or sent == '<C-C>' then
      handled = true
      debug('input=' .. sent)
      vim.schedule(cancel)
      return ''
    end

    if vim.env.TMUX_COMMAND_PALETTE_DEBUG_LOG and typed ~= '' then
      debug(string.format('key=%s typed=%s', vim.fn.keytrans(key), sent))
    end
  end, palette_key_ns)
end

local function focus_palette_prompt(prompt_bufnr)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end

    local prompt_win = vim.fn.bufwinid(prompt_bufnr)
    if prompt_win == -1 or not vim.api.nvim_win_is_valid(prompt_win) then return end

    vim.api.nvim_set_current_win(prompt_win)
    vim.cmd 'startinsert'
    debug(string.format('focus=prompt:%s window:%s', prompt_bufnr, prompt_win))
  end)
end

local function guard_prompt_process(prompt_bufnr)
  local saw_insert = false
  local logged_state = false
  stop_palette_guard()
  palette_guard = vim.uv.new_timer()
  palette_guard:start(0, 25, vim.schedule_wrap(function()
    if not palette_guard or vim.v.exiting ~= vim.NIL then
      stop_palette_guard()
      return
    end

    local current = vim.api.nvim_get_current_buf()
    local in_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == 'i'
    if not logged_state then
      debug(string.format('guard=prompt:%s current:%s mode:%s', prompt_bufnr, current, vim.api.nvim_get_mode().mode))
      logged_state = true
    end
    if in_insert then
      saw_insert = true
    elseif saw_insert then
      -- Ghostty/tmux's keyboard protocol can turn Escape into a mode change
      -- before an insert-mode map runs. Leaving the dedicated prompt still
      -- means "close the palette", so do it at the process boundary.
      debug 'guard=left-prompt'
      quit_palette()
    end
  end))
end

local function select_and_quit(action_state)
  local entry = action_state.get_selected_entry()
  if not entry then return end

  local selection_file = vim.env.TMUX_COMMAND_PALETTE_SELECTION_FILE
  if not selection_file or selection_file == '' then
    vim.notify('tmux command palette has no selection handoff file', vim.log.levels.ERROR)
    return
  end

  vim.fn.writefile({ entry.value.command }, selection_file)
  debug('selected=' .. entry.value.command)
  quit_palette()
end

function M.open()
  debug 'open'
  if not vim.env.TMUX or vim.env.TMUX == '' then
    vim.notify('tmux command palette must run inside tmux', vim.log.levels.ERROR)
    return
  end

  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local finders = require 'telescope.finders'
  local pickers = require 'telescope.pickers'
  local previewers = require 'telescope.previewers'
  local conf = require('telescope.config').values
  local entries = M.collect()

  pickers
    .new({}, {
      prompt_title = 'Tmux commands',
      results_title = 'Search descriptions, shortcuts, and actual commands',
      preview_title = 'Actual tmux command',
      sorting_strategy = 'ascending',
      layout_strategy = 'horizontal',
      layout_config = {
        width = 0.98,
        height = 0.96,
        prompt_position = 'top',
        preview_width = 0.5,
      },
      finder = finders.new_table {
        results = entries,
        entry_maker = function(item)
          return {
            value = item,
            ordinal = table.concat({ item.source, item.shortcut, item.description, item.command }, ' '),
            display = display_entry(item),
          }
        end,
      },
      previewer = previewers.new_buffer_previewer {
        define_preview = function(self, entry)
          local item = entry.value
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
            item.description,
            '',
            'Shortcut: ' .. item.shortcut,
            'Source:   ' .. item.source,
            '',
            item.command,
          })
          vim.bo[self.state.bufnr].filetype = 'tmux'
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        local function choose()
          debug 'choose'
          select_and_quit(action_state)
        end
        local function cancel()
          debug 'cancel'
          quit_palette()
        end

        -- Cover both Telescope's action objects and the explicit buffer maps.
        -- Terminal key protocols can route Escape through Telescope's default
        -- close action before a literal buffer mapping, so replacing the
        -- actions keeps every path process-scoped.
        actions.select_default:replace(choose)
        actions.close:replace(cancel)

        vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'BufHidden', 'BufWipeout' }, {
          buffer = prompt_bufnr,
          once = true,
          callback = function(event)
            -- Last-resort ownership boundary: if Telescope closes its prompt
            -- internally, never leave the palette's Neovim process behind.
            debug('autoclose=' .. event.event)
            vim.schedule(function()
              if vim.v.exiting == vim.NIL then quit_palette() end
            end)
          end,
        })
        vim.api.nvim_create_autocmd('WinClosed', {
          pattern = tostring(vim.api.nvim_get_current_win()),
          once = true,
          callback = function()
            debug 'autoclose=WinClosed'
            vim.schedule(function()
              if vim.v.exiting == vim.NIL then quit_palette() end
            end)
          end,
        })

        -- Own the small interaction surface explicitly so every exit path
        -- terminates the whole process instead of only its Telescope buffer.
        map('i', '<CR>', choose)
        map('i', '<Esc>', cancel)
        map('i', '<C-c>', cancel)
        map('i', '<C-n>', actions.move_selection_next)
        map('i', '<C-j>', actions.move_selection_next)
        map('i', '<Down>', actions.move_selection_next)
        map('i', '<C-p>', actions.move_selection_previous)
        map('i', '<C-k>', actions.move_selection_previous)
        map('i', '<Up>', actions.move_selection_previous)
        map('n', '<CR>', choose)
        map('n', '<Esc>', cancel)
        map('n', '<C-c>', cancel)
        map('n', 'q', cancel)
        map('n', 'j', actions.move_selection_next)
        map('n', '<Down>', actions.move_selection_next)
        map('n', 'k', actions.move_selection_previous)
        map('n', '<Up>', actions.move_selection_previous)
        watch_palette_keys(choose, cancel)
        guard_prompt_process(prompt_bufnr)
        focus_palette_prompt(prompt_bufnr)
        if vim.env.TMUX_COMMAND_PALETTE_DEBUG_LOG then
          for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(prompt_bufnr, 'i')) do
            if mapping.lhs == '<CR>' or mapping.lhs == '<Esc>' or mapping.lhs == '<C-C>' then
              debug(string.format('imap=%s callback=%s', mapping.lhs, tostring(mapping.callback ~= nil)))
            end
          end
        end
        return false
      end,
    })
    :find()
end

function M.dump_json()
  io.stdout:write(vim.json.encode(M.collect()), '\n')
end

function M.self_test()
  local failures = {}
  local passed = 0
  local function check(condition, message)
    if condition then
      passed = passed + 1
    else
      table.insert(failures, message)
    end
  end

  local bindings = parse_bindings(
    'bind-key -r -T prefix C-n next-window\nbind-key -T prefix \\# list-buffers',
    'C-n Next window\n#   List buffers',
    'prefix',
    false
  )
  check(#bindings == 2, 'parses multiple live bindings')
  check(bindings[1].shortcut == 'C-a C-n', 'formats prefix shortcuts')
  check(bindings[1].description == 'Next window', 'joins key descriptions')
  check(bindings[1].command == 'next-window', 'preserves actual commands')
  check(bindings[2].shortcut == 'C-a #', 'decodes escaped tmux keys')

  local catalog = flatten_catalog {
    macros = { { name = 'reload', commands = { 'display-message reload', 'source-file ~/.tmux.conf' } } },
    items = {
      { name = '+Windows', menu = { { name = 'Next', key = 'n', command = 'next-window' } } },
      { name = 'Reload', key = 'r', macro = 'reload' },
    },
  }
  check(#catalog == 2, 'flattens nested catalog actions')
  check(catalog[1].description == 'Windows › Next', 'keeps the catalog path searchable')
  check(catalog[2].command == 'display-message reload ; source-file ~/.tmux.conf', 'expands catalog macros to actual commands')

  if #failures > 0 then
    for _, failure in ipairs(failures) do
      io.stderr:write('tmux command palette self-test: ' .. failure .. '\n')
    end
    vim.cmd 'cquit 1'
    return
  end
  io.stdout:write(('tmux command palette self-test: %d passed\n'):format(passed))
end

return M
