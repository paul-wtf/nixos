{ lib, pkgs, ... }:
let
  # $NVIM is only set when Claude runs in nvim's own terminal.
  followScript = pkgs.writeShellScript "claude-nvim-follow" ''
    [ -n "''${NVIM:-}" ] || exit 0
    expr=$(${lib.getExe pkgs.jq} -r '
      { path: .tool_input.file_path,
        needle: ((.tool_input.new_string // .tool_input.edits[0].new_string // "")
                 | split("\n") | max_by(length) // "" | gsub("^\\s+|\\s+$"; "")) }
      | "v:lua.ClaudeFollow(\"" + (tojson | @base64) + "\")"
    ') || exit 0
    ${pkgs.coreutils}/bin/timeout 2 ${lib.getExe pkgs.neovim-unwrapped} \
      --server "$NVIM" --remote-expr "$expr" > /dev/null 2>&1
    exit 0
  '';

  nvimLog = pkgs.writeShellApplication {
    name = "nvim-log";
    runtimeInputs = with pkgs; [ coreutils findutils jq neovim-unwrapped ];
    text = ''
      usage() {
        cat >&2 <<'EOF'
      usage: nvim-log run [title] -- command [args...]
             nvim-log pipe [title]
             nvim-log show file [title]
             nvim-log progress current total [message]
             nvim-log close
      EOF
        exit 2
      }

      call() {
        [ -n "''${NVIM:-}" ] || return 0
        local b64
        b64=$(jq -rn --arg op "$@" '$ARGS.named | tojson | @base64')
        timeout 2 nvim --server "$NVIM" --remote-expr "v:lua.ClaudeLog(\"$b64\")" > /dev/null 2>&1 || true
      }

      new_log() {
        local dir slug
        dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nvim-log"
        mkdir -p "$dir"
        find "$dir" -name '*.log' -mtime +7 -delete 2> /dev/null || true
        slug=$(printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | cut -c1-40)
        log_file="$dir/$(date +%Y%m%d-%H%M%S)-$slug.log"
        : > "$log_file"
      }

      [ $# -gt 0 ] || usage
      cmd=$1
      shift
      case $cmd in
        run)
          title=""
          if [ "''${1:-}" != "--" ]; then title=''${1:-}; shift || true; fi
          [ "''${1:-}" = "--" ] || usage
          shift
          [ $# -gt 0 ] || usage
          [ -n "$title" ] || title="$*"
          [ -n "''${NVIM:-}" ] || exec "$@"
          new_log "$title"
          call show --arg path "$log_file" --arg title "$title"
          set +e
          "$@" 2>&1 | tee -a "$log_file"
          rc=''${PIPESTATUS[0]}
          set -e
          call finish --argjson code "$rc"
          exit "$rc"
          ;;
        pipe)
          title=''${1:-output}
          [ -n "''${NVIM:-}" ] || exec cat
          new_log "$title"
          call show --arg path "$log_file" --arg title "$title"
          tee -a "$log_file"
          call finish
          ;;
        show)
          [ $# -ge 1 ] || usage
          call show --arg path "$(realpath -m "$1")" --arg title "''${2:-$(basename "$1")}"
          ;;
        progress)
          [ $# -ge 2 ] || usage
          call progress --argjson current "$1" --argjson total "$2" --arg message "''${*:3}"
          ;;
        close)
          call close
          ;;
        *)
          usage
          ;;
      esac
    '';
  };

  # Claude Code writes background output to <tmp>/claude-<uid>/<project>/<session>/tasks/<id>.output
  # but names only the task id in the hook payload.
  backgroundLogScript = pkgs.writeShellScript "claude-nvim-background-log" ''
    [ -n "''${NVIM:-}" ] || exit 0
    input=$(cat)
    jq=${lib.getExe pkgs.jq}
    task=$($jq -r '.tool_response.backgroundTaskId // empty' <<< "$input")
    [ -n "$task" ] || exit 0
    session=$($jq -r '.session_id' <<< "$input")
    title=$($jq -r '.tool_input.description // .tool_input.command' <<< "$input")
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      for f in /tmp/claude-"$(id -u)"/*/"$session"/tasks/"$task".output; do
        [ -e "$f" ] && exec ${lib.getExe nvimLog} show "$f" "$title"
      done
      sleep 0.1
    done
    exit 0
  '';

  logContextScript = pkgs.writeShellScript "claude-nvim-log-context" ''
    [ -n "''${NVIM:-}" ] || exit 0
    cat <<'EOF'
    This session runs in a terminal inside nvim, which has a log pane for command output.
    - Run builds, deploys, migrations, test suites and other long or chatty commands as
      `nvim-log run "<title>" -- <command> [args...]` (shell syntax: `-- sh -c '...'`).
      The output streams into the pane and still comes back to you; the exit code is the
      command's. Programs that buffer when piped (Python) need their unbuffered flag.
    - Background Bash commands show up in the pane on their own.
    - During multi-step work (migrations, batch jobs, rollouts) report progress with
      `nvim-log progress <current> <total> "<message>"`.
    - `... | nvim-log pipe "<title>"` tees a pipeline into the pane; `nvim-log close` closes it.
    EOF
  '';
in
{
  home.packages = [ nvimLog ];

  programs.claude-code.settings.hooks = {
    PostToolUse = [
      # Auto mode applies edits without a permission prompt, so claudecode.nvim never
      # gets a diff to show; this opens the edited file in nvim instead.
      {
        matcher = "Edit|Write|MultiEdit";
        hooks = [{ type = "command"; command = "${followScript}"; }];
      }
      {
        matcher = "Bash";
        hooks = [{ type = "command"; command = "${backgroundLogScript}"; }];
      }
    ];
    SessionStart = [{
      hooks = [{ type = "command"; command = "${logContextScript}"; }];
    }];
  };

  programs.neovim = {
    enable = true;
    # User sessions only: on NixOS, root keeps vim from common/environment.nix.
    defaultEditor = true;

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

        local function editor_window()
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == ""
              and not vim.wo[w].diff
              and vim.api.nvim_win_get_config(w).relative == "" then
              return w
            end
          end
        end

        -- Called by the claude-nvim-follow hook; keeps focus in the Claude terminal.
        function _G.ClaudeFollow(payload)
          local args = vim.json.decode(vim.base64.decode(payload))
          local win = editor_window()
          if not win then return 0 end
          vim.api.nvim_win_call(win, function()
            if not pcall(vim.cmd, "edit " .. vim.fn.fnameescape(args.path)) then return end
            if args.needle == "" then return end
            for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
              if line:find(args.needle, 1, true) then
                vim.api.nvim_win_set_cursor(win, { i, 0 })
                vim.cmd("normal! zz")
                break
              end
            end
          end)
          return 0
        end

        -- ── Claude log pane (fed by nvim-log) ───────────────────
        local log = {}

        local function log_win_valid()
          return log.win and vim.api.nvim_win_is_valid(log.win)
        end

        local function log_winbar()
          if not log_win_valid() then return end
          local s = " " .. (log.title or "")
          local p = log.progress
          if p then
            if p.total and p.total > 0 then
              local filled = math.floor(20 * math.min(p.current / p.total, 1) + 0.5)
              s = s .. string.format("  %s%s %g/%g",
                string.rep("█", filled), string.rep("░", 20 - filled), p.current, p.total)
            end
            if p.message and p.message ~= "" then s = s .. "  " .. p.message end
          end
          if log.finished then
            if log.code == nil then s = s .. "  · done"
            elseif log.code == 0 then s = s .. "  ✓"
            else s = s .. "  ✗ exit " .. log.code end
          end
          vim.wo[log.win].winbar = (s:gsub("%%", "%%%%"))
        end

        local function log_show_win()
          if log_win_valid() then
            vim.api.nvim_win_set_buf(log.win, log.buf)
          else
            local anchor = editor_window() or vim.api.nvim_get_current_win()
            log.win = vim.api.nvim_open_win(log.buf, false, {
              split = "below",
              win = anchor,
              height = math.max(8, math.floor(vim.api.nvim_win_get_height(anchor) * 0.35)),
            })
            local wo = vim.wo[log.win]
            wo.number, wo.relativenumber, wo.cursorline = false, false, false
            wo.signcolumn, wo.colorcolumn, wo.winfixheight = "no", "", true
          end
          log_winbar()
        end

        local function log_new(title)
          local old = log.buf
          if log.job then pcall(vim.fn.jobstop, log.job) end
          log = { win = log.win, buf = vim.api.nvim_create_buf(false, true), title = title }
          log_show_win()
          if old and vim.api.nvim_buf_is_valid(old) then
            vim.api.nvim_buf_delete(old, { force = true })
          end
        end

        local log_ops = {}

        function log_ops.show(a)
          log_new(a.title)
          vim.api.nvim_win_call(log.win, function()
            log.job = vim.fn.jobstart(
              { "sh", "-c", 'exec tail -n +1 -F "$1" 2>/dev/null', "sh", a.path },
              { term = true })
          end)
          -- An unfocused terminal window does not scroll with its output.
          local buf = log.buf
          vim.api.nvim_buf_attach(buf, false, {
            on_lines = function()
              vim.schedule(function()
                if log.buf ~= buf or not log_win_valid()
                  or vim.api.nvim_get_current_win() == log.win then return end
                vim.api.nvim_win_set_cursor(log.win, { vim.api.nvim_buf_line_count(buf), 0 })
              end)
            end,
          })
        end

        -- Without a running log, progress messages become the log themselves.
        function log_ops.progress(a)
          if log.finished or not (log.buf and vim.api.nvim_buf_is_valid(log.buf)) then
            log_new("Progress")
          end
          log.progress = a
          if vim.bo[log.buf].buftype ~= "terminal" and a.message ~= "" then
            local line = a.total > 0 and string.format("[%g/%g] %s", a.current, a.total, a.message)
              or a.message
            local n = vim.api.nvim_buf_line_count(log.buf)
            local empty = n == 1 and vim.api.nvim_buf_get_lines(log.buf, 0, 1, false)[1] == ""
            vim.api.nvim_buf_set_lines(log.buf, empty and 0 or n, n, false, { line })
          end
          log_show_win()
          vim.api.nvim_win_set_cursor(log.win, { vim.api.nvim_buf_line_count(log.buf), 0 })
        end

        function log_ops.finish(a)
          log.finished, log.code = true, a.code
          log_winbar()
        end

        function log_ops.close()
          if log.job then pcall(vim.fn.jobstop, log.job) end
          if log_win_valid() then vim.api.nvim_win_close(log.win, true) end
          if log.buf and vim.api.nvim_buf_is_valid(log.buf) then
            vim.api.nvim_buf_delete(log.buf, { force = true })
          end
          log = {}
        end

        function _G.ClaudeLog(payload)
          local a = vim.json.decode(vim.base64.decode(payload), { luanil = { object = true } })
          local ok, err = pcall(log_ops[a.op], a)
          if not ok then vim.notify("ClaudeLog: " .. tostring(err), vim.log.levels.WARN) end
          return 0
        end

        map("n", "<leader>al", function()
          if log_win_valid() then
            vim.api.nvim_win_close(log.win, false)
          elseif log.buf and vim.api.nvim_buf_is_valid(log.buf) then
            log_show_win()
          else
            vim.notify("No Claude log yet", vim.log.levels.INFO)
          end
        end, { desc = "Toggle Claude log" })
        map("n", "<leader>ax", function() log_ops.close() end, { desc = "Close Claude log" })
      ''
    ];
  };

  catppuccin.nvim.settings.transparent_background = true;
}
