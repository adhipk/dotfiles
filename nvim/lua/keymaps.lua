-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Keep yanked text intact when pasting over a visual selection.
vim.keymap.set('x', 'p', [["_dP]], { desc = 'Paste without overwriting yank register' })

-- Make Cmd+h/j/k/l behave like arrow keys across common modes.
local cmd_arrow_modes = { 'n', 'x', 'o' }
vim.keymap.set(cmd_arrow_modes, '<D-h>', 'h', { desc = 'Left (Cmd+h)' })
vim.keymap.set(cmd_arrow_modes, '<D-j>', 'j', { desc = 'Down (Cmd+j)' })
vim.keymap.set(cmd_arrow_modes, '<D-k>', 'k', { desc = 'Up (Cmd+k)' })
vim.keymap.set(cmd_arrow_modes, '<D-l>', 'l', { desc = 'Right (Cmd+l)' })
vim.keymap.set({ 'i', 'c', 't' }, '<D-h>', '<Left>', { desc = 'Left (Cmd+h)' })
vim.keymap.set({ 'i', 'c', 't' }, '<D-j>', '<Down>', { desc = 'Down (Cmd+j)' })
vim.keymap.set({ 'i', 'c', 't' }, '<D-k>', '<Up>', { desc = 'Up (Cmd+k)' })
vim.keymap.set({ 'i', 'c', 't' }, '<D-l>', '<Right>', { desc = 'Right (Cmd+l)' })

-- Familiar macOS editing shortcuts.
vim.keymap.set({ 'n', 'x' }, '<D-c>', '"+y', { desc = 'Copy to system clipboard' })
vim.keymap.set({ 'n', 'x' }, '<D-x>', '"+d', { desc = 'Cut to system clipboard' })
vim.keymap.set({ 'n', 'x' }, '<D-v>', '"+p', { desc = 'Paste from system clipboard' })
vim.keymap.set('i', '<D-v>', '<C-r>+', { desc = 'Paste from system clipboard' })
vim.keymap.set('c', '<D-v>', '<C-r>+', { desc = 'Paste from system clipboard' })

vim.keymap.set({ 'n', 'x' }, '<D-z>', 'u', { desc = 'Undo' })
vim.keymap.set('i', '<D-z>', '<C-o>u', { desc = 'Undo' })
vim.keymap.set({ 'n', 'x' }, '<D-S-z>', '<C-r>', { desc = 'Redo' })
vim.keymap.set({ 'n', 'x' }, '<D-y>', '<C-r>', { desc = 'Redo' })
vim.keymap.set('i', '<D-S-z>', '<C-o><C-r>', { desc = 'Redo' })
vim.keymap.set('i', '<D-y>', '<C-o><C-r>', { desc = 'Redo' })

-- Delete/change without polluting yank registers.
vim.keymap.set({ 'n', 'v' }, '<leader>d', [["_d]], { desc = '[D]elete without yanking' })
vim.keymap.set('n', '<leader>D', [["_D]], { desc = '[D]elete to end without yanking' })
vim.keymap.set({ 'n', 'v' }, '<leader>c', [["_c]], { desc = '[C]hange without yanking' })
vim.keymap.set('n', '<leader>C', [["_C]], { desc = '[C]hange to end without yanking' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- vim: ts=2 sts=2 sw=2 et
