if exists("b:current_syntax")
  finish
endif

syntax case match

syntax keyword bsvKeyword action actionvalue ancestor begin bit case clocked_by default
syntax keyword bsvKeyword default_clock default_reset dependencies deriving determines else
syntax keyword bsvKeyword enable enum export for function if ifc_inout import inout input_clock
syntax keyword bsvKeyword input_reset instance interface let match matches method module numeric
syntax keyword bsvKeyword output_clock output_reset package parameter path port provisos reset_by
syntax keyword bsvKeyword return rule rules same_family schedule struct tagged type typeclass
syntax keyword bsvKeyword typedef union valueOf valueof void while

syntax keyword bsvEnd end endaction endactionvalue endcase endfunction endinstance endinterface
syntax keyword bsvEnd endmethod endmodule endpackage endrule endrules endtypeclass

syntax keyword bsvBuiltinType Action ActionValue BVI C CF SB SBR Bool Bit Int UInt Integer
syntax keyword bsvBuiltinType Nat Real String Clock Reset Inout Reg Maybe Vector Tuple
syntax keyword bsvBuiltinType FIFO FIFOF Get Put Client Server

syntax keyword bsvBoolean True False

syntax keyword bsvSystemVerilogReserved alias always always_comb always_ff always_latch and
syntax keyword bsvSystemVerilogReserved assert assign assume automatic before bind bins binsof
syntax keyword bsvSystemVerilogReserved break buf bufif0 bufif1 byte casex casez cell chandle
syntax keyword bsvSystemVerilogReserved class clocking cmos config const constraint context
syntax keyword bsvSystemVerilogReserved continue cover covergroup coverpoint cross deassign
syntax keyword bsvSystemVerilogReserved defparam design disable dist do edge event expect
syntax keyword bsvSystemVerilogReserved extends extern final first_match force foreach forever
syntax keyword bsvSystemVerilogReserved fork forkjoin generate genvar highz0 highz1 iff ifnone
syntax keyword bsvSystemVerilogReserved ignore_bins illegal_bins incdir include initial input
syntax keyword bsvSystemVerilogReserved inside intersect join join_any join_none large liblist
syntax keyword bsvSystemVerilogReserved library local localparam logic longint macromodule medium
syntax keyword bsvSystemVerilogReserved modport nand negedge new nmos nor noshowcancelled not
syntax keyword bsvSystemVerilogReserved notif0 notif1 null or output packed pmos posedge primitive
syntax keyword bsvSystemVerilogReserved priority program property protected pull0 pull1 pulldown
syntax keyword bsvSystemVerilogReserved pullup pulsestyle_onevent pulsestyle_ondetect pure rand
syntax keyword bsvSystemVerilogReserved randc randcase randsequence rcmos real realtime ref reg
syntax keyword bsvSystemVerilogReserved release repeat rnmos rpmos rtran rtranif0 rtranif1 scalared
syntax keyword bsvSystemVerilogReserved sequence shortint shortreal showcancelled signed small
syntax keyword bsvSystemVerilogReserved solve specify specparam static string strong0 strong1
syntax keyword bsvSystemVerilogReserved super supply0 supply1 table task this throughout time
syntax keyword bsvSystemVerilogReserved timeprecision timeunit tran tranif0 tranif1 tri tri0 tri1
syntax keyword bsvSystemVerilogReserved triand trior trireg unique unsigned use var vectored
syntax keyword bsvSystemVerilogReserved virtual wait wait_order wand weak0 weak1 wildcard wire
syntax keyword bsvSystemVerilogReserved with within wor xnor xor

syntax match bsvDirective "`[A-Za-z_][A-Za-z0-9_$]*"
syntax match bsvSystemTask "\$[A-Za-z_][A-Za-z0-9_$]*"

syntax match bsvNumber "\v<\d*'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+>"
syntax match bsvNumber "\v<'[01]>"
syntax match bsvNumber "\v<\d+\.\d*([eE][+-]?\d+)?>"
syntax match bsvNumber "\v<\d+>"

syntax region bsvString start=+"+ skip=+\\\\\|\\"+ end=+"+
syntax region bsvAttribute start="(\*" end="\*)" contains=bsvString,bsvNumber,bsvKeyword

syntax match bsvOperator "<-"
syntax match bsvOperator "<="
syntax match bsvOperator ">="
syntax match bsvOperator "=="
syntax match bsvOperator "!="
syntax match bsvOperator "&&"
syntax match bsvOperator "||"
syntax match bsvOperator "<<"
syntax match bsvOperator ">>"
syntax match bsvOperator "<<<"
syntax match bsvOperator ">>>"
syntax match bsvOperator "\V~^"
syntax match bsvOperator "\V^~"
syntax match bsvOperator "[=+\-*/%&|^~?:<>]"

syntax region bsvComment start="/\*" end="\*/" keepend contains=bsvTodo
syntax match bsvComment "//.*$" contains=bsvTodo
syntax keyword bsvTodo TODO FIXME NOTE XXX contained

highlight default link bsvKeyword Keyword
highlight default link bsvEnd Keyword
highlight default link bsvBuiltinType Type
highlight default link bsvBoolean Boolean
highlight default link bsvSystemVerilogReserved Keyword
highlight default link bsvDirective PreProc
highlight default link bsvSystemTask Function
highlight default link bsvNumber Number
highlight default link bsvString String
highlight default link bsvComment Comment
highlight default link bsvTodo Todo
highlight default link bsvAttribute PreProc
highlight default link bsvOperator Operator

let b:current_syntax = "bsv"
