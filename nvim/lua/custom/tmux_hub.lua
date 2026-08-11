local M = {}

local state = {
  bufnr = nil,
  dashboard_win = nil,
  data = nil,
  collapsed = {},
  in_flight = false,
  preview_bufnr = nil,
  preview_generation = 0,
  preview_win = nil,
  rows = {},
  timer = nil,
}

local function run(command, options)
  options = options or {}
  options.text = true
  local result = vim.system(command, options):wait()
  if result.code ~= 0 then return nil, vim.trim(result.stderr or '') end
  return result.stdout or ''
end

local function decode_json(value)
  if not value or value == '' then return nil end
  local ok, decoded = pcall(vim.json.decode, value)
  if not ok or type(decoded) ~= 'table' then return nil end
  return decoded
end

local function executable(command)
  if command:find('/', 1, true) then return vim.fn.executable(command) == 1 end
  return vim.fn.executable(command) == 1
end

local function split_fields(line)
  return vim.split(line, '\t', { plain = true })
end

local function collect_panes()
  local separator = '\t'
  local format = table.concat({
    '#{session_id}',
    '#{session_name}',
    '#{window_id}',
    '#{window_name}',
    '#{pane_id}',
    '#{pane_title}',
    '#{pane_current_command}',
    '#{pane_current_path}',
  }, separator)
  local output = run { 'tmux', 'list-panes', '-a', '-F', format } or ''
  local panes = {}
  for line in output:gmatch '[^\r\n]+' do
    local fields = split_fields(line)
    if #fields >= 8 then
      table.insert(panes, {
        sessionId = fields[1],
        sessionName = fields[2],
        windowId = fields[3],
        windowName = fields[4],
        paneId = fields[5],
        title = fields[6],
        command = fields[7],
        path = fields[8],
      })
    end
  end
  return panes
end

local function fallback_sessions(panes)
  local sessions, by_id = {}, {}
  for _, pane in ipairs(panes) do
    local session = by_id[pane.sessionId]
    if not session then
      session = {
        name = pane.sessionName,
        sessionId = pane.sessionId,
        path = pane.path,
        attached = 0,
        windows = 0,
        agents = {},
        activeTimers = {},
        agentCount = 0,
        activeTimerCount = 0,
        scanHealthy = false,
      }
      by_id[pane.sessionId] = session
      table.insert(sessions, session)
    end
  end

  local windows = {}
  for _, pane in ipairs(panes) do
    local key = pane.sessionId .. ':' .. pane.windowId
    if not windows[key] then
      windows[key] = true
      by_id[pane.sessionId].windows = by_id[pane.sessionId].windows + 1
    end
    local kind = (pane.command .. ' ' .. pane.title):lower():match '(codex)' or (pane.command .. ' ' .. pane.title):lower():match '(claude)'
      or (pane.command .. ' ' .. pane.title):lower():match '(opencode)'
    if kind then
      table.insert(by_id[pane.sessionId].agents, {
        kind = kind,
        paneId = pane.paneId,
        windowId = pane.windowId,
        windowName = pane.windowName,
        path = pane.path,
        elapsed = '?',
      })
      by_id[pane.sessionId].agentCount = by_id[pane.sessionId].agentCount + 1
    end
  end
  return sessions
end

local function matching_line(content, patterns)
  for line in (content or ''):gmatch '[^\r\n]+' do
    local lower = line:lower()
    for _, pattern in ipairs(patterns) do
      if lower:find(pattern, 1, true) then return vim.trim(line) end
    end
  end
end

local function approval_line(content, title)
  if (title or ''):match '^%[ [!%.] %] Action Required' then return title end

  local lower = (content or ''):lower()
  local trust_pair = lower:find('do you trust', 1, true) and lower:find('yes, continue', 1, true)
  local confirm_pair = lower:find('yes, proceed', 1, true) and lower:find('press enter to confirm', 1, true)
  local permission_request = lower:find('would you like to run', 1, true) or lower:find('would you like to make', 1, true)
    or lower:find('would you like to grant', 1, true)
  local permission_pair = permission_request and (lower:find('yes, proceed', 1, true) or lower:find('press enter to confirm', 1, true))
  if not (trust_pair or confirm_pair or permission_pair) then return nil end

  return matching_line(content, {
    'would you like to run',
    'would you like to make',
    'would you like to grant',
    'do you trust',
    'press enter to confirm',
  }) or 'Action required'
end

local status_order = {
  waiting = 1,
  error = 2,
  ready = 3,
  working = 4,
}

local status_labels = {
  waiting = 'WAIT',
  error = 'ERR ',
  ready = 'READY',
  working = 'WORK',
}

local function title_starts_with(title, prefixes)
  for _, prefix in ipairs(prefixes) do
    if (title or ''):sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function derive_agent_status(content, title)
  local prompt = approval_line(content, title)
  if prompt then return 'waiting', prompt end

  local lower = (content or ''):lower()
  if lower:find("you've hit your usage limit", 1, true)
      or lower:find('context window full', 1, true)
      or lower:find('fatal error', 1, true) then
    return 'error', matching_line(content, {
      "you've hit your usage limit",
      'context window full',
      'fatal error',
    }) or 'Agent error'
  end

  if lower:find('esc to interrupt', 1, true)
      or title_starts_with(title, { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏', '✻', '✳', '✶', '✽', '✢' }) then
    return 'working'
  end

  -- Vanilla tmux exposes the live process and visible terminal, but it has no
  -- durable "finished turn" event. A live agent with no strong busy/blocking
  -- signal is therefore called ready rather than guessing idle vs finished.
  return 'ready'
end

local function collect_agent_details(agents, pane_by_id)
  local approvals, scanned = {}, {}
  for _, agent in ipairs(agents) do
    local pane_id = agent.paneId
    if pane_id and not scanned[pane_id] then
      scanned[pane_id] = true
      -- Only inspect the visible screen. Scrollback can contain already-resolved
      -- prompts and must never make the hub report a stale approval.
      local content = run { 'tmux', 'capture-pane', '-p', '-J', '-t', pane_id } or ''
      local pane = pane_by_id[pane_id] or {}
      local status, prompt = derive_agent_status(content, pane.title)
      agent.context = content
      agent.prompt = prompt
      agent.status = status
      agent.title = pane.title
      if status == 'waiting' then
        table.insert(approvals, {
          paneId = pane_id,
          sessionId = agent.sessionId or pane.sessionId,
          sessionName = agent.sessionName or pane.sessionName or '?',
          windowName = agent.windowName or pane.windowName or '?',
          kind = agent.kind or 'agent',
          prompt = prompt,
          context = content,
        })
      end
    end
  end
  return approvals
end

local function group_agents(agents)
  local groups, by_path = {}, {}
  for _, agent in ipairs(agents) do
    local path = agent.path and vim.fs.normalize(agent.path) or ''
    local key = path ~= '' and path or '(unknown)'
    local group = by_path[key]
    if not group then
      group = {
        path = key,
        name = path ~= '' and vim.fs.basename(path) or 'unknown',
        agents = {},
        counts = { waiting = 0, error = 0, ready = 0, working = 0 },
        attentionCount = 0,
        rank = status_order.working,
      }
      by_path[key] = group
      table.insert(groups, group)
    end
    table.insert(group.agents, agent)
    group.counts[agent.status] = (group.counts[agent.status] or 0) + 1
    if agent.status == 'waiting' or agent.status == 'error' then
      group.attentionCount = group.attentionCount + 1
    end
    group.rank = math.min(group.rank, status_order[agent.status] or status_order.ready)
  end

  local function agent_less(left, right)
    local left_rank = status_order[left.status] or status_order.ready
    local right_rank = status_order[right.status] or status_order.ready
    if left_rank ~= right_rank then return left_rank < right_rank end
    local left_number, right_number = tonumber(left.sessionName), tonumber(right.sessionName)
    if left_number and right_number and left_number ~= right_number then return left_number < right_number end
    return (left.sessionName or '') < (right.sessionName or '')
  end

  for _, group in ipairs(groups) do
    table.sort(group.agents, agent_less)
  end
  table.sort(groups, function(left, right)
    if left.rank ~= right.rank then return left.rank < right.rank end
    return left.path < right.path
  end)
  return groups
end

local function task_token(raw, prefix)
  for token in (raw or ''):gmatch '%S+' do
    if token:sub(1, #prefix) == prefix then return token:sub(#prefix + 1) end
  end
end

local function collect_todos(sessions)
  if vim.env.TMUX_HUB_SKIP_TODOS == '1' then return {} end
  local sessions_by_path = {}
  for _, session in ipairs(sessions) do
    local path = session.path
    if path and path ~= '' then
      path = vim.fs.normalize(path)
      sessions_by_path[path] = sessions_by_path[path] or session
    end
  end

  -- Read the machine-wide queue exactly once. The short lock budget keeps a
  -- dashboard refresh from queuing behind a long interactive Tuxedo session.
  local output = run({ 'todo', 'ls', '--json' }, {
    cwd = vim.fn.getcwd(),
    env = {
      TODO_LOCK_ATTEMPTS = '10',
      TODO_LOCK_SLEEP_SECS = '0.02',
    },
  })
  local todos = decode_json(output) or {}
  for _, todo in ipairs(todos) do
    local repo = task_token(todo.raw, 'repo:')
    local session
    if repo and repo ~= '' then
      repo = vim.fs.normalize(repo)
      todo.path = repo
      session = sessions_by_path[repo]
    end
    todo.sessionId = session and session.sessionId or nil
    todo.sessionName = session and session.name
      or (repo and vim.fs.basename(repo))
      or ((todo.projects or {})[1])
      or 'global'
  end
  table.sort(todos, function(left, right)
    if left.done ~= right.done then return not left.done end
    if (left.priority or 'Z') ~= (right.priority or 'Z') then return (left.priority or 'Z') < (right.priority or 'Z') end
    return (left.raw or '') < (right.raw or '')
  end)
  return todos
end

function M.collect()
  local panes = collect_panes()
  local pane_by_id = {}
  for _, pane in ipairs(panes) do
    pane_by_id[pane.paneId] = pane
  end

  local sessions
  local timer_command = vim.env.TMUX_HUB_AGENT_TIMER or 'agent-timer'
  if executable(timer_command) then
    sessions = decode_json(run { timer_command, 'sessions', '--json' })
  end
  sessions = sessions or fallback_sessions(panes)

  local agents = {}
  local hub_name = vim.env.TMUX_HUB_SESSION or 'hub'
  for _, session in ipairs(sessions) do
    session.isHub = session.name == hub_name
    session.agents = session.agents or {}
    session.agentCount = session.agentCount or #session.agents
    session.activeTimerCount = session.activeTimerCount or #(session.activeTimers or {})
    for _, agent in ipairs(session.agents) do
      agent.sessionId = session.sessionId
      agent.sessionName = session.name
      table.insert(agents, agent)
    end
  end

  local approvals = collect_agent_details(agents, pane_by_id)
  local agent_groups = group_agents(agents)
  local status_counts = { waiting = 0, error = 0, ready = 0, working = 0 }
  local sessions_by_id = {}
  for _, session in ipairs(sessions) do
    session.agentStatus = nil
    session.agentStatusCounts = { waiting = 0, error = 0, ready = 0, working = 0 }
    sessions_by_id[session.sessionId] = session
  end
  for _, agent in ipairs(agents) do
    status_counts[agent.status] = (status_counts[agent.status] or 0) + 1
    local session = sessions_by_id[agent.sessionId]
    if session then
      session.agentStatusCounts[agent.status] = (session.agentStatusCounts[agent.status] or 0) + 1
      if not session.agentStatus
          or status_order[agent.status] < status_order[session.agentStatus] then
        session.agentStatus = agent.status
      end
    end
  end
  local todos = collect_todos(sessions)
  local open_todos = 0
  for _, todo in ipairs(todos) do
    if not todo.done then open_todos = open_todos + 1 end
  end

  table.sort(sessions, function(left, right)
    if left.isHub ~= right.isHub then return left.isHub end
    if (left.hasActiveWork == true) ~= (right.hasActiveWork == true) then return left.hasActiveWork == true end
    return (left.name or '') < (right.name or '')
  end)
  table.sort(agents, function(left, right)
    local left_rank = status_order[left.status] or status_order.ready
    local right_rank = status_order[right.status] or status_order.ready
    if left_rank ~= right_rank then return left_rank < right_rank end
    if (left.sessionName or '') ~= (right.sessionName or '') then return (left.sessionName or '') < (right.sessionName or '') end
    return (left.windowName or '') < (right.windowName or '')
  end)

  return {
    generatedAt = os.date '!%Y-%m-%dT%H:%M:%SZ',
    sessions = sessions,
    agents = agents,
    agentGroups = agent_groups,
    approvals = approvals,
    todos = todos,
    summary = {
      sessions = #sessions,
      agents = #agents,
      approvals = #approvals,
      openTodos = open_todos,
      totalTodos = #todos,
      waiting = status_counts.waiting,
      errors = status_counts.error,
      ready = status_counts.ready,
      working = status_counts.working,
    },
  }
end

local function clip(value, width)
  value = tostring(value or ''):gsub('%s+', ' ')
  if vim.fn.strdisplaywidth(value) > width then value = vim.fn.strcharpart(value, 0, width - 1) .. '…' end
  return value
end

local function fit(value, width)
  value = clip(value, width)
  return value .. string.rep(' ', math.max(0, width - vim.fn.strdisplaywidth(value)))
end

local function task_title(raw)
  local title = tostring(raw or '')
  title = title:gsub('^%([A-Z]%)%s+', '')
  title = title:gsub('^%d%d%d%d%-%d%d%-%d%d%s+', '')
  local project_start = title:find('%s%+[%w_.-]+')
  if project_start then return vim.trim(title:sub(1, project_start - 1)) end
  local words = {}
  for word in title:gmatch '%S+' do
    if not word:match '^id:'
        and not word:match '^owner:'
        and not word:match '^repo:'
        and not word:match '^status:'
        and not word:match '^flow:'
        and not word:match '^depends:' then
      table.insert(words, word)
    end
  end
  return table.concat(words, ' ')
end

local function overview_groups(data)
  local groups, by_path = {}, {}
  local function ensure(path)
    path = path and path ~= '' and vim.fs.normalize(path) or '(unknown)'
    local name = path == '(unknown)' and 'unknown' or vim.fs.basename(path)
    local key = name
    local group = by_path[key]
    if group then
      if not group.pathSet[path] then
        group.pathSet[path] = true
        table.insert(group.paths, path)
      end
      return group
    end
    group = {
      key = key,
      path = path,
      paths = { path },
      pathSet = { [path] = true },
      name = name,
      agents = {},
      sessions = {},
      counts = { waiting = 0, error = 0, ready = 0, working = 0 },
      attentionCount = 0,
      taskCount = 0,
      attachedCount = 0,
      detachedCount = 0,
    }
    by_path[key] = group
    table.insert(groups, group)
    return group
  end

  for _, session in ipairs(data.sessions or {}) do
    if not session.isHub then
      local group = ensure(session.path)
      table.insert(group.sessions, session)
      if (session.attached or 0) > 0 then
        group.attachedCount = group.attachedCount + 1
      else
        group.detachedCount = group.detachedCount + 1
      end
      for _, agent in ipairs(session.agents or {}) do
        table.insert(group.agents, agent)
        local status = agent.status or 'ready'
        group.counts[status] = (group.counts[status] or 0) + 1
        if status == 'waiting' or status == 'error' then
          group.attentionCount = group.attentionCount + 1
        end
      end
    end
  end

  for _, todo in ipairs(data.todos or {}) do
    if not todo.done and todo.path and todo.path ~= '' then
      ensure(todo.path).taskCount = ensure(todo.path).taskCount + 1
    end
  end

  local active = {}
  for _, group in ipairs(groups) do
    if #group.agents > 0 or group.attachedCount > 0 or group.taskCount > 0 then
      table.sort(group.agents, function(left, right)
        local left_rank = status_order[left.status] or status_order.ready
        local right_rank = status_order[right.status] or status_order.ready
        if left_rank ~= right_rank then return left_rank < right_rank end
        return (left.sessionName or '') < (right.sessionName or '')
      end)
      table.insert(active, group)
    end
  end
  table.sort(active, function(left, right)
    if left.attentionCount ~= right.attentionCount then return left.attentionCount > right.attentionCount end
    if left.counts.working ~= right.counts.working then return left.counts.working > right.counts.working end
    if #left.agents ~= #right.agents then return #left.agents > #right.agents end
    if left.taskCount ~= right.taskCount then return left.taskCount > right.taskCount end
    return left.name < right.name
  end)
  return active
end

local function add(lines, text, action)
  table.insert(lines, text)
  if action then state.rows[#lines] = action end
end

local function current_action()
  if not state.dashboard_win or not vim.api.nvim_win_is_valid(state.dashboard_win) then return nil end
  return state.rows[vim.api.nvim_win_get_cursor(state.dashboard_win)[1]]
end

local function set_preview(lines)
  if not state.preview_bufnr or not vim.api.nvim_buf_is_valid(state.preview_bufnr) then return end
  vim.bo[state.preview_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.preview_bufnr, 0, -1, false, lines)
  vim.bo[state.preview_bufnr].modifiable = false
  vim.bo[state.preview_bufnr].modified = false
end

local function group_preview_lines(group)
  local lines = {
    string.format('%s  ·  %d agents  ·  %d sessions', group.name or 'repository', #(group.agents or {}), #(group.sessions or {})),
  }
  for _, path in ipairs(group.paths or { group.path or '' }) do
    table.insert(lines, path)
  end
  vim.list_extend(lines, {
    '',
    string.format(
      '%d waiting  ·  %d errors  ·  %d ready  ·  %d working',
      (group.counts or {}).waiting or 0,
      (group.counts or {}).error or 0,
      (group.counts or {}).ready or 0,
      (group.counts or {}).working or 0
    ),
    string.format('%d open tasks  ·  %d attached sessions', group.taskCount or 0, group.attachedCount or 0),
    '',
    'Enter shows or hides the agents in this project.',
  })
  return lines
end

local function request_preview(action)
  if not action then
    set_preview { 'Select an agent or session to preview its visible tmux pane.' }
    return
  end
  if action.kind == 'group' then
    set_preview(group_preview_lines(action.item or {}))
    return
  end

  local target = action.target
  if not target then
    set_preview { action.label or 'No live tmux pane is associated with this row.' }
    return
  end

  state.preview_generation = state.preview_generation + 1
  local generation = state.preview_generation
  vim.system({ 'tmux', 'capture-pane', '-p', '-J', '-S', '-80', '-t', target }, { text = true }, function(result)
    vim.schedule(function()
      if generation ~= state.preview_generation then return end
      if result.code ~= 0 then
        set_preview { action.label or target, '', vim.trim(result.stderr or 'Pane is no longer available.') }
        return
      end
      local header = action.label or target
      if action.status then header = string.format('[%s]  %s', status_labels[action.status] or action.status, header) end
      local lines = { header, action.path or '', '' }
      vim.list_extend(lines, vim.split(result.stdout or '', '\n', { plain = true }))
      set_preview(lines)
    end)
  end)
end

local function render(data)
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then return end
  state.data = data
  state.rows = {}
  local lines = {}
  local summary = data.summary or {}
  local projects = overview_groups(data)
  local non_hub_sessions, attached_sessions, idle_sessions = 0, 0, 0
  for _, session in ipairs(data.sessions or {}) do
    if not session.isHub then
      non_hub_sessions = non_hub_sessions + 1
      if (session.attached or 0) > 0 then attached_sessions = attached_sessions + 1 end
      if (session.agentCount or 0) == 0 then idle_sessions = idle_sessions + 1 end
    end
  end
  local detached_sessions = non_hub_sessions - attached_sessions

  add(lines, 'SESSION MANAGER')
  add(lines, string.format(
    '%d working  ·  %d need attention  ·  %d ready',
    summary.working or 0,
    (summary.waiting or 0) + (summary.errors or 0),
    summary.ready or 0
  ))
  add(lines, string.format(
    '%d projects  ·  %d open tasks  ·  %d sessions',
    #projects,
    summary.openTodos or 0,
    non_hub_sessions
  ))
  add(lines, 'Enter details  ·  a agents  ·  t tasks  ·  s sessions  ·  X cleanup  ·  q close')
  add(lines, '')

  local attention = {}
  for _, agent in ipairs(data.agents or {}) do
    if agent.status == 'waiting' or agent.status == 'error' then table.insert(attention, agent) end
  end
  if #attention > 0 then
    add(lines, string.format('NEEDS ATTENTION (%d)  ·  p to search', #attention))
    for index, agent in ipairs(attention) do
      if index <= 4 then
      add(lines, string.format(
        '  [%s]  %s / %s  %s',
        status_labels[agent.status] or agent.status,
        fit(agent.sessionName, 12),
        fit(agent.windowName, 12),
        agent.prompt or agent.title or ''
      ), {
        kind = 'agent',
        target = agent.paneId,
        sessionId = agent.sessionId,
        status = agent.status,
        label = string.format('%s / %s', agent.sessionName or '?', agent.windowName or '?'),
        path = agent.path,
        item = agent,
      })
      end
    end
    add(lines, '')
  end

  add(lines, string.format('PROJECT OVERVIEW (%d)', #projects))
  if #projects == 0 then add(lines, '  Nothing is running.') end
  for _, group in ipairs(projects) do
    local expanded = state.collapsed[group.key] == false
    local fold = expanded and '▾' or '▸'
    local state_parts = {}
    if group.counts.waiting > 0 then table.insert(state_parts, group.counts.waiting .. ' wait') end
    if group.counts.error > 0 then table.insert(state_parts, group.counts.error .. ' err') end
    if group.counts.working > 0 then table.insert(state_parts, group.counts.working .. ' work') end
    if group.counts.ready > 0 then table.insert(state_parts, group.counts.ready .. ' ready') end
    if group.taskCount > 0 then table.insert(state_parts, group.taskCount .. (group.taskCount == 1 and ' task' or ' tasks')) end
    if #state_parts == 0 and group.attachedCount > 0 then table.insert(state_parts, group.attachedCount .. ' attached') end
    add(lines, string.format(
      '  %s  %s  %s',
      fold,
      fit(group.name, 24),
      table.concat(state_parts, ' · ')
    ), { kind = 'group', groupKey = group.key, item = group, label = group.name, path = group.path })
    if expanded then
      for _, agent in ipairs(group.agents or {}) do
        add(lines, string.format(
          '      [%s]  %s / %s',
          status_labels[agent.status] or agent.status,
          fit(agent.sessionName, 12),
          clip(agent.windowName, 12)
        ), {
          kind = 'agent',
          target = agent.paneId,
          sessionId = agent.sessionId,
          status = agent.status,
          label = string.format('%s · %s / %s', agent.kind or 'agent', agent.sessionName or '?', agent.windowName or '?'),
          path = agent.path,
          item = agent,
        })
      end
    end
  end
  add(lines, '')

  add(lines, string.format('OPEN TASKS (%d)  ·  t to search', summary.openTodos or 0))
  local shown = 0
  for _, todo in ipairs(data.todos or {}) do
    if not todo.done and shown < 5 then
      shown = shown + 1
      add(lines, string.format(
        '  %s  %s  %s',
        fit(todo.priority or '–', 2),
        fit((todo.path and vim.fs.basename(todo.path)) or todo.sessionName, 16),
        clip(task_title(todo.raw), 44)
      ), {
        kind = 'todo',
        target = todo.sessionId,
        sessionId = todo.sessionId,
        label = todo.raw,
        path = todo.path,
        item = todo,
      })
    end
  end
  if shown == 0 then add(lines, '  No open global tasks.') end
  add(lines, '')
  add(lines, string.format(
    'CLEANUP  ·  %d detached  ·  %d without agents  ·  X to review',
    detached_sessions,
    idle_sessions
  ))

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.bo[state.bufnr].modifiable = false
  vim.bo[state.bufnr].modified = false
  local cursor_line = vim.api.nvim_win_get_cursor(state.dashboard_win)[1]
  if not state.rows[cursor_line] then
    for line = 1, #lines do
      if state.rows[line] then
        vim.api.nvim_win_set_cursor(state.dashboard_win, { line, 0 })
        break
      end
    end
  end
  vim.schedule(function() request_preview(current_action()) end)
end

local function hub_binary()
  local configured = vim.env.TMUX_HUB_BIN
  if configured and configured ~= '' then return configured end
  local installed = vim.fn.exepath 'tmux-hub'
  return installed ~= '' and installed or (vim.env.HOME .. '/bin/tmux-hub')
end

local function invoke(arguments)
  local command = { hub_binary() }
  vim.list_extend(command, arguments)
  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function() vim.notify(vim.trim(result.stderr or 'tmux-hub action failed'), vim.log.levels.ERROR) end)
    end
  end)
end

local function jump(action)
  if action and action.target then invoke { 'jump', action.target } end
end

local function open_window(action)
  local target = action and (action.sessionId or action.target)
  if target then invoke { 'open-window', target } end
end

local function activate(action)
  if not action then return end
  if action.kind == 'group' then
    state.collapsed[action.groupKey] = state.collapsed[action.groupKey] == false
    render(state.data)
    return
  end
  jump(action)
end

local refresh

local function session_for_action(action)
  local session_id = action and (action.sessionId or (action.kind == 'session' and action.target))
  if not session_id then return nil end

  for _, session in ipairs(state.data.sessions or {}) do
    if session.sessionId == session_id then return session end
  end
end

local function close_sessions(sessions)
  if #sessions == 0 then
    vim.notify('Select at least one tmux session to close', vim.log.levels.WARN)
    return
  end

  local labels = {}
  for _, session in ipairs(sessions) do
    if session.isHub then
      vim.notify('The active session manager cannot close itself', vim.log.levels.WARN)
      return
    end
    local activity = session.agentStatus and (' · ' .. (status_labels[session.agentStatus] or session.agentStatus)) or ''
    local attached = (session.attached or 0) > 0 and ' · attached' or ''
    table.insert(labels, string.format('%s%s%s', session.name or session.sessionId, activity, attached))
  end

  local prompt = string.format(
    'Close %d tmux session%s?\n\n%s\n\nRunning processes in these sessions will stop.',
    #sessions,
    #sessions == 1 and '' or 's',
    table.concat(labels, '\n')
  )
  if vim.fn.confirm(prompt, '&Close\n&Cancel', 2) ~= 1 then return end

  local remaining = #sessions
  local failures = {}
  for _, session in ipairs(sessions) do
    local closing_session = session
    vim.system({ hub_binary(), 'close', closing_session.sessionId }, { text = true }, function(result)
      if result.code ~= 0 then
        table.insert(failures, string.format(
          '%s: %s',
          closing_session.name or closing_session.sessionId,
          vim.trim(result.stderr or 'close failed')
        ))
      end
      remaining = remaining - 1
      if remaining == 0 then
        vim.schedule(function()
          if #failures == 0 then
            vim.notify(string.format('Closed %d tmux session%s', #sessions, #sessions == 1 and '' or 's'), vim.log.levels.INFO)
          else
            vim.notify(table.concat(failures, '\n'), vim.log.levels.ERROR)
          end
          refresh()
        end)
      end
    end)
  end
end

local function close_selected_session()
  local session = session_for_action(current_action())
  if not session then
    vim.notify('Select a session or agent before closing its tmux session', vim.log.levels.WARN)
    return
  end
  close_sessions { session }
end

local function reply(action)
  if not action or action.kind ~= 'agent' or not action.target then
    vim.notify('Select an agent row before replying', vim.log.levels.WARN)
    return
  end
  if action.status == 'working' then
    vim.notify('Agent is working; jump to it before interrupting its input', vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = string.format('Reply to %s: ', action.label or action.target) }, function(value)
    if not value or vim.trim(value) == '' then return end
    vim.system({ hub_binary(), 'send', action.target }, { text = true, stdin = value }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify(vim.trim(result.stderr or 'tmux-hub reply failed'), vim.log.levels.ERROR)
          return
        end
        vim.notify('Reply submitted to ' .. (action.label or action.target), vim.log.levels.INFO)
        refresh()
      end)
    end)
  end)
end

local function preview_lines(item)
  if item.context then return vim.split(item.context, '\n', { plain = true }) end
  local encoded = vim.inspect(item)
  return vim.split(encoded, '\n', { plain = true })
end

local function picker(title, items, display, ordinal, selected)
  local ok = pcall(require, 'telescope.pickers')
  if not ok then
    vim.notify('tmux-hub requires Telescope for drilldowns', vim.log.levels.ERROR)
    return
  end
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local finders = require 'telescope.finders'
  local pickers = require 'telescope.pickers'
  local previewers = require 'telescope.previewers'
  local conf = require('telescope.config').values

  pickers.new({}, {
    prompt_title = title,
    sorting_strategy = 'ascending',
    layout_config = { width = 0.96, height = 0.9, prompt_position = 'top', preview_width = 0.48 },
    finder = finders.new_table {
      results = items,
      entry_maker = function(item)
        return { value = item, display = display(item), ordinal = ordinal(item) }
      end,
    },
    previewer = previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines(entry.value))
      end,
    },
    sorter = conf.generic_sorter {},
    attach_mappings = function(prompt_bufnr, map)
      local function choose()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        actions.close(prompt_bufnr)
        selected(entry.value)
      end
      local function new_window()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        actions.close(prompt_bufnr)
        open_window(entry.value)
      end
      actions.select_default:replace(choose)
      map('i', '<C-o>', new_window)
      map('n', 'o', new_window)
      return true
    end,
  }):find()
end

local function show_sessions()
  picker('Tmux sessions', state.data.sessions or {}, function(item)
    return string.format('[%s]  %-18s  %2dw  %d agents  %s', status_labels[item.agentStatus] or '    ', item.name, item.windows or 0, item.agentCount or 0, item.path or '')
  end, function(item)
    return table.concat({ item.name or '', item.path or '', item.agentSummary or '', item.timerSummary or '' }, ' ')
  end, function(item)
    jump { target = item.sessionId }
  end)
end

local function show_agents()
  picker('Running agents', state.data.agents or {}, function(item)
    return string.format('[%s]  %-9s  %-18s  %-15s  %s', status_labels[item.status] or item.status or '    ', item.kind or 'agent', item.sessionName or '?', item.windowName or '?', item.elapsed or '')
  end, function(item)
    return table.concat({ item.kind or '', item.sessionName or '', item.windowName or '', item.path or '', item.command or '' }, ' ')
  end, function(item)
    jump { target = item.paneId }
  end)
end

local function show_approvals()
  picker('Approval requests', state.data.approvals or {}, function(item)
    return string.format('!  %-18s  %-15s  %s', item.sessionName or '?', item.windowName or '?', item.prompt or '')
  end, function(item)
    return table.concat({ item.sessionName or '', item.windowName or '', item.kind or '', item.prompt or '' }, ' ')
  end, function(item)
    jump { target = item.paneId }
  end)
end

local function show_todos()
  picker('Global todos', state.data.todos or {}, function(item)
    local status = item.done and 'done' or (item.priority or '–')
    return string.format('%-4s  %-18s  %s', status, item.sessionName or vim.fs.basename(item.path or ''), item.raw or '')
  end, function(item)
    return table.concat({ item.raw or '', item.path or '', item.priority or '', item.done and 'done' or 'open' }, ' ')
  end, function(item)
    if item.sessionId then jump { target = item.sessionId } end
  end)
end

local function show_session_cleanup()
  local sessions = {}
  for _, session in ipairs(state.data.sessions or {}) do
    if not session.isHub then table.insert(sessions, session) end
  end

  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local finders = require 'telescope.finders'
  local pickers = require 'telescope.pickers'
  local previewers = require 'telescope.previewers'
  local conf = require('telescope.config').values

  pickers.new({}, {
    prompt_title = 'Close tmux sessions · Tab marks multiple',
    sorting_strategy = 'ascending',
    layout_config = { width = 0.96, height = 0.9, prompt_position = 'top', preview_width = 0.48 },
    finder = finders.new_table {
      results = sessions,
      entry_maker = function(item)
        local status = status_labels[item.agentStatus] or '    '
        local attached = (item.attached or 0) > 0 and 'attached' or 'detached'
        local display = string.format('[%s]  %-18s  %-8s  %2dw  %d agents  %s', status, item.name or '?', attached, item.windows or 0, item.agentCount or 0, item.path or '')
        return {
          value = item,
          display = display,
          ordinal = table.concat({ item.name or '', item.path or '', item.agentSummary or '', attached }, ' '),
        }
      end,
    },
    previewer = previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        local content = run { 'tmux', 'capture-pane', '-p', '-J', '-S', '-80', '-t', entry.value.sessionId } or ''
        local lines = {
          string.format('%s · %s', entry.value.name or '?', entry.value.path or ''),
          '',
        }
        vim.list_extend(lines, vim.split(content, '\n', { plain = true }))
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    },
    sorter = conf.generic_sorter {},
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selected = picker:get_multi_selection()
        if #selected == 0 then
          local entry = action_state.get_selected_entry()
          if entry then selected = { entry } end
        end
        local chosen = {}
        for _, entry in ipairs(selected) do table.insert(chosen, entry.value) end
        actions.close(prompt_bufnr)
        close_sessions(chosen)
      end)
      return true
    end,
  }):find()
end

refresh = function()
  if state.in_flight then return end
  state.in_flight = true
  vim.system({ hub_binary(), 'dump-json' }, { text = true }, function(result)
    vim.schedule(function()
      state.in_flight = false
      if result.code ~= 0 then
        vim.notify(vim.trim(result.stderr or 'tmux-hub refresh failed'), vim.log.levels.ERROR)
        return
      end
      local data = decode_json(result.stdout)
      if data then render(data) end
    end)
  end)
end

local function leave_hub()
  vim.system({ 'tmux', 'switch-client', '-l' }, { text = true }, function(result)
    if result.code ~= 0 then vim.schedule(function() vim.notify('No previous tmux session', vim.log.levels.WARN) end) end
  end)
end

function M.open()
  if not vim.env.TMUX or vim.env.TMUX == '' then
    vim.notify('tmux-hub must run inside tmux', vim.log.levels.ERROR)
    return
  end

  state.bufnr = vim.api.nvim_create_buf(false, true)
  state.dashboard_win = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_name(state.bufnr, 'tmux-hub://dashboard')
  vim.bo[state.bufnr].buftype = 'nofile'
  vim.bo[state.bufnr].bufhidden = 'hide'
  vim.bo[state.bufnr].swapfile = false
  vim.bo[state.bufnr].filetype = 'tmuxhub'
  vim.api.nvim_win_set_buf(state.dashboard_win, state.bufnr)
  vim.wo[state.dashboard_win].number = false
  vim.wo[state.dashboard_win].relativenumber = false
  vim.wo[state.dashboard_win].cursorline = true
  vim.wo[state.dashboard_win].signcolumn = 'no'
  vim.wo[state.dashboard_win].wrap = false

  state.preview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.preview_bufnr, 'tmux-hub://preview')
  vim.bo[state.preview_bufnr].buftype = 'nofile'
  vim.bo[state.preview_bufnr].bufhidden = 'hide'
  vim.bo[state.preview_bufnr].swapfile = false
  vim.bo[state.preview_bufnr].filetype = 'tmuxhubpreview'
  vim.cmd 'botright vsplit'
  state.preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.preview_win, state.preview_bufnr)
  vim.wo[state.preview_win].number = false
  vim.wo[state.preview_win].relativenumber = false
  vim.wo[state.preview_win].cursorline = false
  vim.wo[state.preview_win].signcolumn = 'no'
  vim.wo[state.preview_win].wrap = false
  vim.api.nvim_set_current_win(state.dashboard_win)

  local options = { buffer = state.bufnr, silent = true, nowait = true }
  vim.keymap.set('n', '<CR>', function() activate(current_action()) end, options)
  vim.keymap.set('n', '<Space>', function() reply(current_action()) end, options)
  vim.keymap.set('n', 'x', close_selected_session, options)
  vim.keymap.set('n', 'X', show_session_cleanup, options)
  vim.keymap.set('n', 'o', function() open_window(current_action()) end, options)
  vim.keymap.set('n', 's', show_sessions, options)
  vim.keymap.set('n', 'a', show_agents, options)
  vim.keymap.set('n', 'p', show_approvals, options)
  vim.keymap.set('n', 't', show_todos, options)
  vim.keymap.set('n', 'r', refresh, options)
  vim.keymap.set('n', 'q', leave_hub, options)
  vim.keymap.set('n', '<Esc>', leave_hub, options)
  vim.keymap.set('n', 'Q', '<cmd>qa!<CR>', options)

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = state.bufnr,
    callback = function() request_preview(current_action()) end,
  })

  render { sessions = {}, agents = {}, agentGroups = {}, approvals = {}, todos = {}, summary = {} }
  refresh()
  state.timer = vim.uv.new_timer()
  state.timer:start(10000, 10000, vim.schedule_wrap(refresh))
  vim.api.nvim_create_autocmd('VimLeavePre', {
    once = true,
    callback = function()
      if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end
    end,
  })
end

function M.dump_json()
  io.stdout:write(vim.json.encode(M.collect()), '\n')
end

function M.self_test()
  local failures, passed = {}, 0
  local function check(condition, message)
    if condition then passed = passed + 1 else table.insert(failures, message) end
  end

  check(approval_line('Would you like to run the following command?\n1. Yes, proceed (y)\nPress enter to confirm') ~= nil, 'detects paired Codex command approval prompts')
  check(approval_line('', '[ ! ] Action Required | Codex') ~= nil, 'detects the explicit action-required pane title')
  check(approval_line('ordinary agent output') == nil, 'ignores ordinary pane output')
  check(derive_agent_status('', '[ ! ] Action Required | Codex') == 'waiting', 'derives waiting from an action-required title')
  check(derive_agent_status('Working (2s • esc to interrupt)', 'Codex') == 'working', 'derives working from visible activity')
  check(derive_agent_status('', '⠹ project | rollout') == 'working', 'derives working from a native spinner title')
  check(derive_agent_status("You've hit your usage limit", 'Codex') == 'error', 'derives visible terminal errors')
  check(derive_agent_status('Completed the requested change.', 'Codex') == 'ready', 'uses ready when vanilla tmux has no stronger signal')

  local sessions = fallback_sessions {
    { sessionId = '$1', sessionName = 'work', windowId = '@1', windowName = 'codex', paneId = '%1', title = 'codex', command = 'codex', path = '/tmp' },
    { sessionId = '$1', sessionName = 'work', windowId = '@2', windowName = 'shell', paneId = '%2', title = 'shell', command = 'zsh', path = '/tmp' },
  }
  check(#sessions == 1, 'groups panes into one fallback session')
  check(sessions[1].windows == 2, 'counts unique windows in fallback inventory')
  check(sessions[1].agentCount == 1, 'detects agent panes in fallback inventory')
  check(split_fields('$1\twork\t@1')[2] == 'work', 'parses tmux tab-delimited fields')

  local groups = group_agents {
    { sessionName = '2', path = '/tmp/b', status = 'ready' },
    { sessionName = '3', path = '/tmp/a', status = 'working' },
    { sessionName = '1', path = '/tmp/a', status = 'waiting' },
  }
  check(#groups == 2, 'groups agents by normalized repository path')
  check(groups[1].path == '/tmp/a', 'sorts repositories needing attention first')
  check(groups[1].counts.waiting == 1 and #groups[1].agents == 2, 'reports per-repository state counts')

  local overview = overview_groups {
    sessions = {
      {
        path = '/tmp/project',
        attached = 1,
        agents = {
          { sessionName = '1', status = 'working' },
          { sessionName = '1', status = 'ready' },
        },
      },
      { path = '/old/project', attached = 0, agents = {} },
      { path = '/tmp/manager', isHub = true, attached = 1, agents = {} },
    },
    todos = {
      { path = '/tmp/project', done = false },
      { path = '/tmp/project', done = true },
      { path = '/tmp/task-only', done = false },
    },
  }
  check(#overview == 2, 'overview includes active and task-backed projects but excludes the manager')
  check(overview[1].path == '/tmp/project', 'overview prioritizes projects with working agents')
  check(overview[1].counts.working == 1 and overview[1].counts.ready == 1, 'overview combines agent state by project')
  check(overview[1].attachedCount == 1 and overview[1].detachedCount == 1 and overview[1].taskCount == 1, 'overview combines same-named stale paths, sessions, and open tasks')
  check(task_title('(A) 2026-08-06 Fix the dashboard +dotfiles @tmux id:abc owner:codex repo:/tmp status:running') == 'Fix the dashboard', 'todo titles omit tracking metadata')
  local preview = group_preview_lines(overview[1])
  check(vim.tbl_contains(preview, '/tmp/project') and vim.tbl_contains(preview, '/old/project'), 'group preview gives each merged path its own buffer line')
  check(vim.iter(preview):all(function(line) return not line:find('\n', 1, true) end), 'group preview never sends embedded newlines to Neovim')

  if #failures > 0 then
    error('tmux hub self-test failed: ' .. table.concat(failures, '; '))
  end
  io.stdout:write(string.format('tmux hub self-test: %d passed\n', passed))
end

return M
