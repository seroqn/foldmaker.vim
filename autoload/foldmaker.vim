if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:pats_saver = {}
let s:ft2pat = {}
function! s:initial_bvar(setting)
  let fms = get(a:setting, 'use_foldmarker', g:foldmaker#use_foldmarker) ? split(escape(&foldmarker, '\'), ',') : []
  return {'stack': [], 'prelnum': 0, 'fms': fms}
endfunc
function! foldmaker#init(fts) abort "{{{
  let ft = a:fts[0] "TODO: 複数ファイルタイプ全てに対応させる
  let d = g:foldmaker[ft]
  if d=={} || get(d, 'start_pats', [])==[]
    return -1
  end
  let s:pats_saver[ft] = d.start_pats[:]
  let s:ft2pat[ft] = '\%('. join(d.start_pats, '\m\)\|\%('). '\m\)'
  exe 'setlocal foldmethod=expr foldexpr=foldmaker#foldexpr('''. ft. ''',v:lnum)'
endfunc
"}}}
function! foldmaker#foldexpr(ft, lnum) abort "{{{
  let setting = g:foldmaker[a:ft]
  let b:_foldmaker = a:lnum != 1 && exists('b:_foldmaker') ? b:_foldmaker : s:initial_bvar(setting)
  if get(setting, 'start_pats', []) !=# get(s:pats_saver, a:ft, ["\<C-q>"]) && foldmaker#init([a:ft])
    return -1
  elseif a:lnum - b:_foldmaker.prelnum != 1
    return s:avoid{has_key(b:_foldmaker, '_lazy') ? '_lazy' : ''}(a:ft, a:lnum, setting)
  end
  let b:_foldmaker.prelnum = a:lnum
  return s:core__{get(setting, 'foldend_type', '')==#'pylike' ? 'pylike' : 'samelevel'}(a:ft, a:lnum, setting)
endfunc
"}}}
function! s:avoid(ft, lnum, setting) abort "{{{
  let [b:_foldmaker.stack, b:_foldmaker.fms, b:_foldmaker.prelnum, line] = [[], [], a:lnum, getline(a:lnum)]
  if indent(a:lnum)!=0 || line==''
    return '='
  end
  let ufm = get(a:setting, 'use_foldmarker', g:foldmaker#use_foldmarker)
  let b:_foldmaker.fms = ufm ? split(escape(&foldmarker, '\'), ',') : []
  if !ufm ? line =~# s:ft2pat[a:ft] : line =~# s:ft2pat[a:ft]. '\|\V'. b:_foldmaker.fms[0] && line !~# b:_foldmaker.fms[1]
    let b:_foldmaker.stack = [a:lnum]
    return '>1'
  end
  let prenbl = prevnonblank(a:lnum-1)
  if indent(prenbl) != 0
    return '='
  end
  let line = getline(prenbl)
  if !ufm ? line =~# s:ft2pat[a:ft] : line =~# s:ft2pat[a:ft]. '\|\V'. b:_foldmaker.fms[0] && line !~# b:_foldmaker.fms[1]
    return '='
  end
  return 0
endfunc
"}}}
function! s:avoid_lazy(ft, lnum, setting) abort "{{{
  let [b:_foldmaker.stack, b:_foldmaker.fms, b:_foldmaker.prelnum, line] = [[], [], a:lnum, getline(a:lnum)]
  if line =~ '^\s*$'
    return '='
  end
  let ufm = get(a:setting, 'use_foldmarker', g:foldmaker#use_foldmarker)
  let b:_foldmaker.fms = ufm ? split(escape(&foldmarker, '\'), ',') : []
  if !(!ufm ? line =~# s:ft2pat[a:ft] : line =~# s:ft2pat[a:ft]. '\|\V'. b:_foldmaker.fms[0] && line !~# b:_foldmaker.fms[1])
    return indent(a:lnum)==0 && indent(prevnonblank(a:lnum-1))==0 ? 0 : '='
  end
  let b:_foldmaker.stack = [a:lnum]
  if a:lnum == b:_foldmaker._lazy.fb_row
    return b:_foldmaker._lazy.fb_mark
  end
  unlet! b:_foldmaker._lazy
  return indent(a:lnum)==0 ? '>1' : '='
endfunc
"}}}
function! s:core__samelevel(ft, lnum, setting) abort "{{{
  let line = getline(a:lnum)
  if line =~ '^\s*$'
    return '='
  end
  let [idt, stack] = [indent(a:lnum), b:_foldmaker.stack]
  if stack!=[] && stack[0] >= a:lnum
    call remove(stack, 0, -1)
  end
  let i = 0
  while stack!=[] && idt <= indent(stack[0])
    call remove(stack, 0)
    let i += 1
  endwhile
  let fms = b:_foldmaker.fms
  if fms==[] ? line =~# s:ft2pat[a:ft] : line =~# s:ft2pat[a:ft]. '\|\V'. fms[0] && line !~# fms[1]
    if idt==0
      let b:_foldmaker.stack = [a:lnum]
      return '>1'
    end
    call insert(stack, a:lnum)
    return i ? '>'. len(stack) : 'a1'
  end
  return i ? (idt==0 ? '<1' : 's'. i) : (idt==0 ? 0 : '=')
endfunc
"}}}
function! s:core__pylike(ft, lnum, setting) abort "{{{
  let line = getline(a:lnum)
  if line =~ '^\s*$'
    return '='
  end
  let [idt, stack] = [indent(a:lnum), b:_foldmaker.stack]
  if stack!=[] && stack[0] >= a:lnum
    call remove(stack, 0, -1)
  end
  let fms = b:_foldmaker.fms
  if fms==[] ? line =~# s:ft2pat[a:ft] : line =~# s:ft2pat[a:ft]. '\|\V'. fms[0] && line !~# fms[1]
    if idt==0
      let b:_foldmaker.stack = [a:lnum]
      return '>1'
    end
    call insert(stack, a:lnum)
    return 'a1'
  end
  let [nidt, i] = [indent(nextnonblank(a:lnum+1)), 0]
  while stack!=[] && nidt <= indent(stack[0])
    call remove(stack, 0)
    let i += 1
  endwhile
  return i ? ('s'. i) : (idt==0 ? 0 : '=')
endfunc
"}}}

function! foldmaker#begin_lazy() abort "{{{
  let setting = g:foldmaker[&ft]
  let ufm = get(setting, 'use_foldmarker', g:foldmaker#use_foldmarker)
  if ufm
    let fms = split(escape(&foldmarker, '\'), ',')
    let pat = '\%('. join(setting.start_pats, '\m\)\|\%('). '\)\|\V'. fms[0]
  else
    let pat = '\%('. join(setting.start_pats, '\m\)\|\%('). '\)'
  end
  let crrrow = line('.')
  let lv0row = crrrow-1
  while lv0row > 1 && (indent(lv0row) > 0 || getline(lv0row) == '')
    let lv0row -= 1
  endwhile
  let lines = getline(lv0row, crrrow)
  let i = match(lines, pat)
  if lv0row==0 || i == -1
    return
  end
  let [fb_row, fb_mark, flv, len] = [lv0row+i, '>1', 1, crrrow-lv0row+1]
  let idts = [indent(fb_row)]
  let i += 1
  while i < len
    if lines[i] =~ '^\s*$'
      let i += 1
      continue
    end
    let idt = indent(lv0row+i)
    let is_fa = lines[i] =~# pat && !(ufm && lines[i] =~# fms[1])
    let is_fe = idts!=[] && idt <= idts[-1]
    if is_fa && is_fe
      call remove(idts, -1)
      while idts!=[] && idt <= idts[-1]
        call remove(idts, -1)
      endwhile
      call add(idts, idt)
      let flv = len(idts)
      let [fb_row, fb_mark] = [lv0row+i, '>'. flv]
    elseif is_fa
      call add(idts, idt)
      let flv += 1
      let [fb_row, fb_mark] = [lv0row+i, '>'. flv]
    elseif is_fe
      call remove(idts, -1)
      while idts!=[] && idt <= idts[-1]
        call remove(idts, -1)
      endwhile
      let flv = len(idts)
    end
    let i += 1
  endwhile
  let b:_foldmaker._lazy = {'fb_row': fb_row, 'fb_mark': fb_mark}
endfunc
"}}}
function! foldmaker#finish_lazy() abort "{{{
  if exists('b:_foldmaker') && has_key(b:_foldmaker, '_lazy')
    unlet b:_foldmaker._lazy
  end
endfunc
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
