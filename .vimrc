" ========================================================================== "
"   VIM .vimrc 
" ========================================================================== "
set termguicolors
set t_Co=256

filetype plugin on
syntax on

source $VIMRUNTIME/defaults.vim
set nocompatible
set encoding=utf-8
set hidden
set nobackup
set nowritebackup
set updatetime=300
set shortmess+=c
set signcolumn=yes

" Quality of Life
set number
set relativenumber
set scrolloff=8
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set undofile " Persistent undo
set guicursor=
set smartindent

set undodir=~/.vim/undo

let maplocalleader = " "
let mapleader = " "

nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

set backspace=indent,eol,start " backspace over everything in insert mode

" ========================================================================== "
"   PLUGIN MANAGEMENT
" ========================================================================== "
" If you don't have vim-plug: 
" curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

call plug#begin('~/.vim/plugged')
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    Plug 'mbbill/undotree'
    Plug 'sheerun/vim-polyglot' 
    Plug 'terryma/vim-smooth-scroll'
    Plug 'preservim/nerdtree'
    Plug 'ctrlpvim/ctrlp.vim'
call plug#end()


inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

function! s:check_back_space() abort
  local col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

noremap <silent> <c-u> :call smooth_scroll#up(&scroll, 10, 2)<CR>
noremap <silent> <c-d> :call smooth_scroll#down(&scroll, 10, 2)<CR>
noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 5, 4)<CR>
noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 5, 4)<CR>

nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>  " EXTREMELY USEFUL: Opens the tree and 

let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'  " Automatically find the project root (.git)

" Add this to ignore 'junk' files so your search stays clean
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$|node_modules|target|dist'

" ========================================================================== "
" 4. EXTRAS
" ========================================================================== "
nnoremap <leader>ut :UndotreeToggle<CR>
colorscheme solarized
set background=light
