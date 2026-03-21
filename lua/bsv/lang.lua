local M = {}

local function set(items)
  local out = {}
  for _, item in ipairs(items) do
    out[item] = true
  end
  return out
end

M.preproc_directives = {
  "include",
  "line",
  "define",
  "undef",
  "ifdef",
  "ifndef",
  "elsif",
  "else",
  "endif",
  "resetall",
}

M.core_keywords = {
  "package",
  "endpackage",
  "import",
  "export",
  "module",
  "endmodule",
  "interface",
  "endinterface",
  "method",
  "endmethod",
  "function",
  "endfunction",
  "rule",
  "endrule",
  "rules",
  "endrules",
  "action",
  "endaction",
  "actionvalue",
  "endactionvalue",
  "begin",
  "end",
  "if",
  "else",
  "case",
  "endcase",
  "default",
  "matches",
  "match",
  "for",
  "while",
  "repeat",
  "forever",
  "return",
  "break",
  "continue",
  "let",
  "typedef",
  "struct",
  "enum",
  "tagged",
  "union",
  "deriving",
  "numeric",
  "type",
  "typeclass",
  "endtypeclass",
  "instance",
  "endinstance",
  "provisos",
  "dependencies",
  "determines",
  "seq",
  "endseq",
  "par",
  "endpar",
  "clocked_by",
  "reset_by",
  "default_clock",
  "default_reset",
  "input_clock",
  "input_reset",
  "output_clock",
  "output_reset",
  "ancestor",
  "parameter",
  "port",
  "path",
  "ready",
  "enable",
  "schedule",
  "same_family",
  "BVI",
  "C",
  "CF",
  "E",
  "SB",
  "SBR",
}

M.keyword_set = set(M.core_keywords)

M.decl_openers = set({
  "package",
  "module",
  "interface",
  "function",
  "typeclass",
  "instance",
  "method",
  "action",
  "actionvalue",
  "rule",
})

M.decl_closers = set({
  "endpackage",
  "endmodule",
  "endinterface",
  "endfunction",
  "endtypeclass",
  "endinstance",
  "endmethod",
  "endaction",
  "endactionvalue",
  "endrule",
})

M.block_openers = set({
  "begin",
  "action",
  "actionvalue",
  "seq",
  "par",
  "case",
  "rules",
})

M.block_closers = set({
  "end",
  "endaction",
  "endactionvalue",
  "endseq",
  "endpar",
  "endcase",
  "endrules",
})

M.trailing_block_openers = set({
  "begin",
  "action",
  "actionvalue",
  "seq",
  "par",
})

M.control_keywords = set({
  "if",
  "for",
  "while",
  "case",
})

M.paren_keywords = set({
  "if",
  "for",
  "while",
  "case",
})

M.types = {
  "Action",
  "ActionValue",
  "Array",
  "Bit",
  "Bool",
  "BypassWire",
  "Clock",
  "DWire",
  "Either",
  "Empty",
  "FIFO",
  "FIFOF",
  "Inout",
  "Int",
  "Integer",
  "List",
  "Maybe",
  "Module",
  "Nat",
  "Power",
  "PulseWire",
  "ReadOnly",
  "Real",
  "Reg",
  "RegFile",
  "Reset",
  "RWire",
  "Rules",
  "Stmt",
  "String",
  "UInt",
  "Vector",
  "Wire",
  "WriteOnly",
  "void",
}

M.type_set = set(M.types)

M.typeclasses = {
  "Add",
  "Arith",
  "BitExtend",
  "BitReduction",
  "Bits",
  "Bitwise",
  "Bounded",
  "DefaultValue",
  "Div",
  "Eq",
  "FShow",
  "IsModule",
  "Literal",
  "Log",
  "Max",
  "Min",
  "Mul",
  "Ord",
  "RealLiteral",
  "SizedLiteral",
  "TAdd",
  "TDiv",
  "TExp",
  "TLog",
  "TMax",
  "TMin",
  "TMul",
  "TSub",
}

M.typeclass_set = set(M.typeclasses)

M.constants = {
  "True",
  "False",
}

M.constant_set = set(M.constants)

M.builtin_functions = {
  "fromInteger",
  "fromReal",
  "fromSizedInteger",
  "fromString",
  "noAction",
  "pack",
  "unpack",
  "valueOf",
  "valueof",
}

M.builtin_function_set = set(M.builtin_functions)

M.protected_ops = {
  ["<-"] = "\1",
  ["<="] = "\2",
  [">="] = "\3",
  ["=="] = "\4",
  ["!="] = "\5",
  ["&&"] = "\6",
  ["||"] = "\7",
  ["<<"] = "\8",
  [">>"] = "\9",
  ["&&&"] = "\10",
  ["~&"] = "\11",
  ["~|"] = "\12",
  ["^~"] = "\13",
  ["~^"] = "\14",
}

M.spaced_single_char_ops = {
  "+",
  "*",
  "/",
  "%",
  "<",
  ">",
}

M.default_indentkeys = table.concat({
  "0=end",
  "0=endaction",
  "0=endactionvalue",
  "0=endseq",
  "0=endpar",
  "0=endcase",
  "0=endrules",
  "0=endpackage",
  "0=endmodule",
  "0=endinterface",
  "0=endrule",
  "0=endfunction",
  "0=endtypeclass",
  "0=endinstance",
  "0=}",
}, ",")

return M
