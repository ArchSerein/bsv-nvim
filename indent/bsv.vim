if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=<SID>GetBSVIndent(v:lnum)
setlocal indentkeys+=0=end,0=endaction,0=endactionvalue,0=endcase,0=endfunction
setlocal indentkeys+=0=endinstance,0=endinterface,0=endmethod,0=endmodule
setlocal indentkeys+=0=endpackage,0=endrule,0=endrules,0=endtypeclass,0=else

let b:undo_indent = "setlocal autoindent< indentexpr< indentkeys<"

function! s:StripComments(line) abort
  let code = a:line
  let code = substitute(code, '/\*.\{-}\*/', ' ', 'g')
  let code = substitute(code, '//.*$', '', '')
  let code = substitute(code, '/\*.*$', '', '')
  return code
endfunction

function! s:IsCommentOnlyOrBlank(line) abort
  if a:line =~# '^\s*\*' || a:line =~# '^\s*\*/'
    return 1
  endif
  return s:StripComments(a:line) =~# '^\s*$'
endfunction

function! s:PrevCodeLine(lnum) abort
  let lnum = a:lnum - 1
  while lnum > 0
    let line = getline(lnum)
    if !s:IsCommentOnlyOrBlank(line)
      return lnum
    endif
    let lnum -= 1
  endwhile
  return 0
endfunction

function! s:StartsWithCloser(line) abort
  return a:line =~# '^\s*\(end\|endaction\|endactionvalue\|endcase\|endfunction\|endinstance\|endinterface\|endmodule\|endmethod\|endpackage\|endrule\|endrules\|endtypeclass\)\>'
endfunction

function! s:StartsWithElse(line) abort
  return a:line =~# '^\s*else\>'
endfunction

function! s:OpensBlock(line) abort
  let code = s:StripComments(a:line)
  if code =~# '\<\(package\|module\|interface\|function\|instance\|typeclass\|rule\|rules\|action\|actionvalue\|begin\|case\)\>'
        \ && code !~# '\<\(endmodule\|endinterface\|endfunction\|endinstance\|endtypeclass\|endrule\|endrules\|endaction\|endactionvalue\|endcase\|end\)\>'
    return 1
  endif
  if code =~# '\<method\>' && code !~# '\<endmethod\>'
    return 1
  endif
  if code =~# '(\s*$' || code =~# ',\s*$' || code =~# '\<provisos\s*(\s*$'
    return 1
  endif
  return 0
endfunction

function! s:GetBSVIndent(lnum) abort
  let line = s:StripComments(getline(a:lnum))
  let prev_lnum = s:PrevCodeLine(a:lnum)
  if prev_lnum == 0
    return 0
  endif

  let ind = indent(prev_lnum)
  let prev = s:StripComments(getline(prev_lnum))

  if s:OpensBlock(prev)
    let ind += shiftwidth()
  endif

  if s:StartsWithCloser(line) || s:StartsWithElse(line)
    let ind -= shiftwidth()
  endif

  return max([ind, 0])
endfunction
