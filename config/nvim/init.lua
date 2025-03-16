vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set number")
vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("lazy").setup({
  spec = {
    -- add your plugins here
    {
      "water-sucks/darkrose.nvim",
      lazy = false,
      priority = 1000,
    },
    {
      'nvim-telescope/telescope.nvim', tag = '0.1.8',
      dependencies = { 'nvim-lua/plenary.nvim' }
    },
    { 'nvim-treesitter/nvim-treesitter', build = ":TSUpdate",
      dependencies = {
        {"windwp/nvim-ts-autotag"},  
      }
    },
    { 'nvim-tree/nvim-tree.lua', dependencies = 'nvim-tree/nvim-web-devicons' },
    { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },

    {'nvimdev/dashboard-nvim', event = 'VimEnter',
      config = function()
        require('dashboard').setup{
	        theme = 'hyper',
          config = {
            header = {'hello'},

            footer = {"","the bugs are back"}
          }
        } end, dependencies = {{'nvim-tree/nvim-web-devicons'}}
    },

  {"neovim/nvim-lspconfig",
      lazy = false,
      dependencies = {
        { "ms-jpq/coq_nvim", branch = "coq" },
        { "ms-jpq/coq.artifacts", branch = "artifacts" },
        { "ms-jpq/coq.thirdparty", branch = "3p" }
      },
      init = function()
        vim.g.coq_settings = {
          auto_start = true,
        }
      end,
      config = function()
        local lspconfig = require("lspconfig")
        local coq = require("coq")
        lspconfig.ast_grep.setup(coq.lsp_ensure_capabilities({}))
        lspconfig.lua_ls.setup(coq.lsp_ensure_capabilities({}))
        lspconfig.biome.setup(coq.lsp_ensure_capabilities({}))
        lspconfig.cssls.setup(coq.lsp_ensure_capabilities({}))
        lspconfig.html.setup(coq.lsp_ensure_capabilities({}))

        vim.keymap.set ('n', 'K', vim.lsp.buf.hover, {})
      end
    },

    {"itchyny/lightline.vim"},

    { "ellisonleao/glow.nvim", config = true, cmd = "Glow" } 



 },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false },
})

local builtin = require("telescope.builtin")

-- file finding
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fs', ':NvimTreeFocus<CR>', {})
-- tab controls
vim.keymap.set('n', '<leader>t', 'gt', {})
vim.keymap.set('n', '<leader>y', 'gT', {})
vim.keymap.set('n', '<leader>1', '0gt', {})
vim.keymap.set('n', '<leader>2', '1gt', {})
vim.keymap.set('n', '<leader>3', '2gt', {})
vim.keymap.set('n', '<leader>4', '3gt', {})
vim.keymap.set('n', '<leader>5', '4gt', {})
vim.keymap.set('n', '<leader>6', '5gt', {})
-- markdown preview
vim.keymap.set('n', '<leader>gg', ':Glow<CR>', {})
vim.keymap.set('n', '<leader>gf', ':Glow!<CR>', {})
-- lsp broked again
vim.keymap.set('n', '<leader>lr', ':LspRestart<CR>', {})

local config = require("nvim-treesitter.configs")
config.setup({
  ensure_installed = {"lua", "javascript"},
  highlight = { enable = true },
  indent = { enable = true },
})
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

-- empty setup using defaults
require("darkrose").setup({
    -- Override colors
    colors = {
        orange = "#F87757",
    },
    -- Override existing or add new highlight groups
    overrides = function(c)
        return {
            Class = { fg = c.magenta },
            ["@variable"] = { fg = c.fg_dark },
        }
    end,
    -- Styles to enable or disable
    styles = {
        bold = true, -- Enable bold highlights for some highlight groups
        italic = true, -- Enable italic highlights for some highlight groups
        underline = true, -- Enable underline highlights for some highlight groups
    }
})
vim.cmd.colorscheme("darkrose")
require("nvim-tree").setup()
require("mason").setup()
require("mason-lspconfig").setup( { ensure_installed = { "lua_ls", "ast_grep", "marksman" } } )
