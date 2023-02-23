if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:ft2ftprc = {}
let s:save_raw = {}
function! s:init_bvar(prac, ...) abort "{{{ a:1=PreLnum
  let marker_used = a:prac.use_marker || g:foldmaker#use_marker
  let qret = {'USE_MARKER': a:prac.use_marker, 'marker_used': marker_used, 'mkrpat': '', 'INDEP_PAT': a:prac.indep_pat, 'PreLnum': a:0 ? a:1 : 0, 'InLazy': 0}
  if marker_used
    let fmrs = split(escape(&foldmarker, '\'), ',')
    let qret.mkrpat = '^\%(.\{-}'. fmrs[0]. '\)\@=\%(.\{-}'. fmrs[1]. '\)\@!'
    let qret.INDEP_PAT .= '\|'. qret.mkrpat
  end
  return [qret, {'Dfs': [], 'Lv': 0, 'Idts': [], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [], 'IfrDfses': []}]
endfunc
"}}}
function! s:reinit(ft) abort "{{{
  if has_key(s:save_raw, a:ft)
    unlet s:save_raw[a:ft]
  end
  if has_key(s:ft2ftprc, a:ft)
    unlet s:ft2ftprc[a:ft]
  end
  return foldmaker#_init_([a:ft])
endfunc
"}}}

function! s:get_inheritee(settings, ft, ihr_log, ship) abort "{{{ -> Qship: {use_marker, fdtype, foldings}
  if !has_key(a:settings, a:ft)
    throw printf('foldmarker: invalid inheritance: "%s" key not exists in g:foldmarker.', a:ft)
  elseif has_key(a:ihr_log, a:ft)
    throw printf('foldmarker: circular inheritance: `%s`', join(keys(a:ihr_log), ','))
  end
  let a:ihr_log[(a:ft)] = 1
  let ftd = a:settings[(a:ft)]
  let a:ship.use_marker = a:ship.use_marker is '' ? get(ftd, 'use_marker', '') : a:ship.use_marker
  let a:ship.fdtype = a:ship.fdtype is '' ? get(ftd, 'fdtype', '') : a:ship.fdtype
  let foldings = get(ftd, 'foldings', {})
  if !has_key(ftd, 'inherit')
    return foldings
  end
  let qfoldings = s:get_inheritee(a:settings, ftd.inherit, a:ihr_log, a:ship)
  return foldings=={} ? qfoldings : qfoldings=={} ? foldings : extend(deepcopy(qfoldings), foldings)
endfunc
"}}}
function! s:multift_into_ft_practical(fts) abort "{{{
  let fts = []
  for ft in a:fts
    if has_key(s:ft2ftprc, ft)
      let fts += [ft]
    end
  endfor
  if len(fts)==1
    return s:ft2ftprc[fts[0]]
  end
  let pracs = map(fts, 's:ft2ftprc[(v:val)]')
  let use_marker = ''
  let indep_dfs = []
  let indep_pats = []
  let ntpstart_pats = []
  let stpstart_pats = []
  let fdtype = pracs[0].fdtype
  for prac in pracs
    if prac.fdtype !=# fdtype
      echoerr printf('foldmaker: 複合filetype の fdtype が異なるため %s の定義を使います', prac._ft)
      return pracs[0]
    end
    let use_marker = prac.use_marker is '' ? use_marker : use_marker is '' || use_marker ? prac.use_marker : 0
    let indep_dfs += prac.indep_dfs
    let indep_pats += [prac.indep_pat]
    let ntpstart_pats += [prac.ntpstart_pat]
    let stpstart_pats += [prac.stpstart_pat]
  endfor
  return {'fdtype': fdtype, 'use_marker': use_marker, 'indep_dfs': indep_dfs, 'indep_pat': join(indep_pats, '\|'), 'ntpstart_pat': join(ntpstart_pats, '\|') 'stpstart_pat': join(stpstart_pats, '\|')}
endfunc
"}}}
function! s:build_ft_practical(foldings, ship, ft) abort "{{{
  let indep_pats = []
  let indep_dfs = []
  let stpstart_pats = []
  let ntpstart_pats = []
  let fd2df_all = {}
  let fd2df_stop = {}
  let children = []
  let inferiors = []
  let prefix = a:ft. ':'
  let dfl_setg = {'start': '', 'cancel': '', 'nonstop': '', 'stop': '', 'parents': [], 'superiors': [], 'is_visible': 1}
  for [name, fd] in items(a:foldings)
    let s:procg_fd = name
    let qfd = extend(fd, dfl_setg, 'keep')
    if qfd.start==''
      continue
    elseif "\x00" =~# qfd.start
      throw printf('`foldings.%s.start` is invalid pattern: `%s`', name, qfd.start)
    end
    let qname = prefix. name
    let df = {'start': qfd.start, 'cancel': '', 'nonstop': qfd.nonstop, 'stop': qfd.stop, 'is_visible': qfd.is_visible, 'chlpat': '', 'chl_dfs': [], 'qifrpat': '', 'ifr_dfs': []}
    let fd2df_all[qname] = df
    if df.stop!=''
      let stpstart_pats += [df.start]
    elseif df.nonstop!=''
      let ntpstart_pats += [df.start]
    end
    if qfd.parents!=[]
      let children += [[qname, prefix, qfd.parents]]
    elseif qfd.superiors!=[]
      let inferiors += [[qname, prefix, qfd.superiors]]
    else
      let indep_pats += [qfd.start]
      let indep_dfs += [df]
    end
  endfor
  let s:procg_fd = ''
  let pdfs = []
  for [chlname, prefix, parents] in children
    for p in parents
      let df = fd2df_all[prefix. p]
      let df.chl_dfs += [fd2df_all[chlname]]
      let pdfs += [df]
    endfor
  endfor
  for df in pdfs
    let df.chlpat = join(map(copy(df.chl_dfs), 'v:val.start'), '\m\|')
  endfor
  let sdfs = []
  for [ifr_name, prefix, superiors] in inferiors
    for s in superiors
      let df = fd2df_all[prefix. s]
      let df.ifr_dfs += [fd2df_all[ifr_name]]
      let sdfs += [df]
    endfor
  endfor
  for df in sdfs
    let df.qifrpat = join(map(copy(df.ifr_dfs), 'v:val.start'), '\m\|'). '\m\|'
  endfor
  let bgnfmr = get(split(escape(&foldmarker, '\'), ','), 0, '')
  if a:ship.use_marker
    let start_pats += [bgnfmr]
  end
  return {'_ft': a:ft, 'fdtype': a:ship.fdtype==#'pylike' ? 'pylike' : 'samelevel', 'use_marker': a:ship.use_marker,
    \ 'indep_dfs': indep_dfs, 'indep_pat': '\%('. join(indep_pats, '\m\)\|\%('). '\m\)', 'ntpstart_pat': '\%('. join(ntpstart_pats, '\m\)\|\%('). '\m\)', 'stpstart_pat': '\%('. join(stpstart_pats, '\m\)\|\%('). '\m\)'}
endfunc
"}}}
" Df{'start', 'cancel', 'nonstop', 'stop': String; 'is_visible': Bool; 'chlpat': String; 'chl_dfs': Df[]; 'qifrpat': String; 'ifr_dfs': Df[]}
" Prac{'_ft': String; 'fdtype': 'pylike' | 'samelevel'; 'use_marker': Bool, 'indep_dfs': Df[], 'indep_pat', 'ntpstart_pat', 'stpstart_pat': String}
" NOTE: qifrpat には末尾に '\m\|' が付いているので使用時には除去する必要がある。

function! s:get_ifr_df(line, ifr_dfses) abort "{{{
  for dfs in a:ifr_dfses
    for df in dfs
      if a:line =~# df.start
        return df
      end
    endfor
  endfor
  throw printf('folding define is not found. line:`%s`, dfses:`%s`', a:line, string(a:ifr_dfses))
endfunc
"}}}

function! foldmaker#_init_(fts) abort "{{{
  let is_succeeded = 0
  for ft in a:fts
    let has_ftprc = has_key(s:ft2ftprc, ft)
    if has_ftprc || !has_key(g:foldmaker, ft)
      let is_succeeded = is_succeeded || has_ftprc
      continue
    end
    let d = g:foldmaker[ft]
    let ship = {'use_marker': get(d, 'use_marker', ''), 'fdtype': get(d, 'fdtype', '')}
    let foldings = get(d, 'foldings', {})
    if has_key(d, 'inherit')
      let qfoldings = s:get_inheritee(g:foldmaker, d.inherit, {ft: 1}, ship)
      if foldings=={} && has_key(s:ft2ftprc, d.inherit) && ship.fdtype==#s:ft2ftprc[d.inherit].fdtype && ship.use_marker==#s:ft2ftprc[d.inherit].use_marker
        let s:ft2ftprc[ft] = s:ft2ftprc[d.inherit]
        let s:save_raw[ft] = g:foldmaker[ft]
        continue
      end
      let foldings = extend(deepcopy(qfoldings), foldings)
    end
    if foldings=={}
      continue
    end
    let s:procg_fd = ''
    try
      let s:ft2ftprc[ft] = s:build_ft_practical(foldings, ship, ft)
    catch
      echoerr printf('%s: %s ..at filetype "%s" %s', v:throwpoint, v:exception, ft, s:procg_fd=='' ? '' : 'folding["'. s:procg_fd. '"]')
    finally
      unlet! s:procg_fd
    endtry
    let s:save_raw[ft] = g:foldmaker[ft]
    let is_succeeded = 1
  endfor
  if is_succeeded
    let s:save_use_marker = g:foldmaker#use_marker
    return 1
  end
endfunc
"}}}
function! foldmaker#_expr_(lnum, ft, fts) abort "{{{
  let reinited = 0
  for ft in a:fts
    if !has_key(g:foldmaker, ft) || g:foldmaker[ft] is# get(s:save_raw, ft, {})
      continue
    elseif !s:reinit(ft)
      return -1
    end
    let reinited = 1
  endfor
  if a:ft =~ '\.' && (!has_key(s:ft2ftprc, a:ft) || reinited)
    let s:ft2ftprc[(a:ft)] = s:multift_into_ft_practical(a:fts)
  end
  let prac = s:ft2ftprc[(a:ft)]
  let [b:_fdmaker, b:_fdmaker_fd] = a:lnum != 1 && exists('b:_fdmaker') ? [b:_fdmaker, b:_fdmaker_fd] : s:init_bvar(prac)

  if a:lnum - b:_fdmaker.PreLnum != 1
    return s:climb(a:lnum, prac)
  end
  let b:_fdmaker.PreLnum = a:lnum
  let line = getline(a:lnum)
  if line =~ '^\s*$'
    return '='
  elseif b:_fdmaker_fd.Dfs==[]
    return line !~# b:_fdmaker.INDEP_PAT ? 0 : s:first_lv_newfd(a:lnum, line, prac)
  end
  let df = b:_fdmaker_fd.Dfs[0]
  if df.stop!=''
    return line !~# df.stop ? '=' : s:at_stopfd_stop(df)
  end
  let case = b:_fdmaker_fd.ChlPat!='' && line =~# b:_fdmaker_fd.ChlPat ? 2 : b:_fdmaker_fd.IfrPat!='' && line =~# b:_fdmaker_fd.IfrPat ? 3 : line =~# b:_fdmaker.INDEP_PAT
  if !case
    return s:under_fd__{prac.fdtype}(a:lnum, line, df)
  elseif case==3
    let ndf = s:get_ifr_df(line, b:_fdmaker_fd.IfrDfses)
  else
    for ndf in case==2 ? df.chl_dfs : prac.indep_dfs
      if line =~# ndf.start
        break
      end
    endfor
  end " 2nd lv new folding
  let idt = indent(a:lnum)
  while b:_fdmaker_fd.Idts!=[] && idt <= b:_fdmaker_fd.Idts[0]
    let [ndfs, qifrpats] = [b:_fdmaker_fd.Dfs[1:], b:_fdmaker_fd.QIfrPats[1:]]
    let b:_fdmaker_fd = ndfs==[] ? {'Lv': 0, 'Dfs': [], 'Idts': [], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [], 'IfrDfses': []}
      \ : {'Lv': b:_fdmaker_fd.Lv - !!b:_fdmaker_fd.Dfs[0].is_visible, 'Dfs': ndfs, 'Idts': b:_fdmaker_fd.Idts[1:], 'ChlPat': ndfs[0].chlpat, 'IfrPat': join(qifrpats, '')[:-5], 'QIfrPats': qifrpats, 'IfrDfses': b:_fdmaker_fd.IfrDfses[1:]}
  endwhile
  if !(ndf.cancel=='' || line =~# ndf.cancel) || (ndf.stop!='' && line =~# ndf.stop)
    return b:_fdmaker.Lv
  end
  let qifrpats = [ndf.qifrpat] + b:_fdmaker_fd.QIfrPats
  let b:_fdmaker_fd = ndf.stop=='' ? {'Lv': b:_fdmaker_fd.Lv + !!ndf.is_visible, 'Dfs': [ndf] + b:_fdmaker_fd.Dfs, 'Idts': [idt] + b:_fdmaker_fd.Idts, 'ChlPat': ndf.chlpat, 'IfrPat': join(qifrpats, '')[:-5], 'QIfrPats': qifrpats, 'IfrDfses': [ndf.ifr_dfs] + b:_fdmaker_fd.IfrDfses}
    \ : {'Lv': b:_fdmaker_fd.Lv + !!ndf.is_visible, 'Dfs': [ndf] + b:_fdmaker_fd.Dfs, 'Idts': [idt] + b:_fdmaker_fd.Idts, 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [''] + b:_fdmaker_fd.QIfrPats, 'IfrDfses': [[]] + b:_fdmaker_fd.IfrDfses}
  return ndf.is_visible ? '>'. b:_fdmaker_fd.Lv : b:_fdmaker_fd.Lv
endfunc
"}}}
function! s:first_lv_newfd(lnum, line, prac) abort "{{{
  let found = 0
  for ndf in a:prac.indep_dfs
    if a:line =~# ndf.start
      let found = 1
      break
    end
  endfor
  if !found && b:_fdmaker.marker_used && a:line =~# b:_fdmaker.mkrpat
    let ndf = [{'start': b:_fdmaker.mkrpat, 'nonstop': '', 'stop': '', 'is_visible': 1, 'chlpat': '', 'chl_dfs': [], 'qifrpat': '', 'ifr_dfs': []}]
  end
  if !(ndf.cancel=='' || line =~# ndf.cancel) || (ndf.stop!='' && a:line =~# ndf.stop)
    return b:_fdmaker.Lv
  end
  let b:_fdmaker_fd = ndf.stop=='' ? {'Lv': !!ndf.is_visible, 'Dfs': [ndf], 'Idts': [indent(a:lnum)], 'ChlPat': ndf.chlpat, 'IfrPat': ndf.qifrpat[:-5], 'QIfrPats': [ndf.qifrpat], 'IfrDfses': [ndf.ifr_dfs]}
    \ : {'Lv': !!ndf.is_visible, 'Dfs': [ndf], 'Idts': [indent(a:lnum)], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [''], 'IfrDfses': [[]]}
  return ndf.is_visible ? '>1' : 0
endfunc
"}}}
function! s:at_stopfd_stop(df) abort "{{{
  let [ndfs, qifrpats] = [b:_fdmaker_fd.Dfs[1:], b:_fdmaker_fd.QIfrPats[1:]]
  let b:_fdmaker_fd = {'Lv': b:_fdmaker_fd.Lv - !!a:df.is_visible, 'Dfs': ndfs, 'Idts': b:_fdmaker_fd.Idts[1:], 'ChlPat': ndfs==[] ? '' : ndfs[0].chlpat, 'IfrPat': join(qifrpats, '')[:-5], 'QIfrPats': qifrpats, 'IfrDfses': b:_fdmaker_fd.IfrDfses[1:]}
  return a:df.is_visible ? '<'. (b:_fdmaker_fd.Lv+1) : b:_fdmaker_fd.Lv
endfunc
"}}}
function! s:under_fd__samelevel(lnum, line, df) abort "{{{
  let save_lv = b:_fdmaker_fd.Lv
  if a:df.nonstop=='' || a:line !~# a:df.nonstop
    let idt = indent(a:lnum)
    while b:_fdmaker_fd.Idts!=[] && idt <= b:_fdmaker_fd.Idts[0]
      let [ndfs, qifrpats] = [b:_fdmaker_fd.Dfs[1:], b:_fdmaker_fd.QIfrPats[1:]]
      let b:_fdmaker_fd = ndfs==[] ? {'Lv': 0, 'Dfs': [], 'Idts': [], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [], 'IfrDfses': []}
        \ : {'Lv': b:_fdmaker_fd.Lv - !!b:_fdmaker_fd.Dfs[0].is_visible, 'Dfs': ndfs, 'Idts': b:_fdmaker_fd.Idts[1:], 'ChlPat': ndfs[0].chlpat, 'IfrPat': join(qifrpats, '')[:-5], 'QIfrPats': qifrpats, 'IfrDfses': b:_fdmaker_fd.IfrDfses[1:]}
    endwhile
  end
  return b:_fdmaker_fd.Lv==save_lv ? save_lv : '<'. (b:_fdmaker_fd.Lv+1)
endfunc
"}}}
function! s:under_fd__pylike(lnum, line, df) abort "{{{
  let save_lv = b:_fdmaker_fd.Lv
  let nnbrow = nextnonblank(a:lnum+1)
  if nnbrow && (a:df.nonstop=='' || a:line !~# a:df.nonstop)
    let nidt = indent(nnbrow)
    while b:_fdmaker_fd.Idts!=[] && nidt <= b:_fdmaker_fd.Idts[0]
      let [ndfs, qifrpats] = [b:_fdmaker_fd.Dfs[1:], b:_fdmaker_fd.QIfrPats[1:]]
      let b:_fdmaker_fd = ndfs==[] ? {'Lv': 0, 'Dfs': [], 'Idts': [], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [], 'IfrDfses': []}
        \ : {'Lv': b:_fdmaker_fd.Lv - !!b:_fdmaker_fd.Dfs[0].is_visible, 'Dfs': ndfs, 'Idts': b:_fdmaker_fd.Idts[1:], 'ChlPat': ndfs[0].chlpat, 'IfrPat': join(qifrpats, '')[:-5], 'QIfrPats': qifrpats, 'IfrDfses': b:_fdmaker_fd.IfrDfses[1:]}
    endwhile
  end
  return b:_fdmaker_fd.Lv==save_lv ? save_lv : '<'. (b:_fdmaker_fd.Lv+1)
endfunc
"}}}

function! s:climb(lnum, prac) abort "{{{
  let b:_fdmaker.PreLnum = a:lnum
  let b:_fdmaker_fd = {'Dfs': [], 'Lv': 0, 'Idts': [], 'ChlPat': '', 'IfrPat': '', 'QIfrPats': [], 'IfrDfses': []}
  if !b:_fdmaker.USE_MARKER && b:_fdmaker.marker_used != g:foldmaker#use_marker
    let [b:_fdmaker, _] = s:init_bvar(a:prac, a:lnum)
  end
  let line = getline(a:lnum)
  if line !~# b:_fdmaker.INDEP_PAT
    return '='
  end
  let indep_dfs = !b:_fdmaker.marker_used ? a:prac.indep_dfs
    \ : a:prac.indep_dfs + [{'start': b:_fdmaker.mkrpat, 'nonstop': '', 'stop': '', 'is_visible': 1, 'chlpat': '', 'chl_dfs': [], 'qifrpat': '', 'ifr_dfs': []}]
  for df in indep_dfs
    if line =~# df.start
      break
    end
  endfor
  if !(df.cancel=='' || line =~# df.cancel)
    return '='
  end
  let lines = getline(1, a:lnum-1)
  if line =~ '^\S' && (a:prac.ntpstart_pat!='' || line !~# a:prac.ntpstart_pat) && a:prac.stpstart_pat!='' && match(lines, a:prac.stpstart_pat)==-1 || a:lnum==1
    let b:_fdmaker_fd = {'Lv': !!df.is_visible, 'Dfs': [df], 'Idts': [0], 'ChlPat': df.chlpat, 'IfrPat': df.qifrpat[:-5], 'QIfrPats': [df.qifrpat], 'IfrDfses': [df.ifr_dfs]}
    return df.is_visible ? '>1' : 0
  elseif !df.is_visible
    return '='
  end
  let [lv, ctxt] = s:calc_climbing_ctxt(lines, a:prac.indep_dfs, b:_fdmaker.INDEP_PAT)
  if ctxt=={}
    return '='
  end
  let crridt = indent(a:lnum)
  let idts = ctxt.idts
  let lv += idts==[] || crridt > idts[0]
  let b:_fdmaker_fd = {'Lv': lv, 'Dfs': [df] + ctxt.dfs, 'Idts': [crridt] + idts, 'ChlPat': df.chlpat,
    \ 'IfrPat': (df.qifrpat. ctxt.qifrpat)[:-5], 'QIfrPats': [df.qifrpat] + ctxt.qifrpats, 'IfrDfses': [df.ifr_dfs] + ctxt.ifr_dfses}
  return '>'. lv
endfunc
"}}}
" 現在行が INDEP_PAT にマッチするのを前提として、先頭から a:lines をなめて現在行の lv と ctxt を返す
function! s:calc_climbing_ctxt(lines, indep_dfs, indep_pat) abort "{{{ -> lv: Number, ctxt: ({'dfs': Df[]; 'idts': Number; 'qifrpats': String[]; 'qifrpat': String; 'ifr_dfses': Df[][]} | {})
  let lv = 0
  let dfs = []
  let idts = []
  let chl_dfs = []
  let chlpats = ['']
  let ifr_dfses = []
  let qifrpats = []
  let chlpat = ''
  let ifrpat = ''
  let qifrpat = ''
  let gpat = a:indep_pat
  let i = match(a:lines, gpat)
  while i!=-1
    let line = a:lines[i]
    let idt = indent(i+1)
    let case = chlpat!='' && line =~# chlpat ? 2 : qifrpat!='' && line =~# qifrpat[:-5] ? 3 : line =~# a:indep_pat
    if !case
      if dfs[0].nonstop=='' || line !~# dfs[0].nonstop
        while idts!=[] && idt <= idts[0]
          let lv -= !!lv
          let [dfs, idts, chl_dfs, chlpats, qifrpats, ifr_dfses] = [dfs[1:], idts[1:], chl_dfs[1:], chlpats[1:], qifrpats[1:], ifr_dfses[1:]]
          let [qifrpat, chlpat] = [join(qifrpats, ''), chlpats[0]]
          let gpat = dfs==[] ? a:indep_pat : chlpat. qifrpat. a:indep_pat. '\m\|\%<'. (idt+1). 'v\S'
        endwhile
      endif
      let i = match(a:lines, gpat, i+1)
      continue
    elseif case==3
      let df = s:get_ifr_df(line, ifr_dfses)
    else
      for df in case==2 ? chl_dfs[0] : a:indep_dfs
        if line =~# df.start
          break
        end
      endfor
    end
    let lv -= idts!=[] && idt <= idts[0] ? 1 : 0
    if !(df.cancel=='' || line =~# df.cancel)
      let i = match(a:lines, gpat, i+1)
      continue
    elseif df.stop!=''
      let last = match(a:lines, df.stop, i)
      if last==-1
        return [lv, {}]
      end
      let i = match(a:lines, gpat, last+1)
      continue
    end
    let lv += !!df.is_visible
    let dfs = [df] + dfs
    let idts = [idt] + idts
    let chl_dfs = [df.chl_dfs] + chl_dfs
    let chlpats = [df.chlpat] + chlpats
    let ifr_dfses = [df.ifr_dfs] + ifr_dfses
    let qifrpats = [df.qifrpat] + qifrpats
    let chlpat = df.chlpat
    let qifrpat = (df.qifrpat. qifrpat)
    let gpat = (chlpat=='' ? '' : chlpat. '\m\|'). qifrpat. a:indep_pat. '\m\|\%<'. (idt+1). 'v\S'
    let i = match(a:lines, gpat, i+1)
  endwhile
  return [lv, {'dfs': dfs, 'idts': idts, 'qifrpats': qifrpats, 'qifrpat': qifrpat, 'ifr_dfses': ifr_dfses}]
endfunc
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
