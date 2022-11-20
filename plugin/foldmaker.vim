if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_foldmaker')| finish| endif| let g:loaded_foldmaker = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:foldmaker = exists('g:foldmaker') ? g:foldmaker : {}
let g:foldmaker#use_marker = exists('g:foldmaker#use_marker') ? g:foldmaker#use_marker : 0

aug foldmaker
  au!
  au FileType * call s:init()
aug END

function! s:init() abort "{{{
  unlet! b:_fdmaker b:_fdmaker_fd
  let ft = expand('<amatch>')
  let fts = ft=~'\.' ? filter(split(ft, '\.'), 'has_key(g:foldmaker, v:val)') : has_key(g:foldmaker, ft) ? [ft] : []
  if fts!=[] && foldmaker#_init_(fts)
    exe 'setlocal foldmethod=expr foldexpr=foldmaker#_expr_(v:lnum,'''. ft. ''','. string(fts).')'
  end
endfunc
"}}}
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
