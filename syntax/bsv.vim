if exists("b:current_syntax")
  finish
endif

let s:lang = luaeval('require("bsv.lang")')

function! s:define_keywords(group, words) abort
  if empty(a:words)
    return
  endif
  execute 'syn keyword ' . a:group . ' ' . join(a:words, ' ')
endfunction

syn match  bsvLineComment  "//.*$"
syn region bsvBlockComment start="/\*" end="\*/" keepend
syn region bsvPragma start="(\*" end="\*)" keepend

syn region bsvString start=+"+ skip=+\\.+ end=+"+ keepend

syn match bsvNumber "\\v<\\d+'\\s*[sS]?[bBoOdDhH]\\s*[0-9a-fA-F_xXzZ?]+>"
syn match bsvNumber "\\v<'[01]>"
syn match bsvNumber "\\v<[-+]?\\d[\\d_]*>"
syn match bsvFloat  "\\v<\\d[\\d_]*\\.\\d[\\d_]*([eE][+-]?\\d[\\d_]*)?>"

syn match bsvPreProc "\\v`(include|line|define|undef|ifdef|ifndef|elsif|else|endif|resetall)\\>"
syn match bsvSystemTask "\\v\\$[A-Za-z_][A-Za-z0-9_$]*"
syn match bsvBuiltin "\\v<(pack|unpack|fromInteger|fromSizedInteger|fromReal|fromString|noAction|valueOf|valueof)>"

call s:define_keywords('bsvKeyword', s:lang.core_keywords)
call s:define_keywords('bsvType', s:lang.types)
call s:define_keywords('bsvTypeClass', s:lang.typeclasses)
call s:define_keywords('bsvBoolean', s:lang.constants)

syn match bsvOperator "==\|!=\|<=\|>=\|<-\|<<\|>>\|&&&\|&&\|||\|~&\|~|\|\^~\|~\^\|::"
syn match bsvOperator "+\|-\|\*\|/\|%\|=\|<\|>\|\^\|~\|!\|&\||\|?\|:"

hi def link bsvLineComment Comment
hi def link bsvBlockComment Comment
hi def link bsvPragma PreProc
hi def link bsvString String
hi def link bsvNumber Number
hi def link bsvFloat Float
hi def link bsvPreProc PreProc
hi def link bsvSystemTask Function
hi def link bsvBuiltin Function
hi def link bsvKeyword Keyword
hi def link bsvType Type
hi def link bsvTypeClass Type
hi def link bsvBoolean Boolean
hi def link bsvOperator Operator

let b:current_syntax = "bsv"
