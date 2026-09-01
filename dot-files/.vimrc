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
