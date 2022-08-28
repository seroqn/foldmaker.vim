if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_foldmaker')| finish| endif| let g:loaded_foldmaker = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:foldmaker = exists('g:foldmaker') ? g:foldmaker : {}
let g:foldmaker#use_foldmarker = exists('g:foldmaker#use_foldmarker') ? g:foldmaker#use_foldmarker : 0
let g:foldmaker#lazy_during_inserting = exists('g:foldmaker#lazy_during_inserting') ? g:foldmaker#lazy_during_inserting : 0


let g:foldmaker#kind = {'l-contination': {'head': '>> ', 'foldtext': 'join(getline(v:foldstart, v:foldend), "")'}, 'doc': {}, 'module': {}}
let g:foldmaker#kinds = {'line_continuation': {'initial_able': 0, 'able_min': 2, 'able_max': 5, 'head': '>> ', 'foldtext': 'join(getline(v:foldstart, v:foldend), "")'}}

aug foldmaker
  au!
  au FileType * call s:init()
  au InsertEnter * if g:foldmaker#lazy_during_inserting && &foldmethod=='expr' && has_key(g:foldmaker, &ft) | call foldmaker#begin_lazy() | endif
  au InsertLeave * if g:foldmaker#lazy_during_inserting && &foldmethod=='expr' && has_key(g:foldmaker, &ft) | call foldmaker#finish_lazy() | endif
aug END

function! s:init() abort "{{{
  let fts = filter(split(expand('<amatch>'), '\.'), 'has_key(g:foldmaker, v:val)')
  if fts!=[]
    call foldmaker#init(fts)
  end
endfunc
"}}}
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
