" Class: class#notebrowse#date
" Author: lymslive
" Description: VimL class frame
" Create: 2017-03-16
" Modify: 2017-03-16

"LOAD:
if exists('s:load') && !exists('g:DEBUG')
    finish
endif

" CLASS:
let s:class = class#notebrowse#old()
let s:class._name_ = 'class#notebrowse#date'
let s:class._version_ = 1

" the leading arg of date path
let s:class.daylead = ''

function! class#notebrowse#date#class() abort "{{{
    return s:class
endfunction "}}}

" NEW: argv = [notebook, daylead]
function! class#notebrowse#date#new(...) abort "{{{
    let l:obj = copy(s:class)
    call l:obj._new_(a:000)
    return l:obj
endfunction "}}}
" CTOR:
function! class#notebrowse#date#ctor(this, argv) abort "{{{
    if len(a:argv) < 2
        :ELOG 'class#notebrowse#date#new(notebook, daylead)'
        return -1
    endif
    let l:Suctor = s:class._suctor_()
    call l:Suctor(a:this, [a:argv[0]])
    let a:this.daylead = a:argv[1]
endfunction "}}}

" ISOBJECT:
function! class#notebrowse#date#isobject(that) abort "{{{
    return s:class._isobject_(a:that)
endfunction "}}}

" list: 
function! s:class.list() dict abort "{{{
    let l:pDiretory = self.notebook.Datedir()
    if !empty(self.daylead) && self.daylead !~# '/$'
        let l:daylead = self.daylead . '/'
    else
        let l:daylead = self.daylead
    endif

    let l:lpDate = glob(l:pDiretory . '/' . l:daylead . '*', 0, 1)
    let l:iHead = len(l:pDiretory) + 1
    call map(l:lpDate, 'strpart(v:val, l:iHead)')

    return l:lpDate
endfunction "}}}

" TransferScope: 
function! s:class.TransferScope() dict abort "{{{
    if self.daylead =~# self.notebook.pattern.datePath
        return class#TRUE
    endif
    return class#FALSE
endfunction "}}}

" LOAD:
let s:load = 1
:DLOG '-1 class#notebrowse#date is loading ...'
function! class#notebrowse#date#load(...) abort "{{{
    if a:0 > 0 && !empty(a:1) && exists('s:load')
        unlet s:load
        return 0
    endif
    return s:load
endfunction "}}}

" TEST:
function! class#notebrowse#date#test(...) abort "{{{
    return 0
endfunction "}}}
