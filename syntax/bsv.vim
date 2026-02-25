" syntax/bsv.vim
" Fallback regex-based syntax highlighting for Bluespec SystemVerilog (BSV).
" This is intentionally conservative. Tree-sitter highlighting is preferred.

if exists("b:current_syntax")
  finish
endif

" Comments
syn match  bsvLineComment  "//.*$"
syn region bsvBlockComment start="/\*" end="\*/" contains=bsvBlockComment
" BSV attribute / pragma blocks: (* ... *)
syn region bsvPragma start="(\*" end="\*)" keepend

" Strings
syn region bsvString start=+"+ skip=+\\."+ end=+"+ keepend

" Numbers (simple)
syn match bsvNumber "\v<\d+>"
syn match bsvNumber "\v<\d+'\s*[sS]?[bBoOdDhH]\s*[0-9a-fA-F_xXzZ?]+>"
syn match bsvFloat  "\v<\d+\.\d+([eE][+-]?\d+)?>"

" Preprocessor / compiler directives (backtick)
syn match bsvPreProc "\v^\s*`(include|define|undef|ifdef|ifndef|elsif|else|endif)\b.*$"

" System tasks/functions (e.g. $display)
syn match bsvSystemTask "\v\$\h\w*"

" Keywords (BSV-centric; includes some SV control words)
syn keyword bsvKeyword
      \ package endpackage import export
      \ module endmodule interface endinterface
      \ method endmethod function endfunction
      \ rule endrule rules endrules
      \ action endaction actionvalue endactionvalue
      \ begin end
      \ if else case endcase default
      \ for while repeat forever break continue return
      \ let match matches
      \ typedef struct enum tagged union
      \ typeclass endtypeclass instance endinstance
      \ provisos dependencies determines deriving
      \ seq endseq par endpar
      \ clocked_by reset_by default_clock default_reset
      \ input_clock input_reset output_clock output_reset

" Built-in types (seeded from VS Code grammar)
syn keyword bsvType
      \ void Action ActionValue Integer Nat Real Inout
      \ Bit UInt Int Bool Maybe String Either Rules Module
      \ Clock Reset Power Empty Array
      \ Reg RWire Wire BypassWire DWire PulseWire ReadOnly WriteOnly
      \ Vector List RegFile FIFO FIFOF Stmt

" Typeclasses and type-level math (seeded from VS Code grammar)
syn keyword bsvTypeClass
      \ Bits DefaultValue Eq Ord Bounded Arith Literal Bitwise BitReduction BitExtend FShow IsModule
      \ Add Max Log Mul Div TAdd TSub TLog TExp TMul TDiv TMin TMax

syn keyword bsvBoolean True False

" Operators (SAFE VERSION)
syn match bsvOperator "=="
syn match bsvOperator "!="
syn match bsvOperator "<="
syn match bsvOperator ">="
syn match bsvOperator "<-"
syn match bsvOperator "<<"
syn match bsvOperator ">>"

syn match bsvOperator "="
syn match bsvOperator "<"
syn match bsvOperator ">"

syn match bsvOperator "&&&"
syn match bsvOperator "&&"
syn match bsvOperator "||"

syn match bsvOperator "+"
syn match bsvOperator "-"
syn match bsvOperator "*"
syn match bsvOperator "/"
syn match bsvOperator "%"
syn match bsvOperator "^"
syn match bsvOperator "~"
syn match bsvOperator "!"
syn match bsvOperator "&"
syn match bsvOperator "|"
syn match bsvOperator "?"
syn match bsvOperator ":"

" Highlight links
hi def link bsvLineComment   Comment
hi def link bsvBlockComment  Comment
hi def link bsvPragma        PreProc
hi def link bsvString        String
hi def link bsvNumber        Number
hi def link bsvFloat         Float
hi def link bsvPreProc       PreProc
hi def link bsvSystemTask    Function
hi def link bsvKeyword       Keyword
hi def link bsvType          Type
hi def link bsvTypeClass     Type
hi def link bsvBoolean       Boolean
hi def link bsvOperator      Operator

let b:current_syntax = "bsv"
