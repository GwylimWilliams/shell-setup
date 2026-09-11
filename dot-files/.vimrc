syntax on
"set number
"set mouse=a

set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
filetype plugin indent on

set encoding=utf-8
set background=dark
set termguicolors
set shell=bash

set incsearch
set hlsearch
set ignorecase
set smartcase
set wildmenu
set wildmode=longest:full,full
set hidden
set confirm
set autoread
set history=1000
set autowriteall
set autochdir

set showmatch
set laststatus=2
set scrolloff=5
set splitbelow
set splitright

" Built-in StatusLine and VertSplit are reverse video — harsh white bars on a
" dark terminal. gui=NONE clears the reverse, otherwise the colours swap.
" cterm* mirrors the gui colours for the fallback path (no truecolor, e.g.
" vim built without +termguicolors).
" WinSeparator is what current Vim uses; VertSplit covers older versions.
highlight StatusLine cterm=NONE ctermfg=252 ctermbg=236 gui=NONE guifg=#D0D0D0 guibg=#303030
highlight StatusLineNC cterm=NONE ctermfg=244 ctermbg=234 gui=NONE guifg=#808080 guibg=#1C1C1C
highlight VertSplit cterm=NONE ctermfg=236 ctermbg=NONE gui=NONE guifg=#303030 guibg=NONE
highlight WinSeparator cterm=NONE ctermfg=236 ctermbg=NONE gui=NONE guifg=#303030 guibg=NONE

set undofile
set undodir=~/.vim/undo
if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p')
endif

let mapleader=" "
nnoremap <leader>h :nohlsearch<CR>
nnoremap <leader>v :vsplit $MYVIMRC<CR>
nnoremap <leader>s :source $MYVIMRC<CR>
nnoremap Y y$ " Y yanks to end of line like C and D
nnoremap <C-Left> b
nnoremap <C-Right> w
