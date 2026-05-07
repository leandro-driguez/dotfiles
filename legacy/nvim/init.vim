call plug#begin('~/.config/nvim/plugged')

" Core plugins
Plug 'neovim/nvim-lspconfig'          " LSP support
Plug 'hrsh7th/nvim-compe'            " Autocompletion

" C# specific plugins
Plug 'OmniSharp/omnisharp-vim'       " C# server and utility functions

call plug#end()

" LSP and Omnisharp Configuration
lua << EOF
local lsp = require('lspconfig')
lsp.omnisharp.setup{
    cmd = { "/nix/store/3k6bzl6rg6864m9hzp48spgjqfv1757c-omnisharp-roslyn-1.39.6/bin/OmniSharp", "--languageserver" };
}
EOF


" Autocompletion
let g:compe = {}
let g:compe.enabled = v:true
let g:compe.source = {}
let g:compe.source.path = v:true
let g:compe.source.buffer = v:true
let g:compe.source.vsnip = v:false
let g:compe.source.nvim_lsp = v:true

