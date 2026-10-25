{ lib, pkgs, ... }:
{
  # Language server for Nix (completion, hover, go-to-definition)
  home.packages = [ pkgs.nixd ];

  programs.vim = {
    enable = true;

    # nixpkgs defaults vim-full on darwin to an X11 GTK2 GUI, which nothing on the Mac uses.
    packageConfigurable = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      pkgs.vim-full.override { guiSupport = "none"; }
    );

    plugins = with pkgs.vimPlugins; [
      catppuccin-vim
      vim-airline
      vim-airline-themes
      vim-nix
      vim-lsp
      asyncomplete-vim
      asyncomplete-lsp-vim
      asyncomplete-file-vim
      asyncomplete-buffer-vim
    ];

    extraConfig = ''
      " ── Theme ───────────────────────────────────────────────
      set termguicolors
      syntax on

      augroup TransparentBackground
        autocmd!
        autocmd ColorScheme * highlight Normal       guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight NormalNC     guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight NonText      guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight EndOfBuffer  guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight SignColumn   guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight LineNr       guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight CursorLineNr guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight FoldColumn   guibg=NONE ctermbg=NONE
      augroup END

      silent! colorscheme catppuccin_mocha

      " ── Airline ─────────────────────────────────────────────
      let g:airline_theme = 'catppuccin_mocha'
      let g:airline_powerline_fonts = 1
      let g:airline#extensions#tabline#enabled = 1
      let g:airline#extensions#tabline#formatter = 'unique_tail'
      set laststatus=2
      set noshowmode

      " ── Sensible Defaults ───────────────────────────────────
      set nocompatible
      filetype plugin indent on

      set number relativenumber
      set cursorline
      set ruler
      set showcmd
      set wildmenu
      set scrolloff=8
      set sidescrolloff=8
      set signcolumn=yes
      set colorcolumn=100

      set tabstop=4 shiftwidth=4 softtabstop=4 expandtab
      set smartindent autoindent
      set backspace=indent,eol,start
      set wrap linebreak

      set ignorecase smartcase incsearch hlsearch

      set splitright splitbelow

      set hidden
      set autoread
      set undofile
      set undodir=~/.vim/undo
      set noswapfile
      set nobackup

      set updatetime=250
      set timeoutlen=500
      set lazyredraw
      set mouse=a
      set clipboard=unnamedplus
      set encoding=utf-8

      set foldmethod=indent
      set foldlevelstart=99

      " ── Keymaps ─────────────────────────────────────────────
      let mapleader = " "
      nnoremap <leader>w :w<CR>
      nnoremap <leader>q :q<CR>
      nnoremap <leader>h :nohlsearch<CR>
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l

      if !isdirectory(expand('~/.vim/undo'))
        call mkdir(expand('~/.vim/undo'), 'p')
      endif

      " ── Nix files: 2-space indent (community convention) ────
      autocmd FileType nix setlocal shiftwidth=2 softtabstop=2 tabstop=2

      " ── Autocomplete (asyncomplete + vim-lsp) ───────────────
      set completeopt=menuone,noinsert,noselect
      let g:asyncomplete_auto_popup = 1

      " Tab/Shift-Tab through the popup, Enter accepts
      inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
      inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
      inoremap <expr> <CR>    pumvisible() ? asyncomplete#close_popup() : "\<CR>"

      " Complete file paths in all file types
      au User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#file#get_source_options({
            \ 'name': 'file',
            \ 'allowlist': ['*'],
            \ 'priority': 10,
            \ 'completor': function('asyncomplete#sources#file#completor'),
            \ }))

      " Words from open buffers
      au User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#buffer#get_source_options({
            \ 'name': 'buffer',
            \ 'allowlist': ['*'],
            \ 'completor': function('asyncomplete#sources#buffer#completor'),
            \ }))

      " ── LSP: nixd for Nix ───────────────────────────────────
      if executable('nixd')
        au User lsp_setup call lsp#register_server({
              \ 'name': 'nixd',
              \ 'cmd': {server_info->['nixd']},
              \ 'allowlist': ['nix'],
              \ })
      endif

      let g:lsp_diagnostics_echo_cursor = 1
      let g:lsp_diagnostics_virtual_text_enabled = 0

      function! s:on_lsp_buffer_enabled() abort
        setlocal omnifunc=lsp#complete
        nmap <buffer> gd <plug>(lsp-definition)
        nmap <buffer> gr <plug>(lsp-references)
        nmap <buffer> K  <plug>(lsp-hover)
        nmap <buffer> <leader>rn <plug>(lsp-rename)
        nmap <buffer> ]d <plug>(lsp-next-diagnostic)
        nmap <buffer> [d <plug>(lsp-previous-diagnostic)
      endfunction

      augroup lsp_install
        autocmd!
        autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
      augroup END
    '';
  };
}

