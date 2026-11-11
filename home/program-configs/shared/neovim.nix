{ lib, pkgs, ... }:
{
  # vim stays the EDITOR and keeps its own config in vim.nix; neovim runs
  # alongside it as `nvim`.
  programs.neovim = {
    enable = true;

    extraPackages = with pkgs; [ nixd ripgrep fd fzf ];

    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: with p; [
        bash c diff dockerfile fish git_config gitcommit gitignore go gomod
        java json kotlin lua make markdown markdown_inline nix python rust
        toml vim vimdoc yaml
      ]))
      nvim-lspconfig
      blink-cmp
      lualine-nvim
      nvim-web-devicons
      which-key-nvim
      fzf-lua
      gitsigns-nvim
      diffview-nvim
      snacks-nvim
      claudecode-nvim
    ];

    initLua = lib.mkMerge [
      (lib.mkOrder 100 ''
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "
      '')
      ''
        local o = vim.opt

        o.number = true
        o.relativenumber = true
        o.cursorline = true
        o.scrolloff = 8
        o.sidescrolloff = 8
        o.signcolumn = "yes"
        o.colorcolumn = "100"
        o.showmode = false

        o.tabstop = 4
        o.shiftwidth = 4
        o.softtabstop = 4
        o.expandtab = true
        o.smartindent = true
        o.wrap = true
        o.linebreak = true

        o.ignorecase = true
        o.smartcase = true

        o.splitright = true
        o.splitbelow = true

        o.undofile = true
        o.swapfile = false

        o.updatetime = 250
        o.timeoutlen = 500
        o.mouse = "a"
        o.clipboard = "unnamedplus"

        o.foldmethod = "indent"
        o.foldlevelstart = 99

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "nix",
          callback = function()
            vim.bo.shiftwidth = 2
            vim.bo.softtabstop = 2
            vim.bo.tabstop = 2
          end,
        })

        local map = vim.keymap.set
        map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
        map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
        map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
        map("n", "<C-h>", "<C-w>h")
        map("n", "<C-j>", "<C-w>j")
        map("n", "<C-k>", "<C-w>k")
        map("n", "<C-l>", "<C-w>l")

        -- ── Reload files changed on disk (Claude edits) ─────────
        o.autoread = true
        vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave" }, {
          command = "silent! checktime",
        })
        -- None of the events above fire while typing in the Claude terminal.
        local reload_timer = vim.uv.new_timer()
        reload_timer:start(1000, 1000, vim.schedule_wrap(function()
          if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
            vim.cmd("silent! checktime")
          end
        end))
        vim.api.nvim_create_autocmd("FileChangedShellPost", {
          callback = function(ev)
            vim.notify("Reloaded " .. vim.fn.fnamemodify(ev.file, ":~:."), vim.log.levels.INFO)
          end,
        })

        -- ── Treesitter ──────────────────────────────────────────
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(ev)
            if pcall(vim.treesitter.start, ev.buf) then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end,
        })

        -- ── LSP ─────────────────────────────────────────────────
        vim.lsp.enable("nixd")
        vim.diagnostic.config({
          virtual_text = { current_line = true },
          severity_sort = true,
        })
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(ev)
            local opts = { buffer = ev.buf }
            map("n", "gd", vim.lsp.buf.definition, opts)
            -- nowait: the built-in grn/grr/gra mappings would otherwise delay gr.
            map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { nowait = true }))
            map("n", "<leader>rn", vim.lsp.buf.rename, opts)
          end,
        })

        -- ── Completion ──────────────────────────────────────────
        require("blink.cmp").setup({
          keymap = {
            preset = "none",
            ["<Tab>"] = { "select_next", "fallback" },
            ["<S-Tab>"] = { "select_prev", "fallback" },
            ["<CR>"] = { "accept", "fallback" },
            ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
            ["<C-e>"] = { "hide", "fallback" },
          },
          completion = {
            list = { selection = { preselect = false, auto_insert = false } },
            documentation = { auto_show = true },
          },
          sources = { default = { "lsp", "path", "buffer" } },
        })

        -- ── UI ──────────────────────────────────────────────────
        require("lualine").setup({ options = { globalstatus = true } })
        require("which-key").setup({})
        require("snacks").setup({})

        -- ── Finder ──────────────────────────────────────────────
        local fzf = require("fzf-lua")
        fzf.setup({})
        map("n", "<leader>ff", fzf.files, { desc = "Find files" })
        map("n", "<leader>fg", fzf.live_grep, { desc = "Grep" })
        map("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
        map("n", "<leader>fr", fzf.oldfiles, { desc = "Recent files" })

        -- ── Git ─────────────────────────────────────────────────
        local gs = require("gitsigns")
        gs.setup({})
        map("n", "]h", function() gs.nav_hunk("next") end, { desc = "Next hunk" })
        map("n", "[h", function() gs.nav_hunk("prev") end, { desc = "Previous hunk" })
        map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
        map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
        map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
        map("n", "<leader>gb", gs.blame_line, { desc = "Blame line" })

        require("diffview").setup({})
        map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diff working tree" })
        map("n", "<leader>gD", "<cmd>DiffviewClose<cr>", { desc = "Close diff view" })
        map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })

        -- ── Claude Code ─────────────────────────────────────────
        require("claudecode").setup({
          terminal = {
            provider = "snacks",
            split_side = "right",
            split_width_percentage = 0.40,
          },
        })
        require("which-key").add({ { "<leader>a", group = "Claude" }, { "<leader>f", group = "Find" }, { "<leader>g", group = "Git" } })
        map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
        map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
        map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume session" })
        map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue last session" })
        map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Select model" })
        map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add buffer to context" })
        map("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection" })
        map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
        map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Deny diff" })
      ''
    ];
  };

  catppuccin.nvim.settings.transparent_background = true;
}
