vim.pack.add {
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
}

require('render-markdown').setup {
  completions = { lsp = { enabled = true } },
  file_types = { 'markdown' },
}
