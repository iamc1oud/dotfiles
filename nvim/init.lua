-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Basic VSCode-like settings
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = false -- VSCode doesn't use relative numbers by default
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.cursorline = true

-- Python provider (for full Python support)
vim.g.python3_host_prog = vim.fn.exepath("python3")

-- Plugin specifications
require("lazy").setup({
	-- VSCode theme
	{
		-- helix theme = "ayu_dark"
		-- kept installed; lazy.nvim loads it on `:colorscheme ayu-dark`
		"Shatur/neovim-ayu",
		lazy = true,
		config = function()
			require("ayu").setup({ mirage = false })
		end,
	},

	-- Xcode dark theme (active)
	{
		"fraeso/xcodedark.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("xcodedark").setup({
				transparent = true,
				integrations = {
					telescope = true,
					nvim_tree = true,
					gitsigns = true,
					bufferline = true,
					incline = true,
					lazygit = true,
					which_key = true,
					notify = true,
					snacks = true,
					blink = true,
				},
				terminal_colors = true,
			})
			vim.cmd.colorscheme("xcodedark")
		end,
	},

	-- VSCode-like icons
	{
		"nvim-tree/nvim-web-devicons",
		config = function()
			require("nvim-web-devicons").setup()
		end,
	},

	-- Treesitter for better syntax highlighting
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"lua",
					"python",
					"javascript",
					"typescript",
					"go",
					"rust",
					"bash",
					"json",
					"html",
					"css",
				},
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},

	{
		"rcarriga/nvim-notify",
		config = function()
			vim.notify = require("notify")
		end,
	},
  -- Claude Code
  {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = true,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    -- Diff management
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
},

	-- Telescope for fuzzy finding (like VSCode Ctrl+P)
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local builtin = require("telescope.builtin")
			-- VSCode Ctrl+P / Cmd+P - Quick Open
			vim.keymap.set("n", "<C-p>", builtin.find_files, { desc = "Find files" })
			vim.keymap.set("n", "<D-p>", builtin.find_files, { desc = "Find files" })

			-- VSCode Ctrl+Shift+F / Cmd+Shift+F - Search in files
			vim.keymap.set("n", "<C-S-f>", builtin.live_grep, { desc = "Search in files" })
			vim.keymap.set("n", "<D-S-f>", builtin.live_grep, { desc = "Search in files" })

			-- VSCode Ctrl+Shift+O / Cmd+Shift+O - Go to symbol
			vim.keymap.set("n", "<C-S-o>", builtin.lsp_document_symbols, { desc = "Go to symbol" })
			vim.keymap.set("n", "<D-S-o>", builtin.lsp_document_symbols, { desc = "Go to symbol" })

			-- Helix space mode
			vim.keymap.set("n", "<leader>f", builtin.find_files, { desc = "File picker" })
			vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Buffer picker" })
			vim.keymap.set("n", "<leader>s", builtin.lsp_document_symbols, { desc = "Symbol picker" })
			vim.keymap.set("n", "<leader>S", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
			vim.keymap.set("n", "<leader>d", function() builtin.diagnostics({ bufnr = 0 }) end, { desc = "Diagnostics" })
			vim.keymap.set("n", "<leader>D", builtin.diagnostics, { desc = "Workspace diagnostics" })
			vim.keymap.set("n", "<leader>/", builtin.live_grep, { desc = "Global search" })
			vim.keymap.set("n", "<leader>j", builtin.jumplist, { desc = "Jumplist" })
			vim.keymap.set("n", "<leader>'", builtin.resume, { desc = "Last picker" })
		end,
	},

	-- LSP configuration
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = { "lua_ls", "pyright", "ts_ls" },
			})

			local capabilities = vim.lsp.protocol.make_client_capabilities()

			-- Setup LSP servers
			vim.lsp.config("*", { capabilities = capabilities })
			vim.lsp.enable({ "lua_ls", "pyright", "ts_ls" })

			-- VSCode-like LSP keymaps
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
			vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
			vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature help" })

			-- VSCode F2 - Rename
			vim.keymap.set("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename" })

			-- Helix goto/space LSP keys (space-a skipped: <leader>a is Claude)
			vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
			vim.keymap.set("n", "<leader>k", vim.lsp.buf.hover, { desc = "Hover" })
			vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, { desc = "Rename" })

			-- VSCode Shift+Alt+F / Shift+Option+F - Format document
			vim.keymap.set("n", "<S-A-f>", vim.lsp.buf.format, { desc = "Format document" })
			vim.keymap.set("n", "<S-D-f>", vim.lsp.buf.format, { desc = "Format document" })
		end,
	},

	-- Autocompletion
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-Space>"] = cmp.mapping.complete(),
					-- Close menu if open, else go to line end (helix C-e)
					["<C-e>"] = cmp.mapping(function()
						if cmp.visible() then
							cmp.abort()
						else
							vim.api.nvim_feedkeys(vim.keycode("<End>"), "n", false)
						end
					end, { "i" }),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "buffer" },
					{ name = "path" },
				}),
			})
		end,
	},

	-- File explorer (like VSCode sidebar)
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				view = {
					width = 35,
					side = "left",
				},
				renderer = {
					icons = {
						show = {
							file = true,
							folder = true,
							folder_arrow = true,
							git = true,
						},
					},
				},
			})
			-- VSCode Ctrl+B / Cmd+B - Toggle sidebar
			vim.keymap.set("n", "<C-b>", ":NvimTreeToggle<CR>", { desc = "Toggle sidebar", silent = true })
			vim.keymap.set("n", "<D-b>", ":NvimTreeToggle<CR>", { desc = "Toggle sidebar", silent = true })
		end,
	},

	-- Status line (like VSCode bottom bar)
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			-- System-wide CPU/RAM, resampled at most once per second
			local prev, cached, last = nil, "", 0
			local function sys_usage()
				local now = vim.uv.now()
				if now - last < 1000 then
					return cached
				end
				last = now
				local busy, total = 0, 0
				for _, c in ipairs(vim.uv.cpu_info()) do
					local t = c.times
					busy = busy + t.user + t.nice + t.sys + t.irq
					total = total + t.user + t.nice + t.sys + t.irq + t.idle
				end
				local cpu = prev and (busy - prev[1]) / math.max(total - prev[2], 1) * 100 or 0
				prev = { busy, total }
				local mem = vim.uv.get_total_memory()
				local used = mem - vim.uv.get_available_memory()
				cached = string.format("CPU %d%%%%  RAM %.1f/%.0fG", cpu, used / 2 ^ 30, mem / 2 ^ 30)
				return cached
			end
			require("lualine").setup({
				options = {
					theme = "auto",
					section_separators = "",
					component_separators = "|",
				},
				sections = {
					lualine_x = {
						sys_usage,
						"encoding",
						"fileformat",
						"filetype",
					},
				},
			})
		end,
	},

	-- Buffer line (tabs like VSCode)
	{
		"akinsho/bufferline.nvim",
		version = "*",
		dependencies = "nvim-tree/nvim-web-devicons",
		config = function()
			require("bufferline").setup({
				options = {
					mode = "buffers",
					style_preset = require("bufferline").style_preset.default,
					themable = true,
					numbers = "none",
					close_command = "bdelete! %d",
					diagnostics = "nvim_lsp",
					offsets = {
						{
							filetype = "NvimTree",
							text = "File Explorer",
							text_align = "center",
							separator = true,
						},
					},
					separator_style = "thin",
				},
			})

			-- VSCode tab navigation
			-- Cmd+Shift+[ / Cmd+Shift+] - Previous/Next tab
			vim.keymap.set("n", "<D-S-[>", ":BufferLineCyclePrev<CR>", { desc = "Previous tab", silent = true })
			vim.keymap.set("n", "<D-S-]>", ":BufferLineCycleNext<CR>", { desc = "Next tab", silent = true })
			-- Ctrl+Tab / Ctrl+Shift+Tab alternative
			vim.keymap.set("n", "<C-Tab>", ":BufferLineCycleNext<CR>", { desc = "Next tab", silent = true })
			vim.keymap.set("n", "<C-S-Tab>", ":BufferLineCyclePrev<CR>", { desc = "Previous tab", silent = true })
			-- Cmd+W - Close tab
			vim.keymap.set("n", "<D-w>", ":bdelete<CR>", { desc = "Close tab", silent = true })
			vim.keymap.set("n", "<C-w>", ":bdelete<CR>", { desc = "Close tab", silent = true })
		end,
	},

	-- Git integration (like VSCode Git)
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "│" },
					change = { text = "│" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
			})
		end,
	},

	-- Comment plugin (VSCode Cmd+/ or Ctrl+/)
	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	},

	-- Auto pairs
	{
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup()
		end,
	},

	-- Indent guides (like VSCode)
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			require("ibl").setup()
		end,
	},

	-- Which-key for keybinding hints (like VSCode command palette)
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("which-key").setup()
		end,
	},

	-- Terminal (like VSCode integrated terminal)
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("toggleterm").setup({
				size = 15,
				open_mapping = [[<C-`>]], -- VSCode Ctrl+` toggle terminal (term 1)
				hide_numbers = true,
				shade_terminals = true,
				direction = "tab", -- each terminal opens as its own tab (gt/gT to switch)
				close_on_exit = true,
			})
			-- Cmd+` as alternative for terminal 1
			vim.keymap.set("n", "<D-`>", ":1ToggleTerm direction=tab<CR>", { desc = "Toggle terminal 1", silent = true })
			-- Second terminal, own tab
			vim.keymap.set("n", "<C-1>", ":2ToggleTerm direction=tab<CR>", { desc = "Toggle terminal 2", silent = true })
			vim.keymap.set("t", "<C-1>", "<Cmd>2ToggleTerm direction=tab<CR>", { desc = "Toggle terminal 2", silent = true })
			-- btop in a floating window (q inside btop closes it)
			local btop = require("toggleterm.terminal").Terminal:new({ cmd = "btop", direction = "float", hidden = true })
			vim.keymap.set("n", "<leader>tb", function() btop:toggle() end, { desc = "Toggle btop" })
		end,
	},
})

-- Core keybindings (minimal set)

-- Save file
vim.keymap.set("n", "<C-s>", ":w<CR>", { desc = "Save file", silent = true })
vim.keymap.set("n", "<D-s>", ":w<CR>", { desc = "Save file", silent = true })
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a", { desc = "Save file", silent = true })
vim.keymap.set("i", "<D-s>", "<Esc>:w<CR>a", { desc = "Save file", silent = true })

-- Find in current file
vim.keymap.set("n", "<C-f>", "/", { desc = "Find in file" })
vim.keymap.set("n", "<D-f>", "/", { desc = "Find in file" })

-- Select all (Ctrl+A now goes to line start, matching helix)
vim.keymap.set("n", "<D-a>", "ggVG", { desc = "Select all" })

-- Delete selected text (visual mode): D, Backspace, Delete all remove the
-- selection itself, not "to end of line" like vanilla visual D does.
vim.keymap.set("v", "D", "d", { desc = "Delete selection" })
vim.keymap.set("v", "<BS>", "d", { desc = "Delete selection" })
vim.keymap.set("v", "<Del>", "d", { desc = "Delete selection" })

-- Helix keybindings (mirrors ~/.config/helix/config.toml)
local map = vim.keymap.set

-- Cmd+Arrow: Ghostty sends Ctrl-A / Ctrl-E; <D-…> covers kitty-protocol super
for _, k in ipairs({ "<C-a>", "<D-Left>" }) do
	map("n", k, "0", { desc = "Line start" })
	map("x", k, "<Esc>0", { desc = "Line start" })
	map("i", k, "<C-o>0", { desc = "Line start" })
end
for _, k in ipairs({ "<C-e>", "<D-Right>" }) do
	map("n", k, "$", { desc = "Line end" })
	map("x", k, "<Esc>$", { desc = "Line end" })
end
map("i", "<D-Right>", "<End>", { desc = "Line end" }) -- insert <C-e> handled in cmp

-- Option+Arrow: word by word, no selection left behind
map("n", "<M-Left>", "b", { desc = "Prev word start" })
map("n", "<M-Right>", "e", { desc = "Next word end" })
map("x", "<M-Left>", "<Esc>b", { desc = "Prev word start" })
map("x", "<M-Right>", "<Esc>e", { desc = "Next word end" })
map("i", "<M-Left>", "<C-o>b", { desc = "Prev word start" })
map("i", "<M-Right>", "<C-o>e<Right>", { desc = "After next word end" })

-- macOS-style selection: Shift(+Option/Cmd)+Arrow starts/extends visual selection
for key, motion in pairs({
	["<S-Left>"] = "h",
	["<S-Right>"] = "l",
	["<S-Up>"] = "gk",
	["<S-Down>"] = "gj",
	["<M-S-Left>"] = "b",
	["<M-S-Right>"] = "e",
	["<D-S-Left>"] = "0",
	["<D-S-Right>"] = "g_",
}) do
	map("n", key, "v" .. motion, { desc = "Extend selection" })
	map("x", key, motion, { desc = "Extend selection" })
end

-- Helix goto mode
map({ "n", "x" }, "gh", "0", { desc = "Goto line start" })
map({ "n", "x" }, "gl", "$", { desc = "Goto line end" })
map({ "n", "x" }, "gs", "^", { desc = "Goto first non-blank" })
map({ "n", "x" }, "ge", "G", { desc = "Goto last line" })
map("n", "ga", "<C-^>", { desc = "Goto last accessed file" })
map("n", "gn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "gp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map({ "n", "x" }, "mm", "%", { desc = "Goto matching bracket" })

-- Misc helix normal-mode keys
map("n", "U", "<C-r>", { desc = "Redo" })
map("n", "<C-c>", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<C-c>", "gc", { remap = true, desc = "Toggle comment" })
map("n", "<leader>w", "<C-w>", { desc = "Window mode" })

-- Helix [editor.auto-save]: save on focus lost and 3s after last edit
local autosave_timer = vim.uv.new_timer()
local function autosave()
	vim.g.autosaving = true
	vim.cmd("silent! wall")
	vim.g.autosaving = false
end
vim.api.nvim_create_autocmd("FocusLost", { callback = autosave })
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
	callback = function()
		autosave_timer:stop()
		autosave_timer:start(3000, 0, vim.schedule_wrap(autosave))
	end,
})

-- Notifications (skipped for auto-saves to avoid spam)
vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function()
		if vim.g.autosaving then
			return
		end
		vim.notify("Saved successfully ✨", "info", {
			title = "File Written",
			timeout = 1200,
		})
	end,
})

vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#2f334d" })
vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#8aadf4", bg = "#2f334d" })
