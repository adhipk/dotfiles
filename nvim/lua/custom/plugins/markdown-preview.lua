return {
  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    build = 'cd app && npm install',
    init = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_echo_preview_url = 0
      vim.g.mkdp_theme = 'light'
      vim.g.mkdp_page_title = '${name}'
      vim.g.mkdp_combine_preview = 1
      vim.g.mkdp_combine_preview_auto_refresh = 1
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_preview_options = {
        disable_sync_scroll = 0,
        sync_scroll_type = 'relative',
        hide_yaml_meta = 1,
        content_editable = false,
        disable_filename = 1,
        toc = {},
      }
      vim.cmd [[
        function! OpenMarkdownPreview(url)
          call system("open -n " . shellescape(a:url))

        endfunction
      ]]
      vim.g.mkdp_browserfunc = 'OpenMarkdownPreview'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
