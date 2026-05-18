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

if has("gui_running")
    set lines=40
    set columns=100
endif

let maplocalleader = " "
let mapleader = " "

"nnoremap <C-d> <C-d>zz
"nnoremap <C-u> <C-u>zz

" Center the screen when jumping to the next/previous search match
"nnoremap n nzz
"nnoremap N Nzz

" Bonus: Center the screen when joining lines (keeping your eye on the break)
nnoremap J Jz

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
    "Plug 'terryma/vim-smooth-scroll'
    Plug 'psliwka/vim-smoothie'
    Plug 'preservim/nerdtree'
    Plug 'ctrlpvim/ctrlp.vim'
call plug#end()


inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
inoremap <silent><expr> <cr> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Force CoC to refresh the completion list when you backspace
inoremap <silent><expr> <BS> coc#pum#visible() ? "\<BS>\<C-r>=coc#refresh()\<CR>" : "\<BS>"
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

"noremap <silent> <c-u> zz:call smooth_scroll#up(&scroll, 8, 2)<CR>
"noremap <silent> <c-d> zz:call smooth_scroll#down(&scroll, 8, 2)<CR>
"noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 5, 4)<CR>
"noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 5, 4)<CR>

" --- SMOOTHIE CONFIG ---
let g:smoothie_enabled = 1
let g:smoothie_speed_constant_ms = 10
let g:smoothie_speed_exponent_all_platforms = 0
let g:smoothie_break_threshold = 1000 " Prevent teleporting on long jumps

" The 'Single-Trigger' mappings
nnoremap <silent> <C-d> :set scrolloff=0 <bar> call smoothie#do("\<lt>C-d>zz") <bar> set scrolloff=8<CR>
nnoremap <silent> <C-u> :set scrolloff=0 <bar> call smoothie#do("\<lt>C-u>zz") <bar> set scrolloff=8<CR>
nnoremap <silent> n     :call smoothie#do("nzz")<CR>
nnoremap <silent> N     :call smoothie#do("Nzz")<CR>


let g:NERDTreeChDirMode = 2

" Find the Git root and make it the 'home base'
function! SyncToProjectRoot()
  " Only run on real files, not tool windows or empty buffers
  if &buftype != '' || expand('%:p') == ''
    return
  endif

  " Look for a .git folder starting from the current file
  let l:git_root = finddir('.git/..', expand('%:p:h') . ';')
  
  if !empty(l:git_root)
    " Change Vim's actual working directory to the project root
    execute 'lcd ' . fnameescape(l:git_root)
  endif
endfunction

" Trigger this whenever you open a file
autocmd BufReadPost,BufEnter * call SyncToProjectRoot()

"nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-n> :execute 'NERDTreeToggle ' . getcwd()<CR>
nnoremap <leader>f :NERDTreeFind<CR>

" Stops nerdtree from expanding the tree when I hit <leader>f in its window.
nnoremap <silent> <leader>f :if &filetype !=# 'nerdtree' <bar> execute 'NERDTreeFind' <bar> endif<CR>

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


