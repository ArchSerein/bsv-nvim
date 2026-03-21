(comment) @comment @spell

(intLiteral) @number
(realLiteral) @number.float
(stringLiteral) @string

(typeIde) @type
(typeNat) @number
(typeclassIde) @type

(exprPrimary
  "." (identifier) @property)

(lValue
  "." (identifier) @property)

(exprPrimary
  (Identifier) @constant)

(structMember
  (identifier) @field)

(unionMember
  (Identifier) @field)

(structExpr
  (Identifier) @type)

(taggedUnionExpr
  (Identifier) @type)

(taggedUnionPattern
  (Identifier) @type)

(memberBind
  (identifier) @property)

(typedefEnum
  (Identifier) @type)

(typedefEnumElement
  (Identifier) @constant)

(attrName
  (identifier) @attribute)

(typeFormal
  (typeIde (identifier) @parameter))

(subinterfaceDef
  (Identifier) @type)

(proviso
  (Identifier) @type)

(moduleProto
  (identifier) @constructor)

(moduleFormalParam
  (identifier) @parameter)

(moduleApp
  (identifier) @constructor)

(functionProto
  (identifier) @function)

(functionAssign
  (identifier) @function)

(functionFormal
  (identifier) @parameter)

(functionCall
  (exprPrimary (identifier) @function.call))

(systemTaskStmt
  (displayTaskName) @function.builtin)

(systemTaskStmt
  (dollarIdentifier) @function.call)

(systemFunctionCall) @function.call

(methodProto
  (identifier) @function)

(methodProtoFormal
  (identifier) @parameter)

(methodDef
  (identifier) @function)

(methodFormal
  (identifier) @parameter)
