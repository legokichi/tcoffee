# The CoffeeScript parser is generated by [Jison](http://github.com/zaach/jison)
# from this grammar file. Jison is a bottom-up parser generator, similar in
# style to [Bison](http://www.gnu.org/software/bison), implemented in JavaScript.
# It can recognize [LALR(1), LR(0), SLR(1), and LR(1)](http://en.wikipedia.org/wiki/LR_grammar)
# type grammars. To create the Jison parser, we list the pattern to match
# on the left-hand side, and the action to take (usually the creation of syntax
# tree nodes) on the right. As the parser runs, it
# shifts tokens from our token stream, from left to right, and
# [attempts to match](http://en.wikipedia.org/wiki/Bottom-up_parsing)
# the token sequence against the rules below. When a match can be made, it
# reduces into the [nonterminal](http://en.wikipedia.org/wiki/Terminal_and_nonterminal_symbols)
# (the enclosing name at the top), and we proceed from there.
#
# If you run the `cake build:parser` command, Jison constructs a parse table
# from our rules and saves it into `lib/parser.js`.

# The only dependency is on the **Jison.Parser**.
{Parser} = require 'jison'

# Jison DSL
# ---------

# Since we're going to be wrapped in a function by Jison in any case, if our
# action immediately returns a value, we can optimize by removing the function
# wrapper and just returning the value directly.
unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

# Our handy DSL for Jison grammar generation, thanks to
# [Tim Caswell](http://github.com/creationix). For every rule in the grammar,
# we pass the pattern-defining string, the action to run, and extra options,
# optionally. If no action is specified, we simply pass the value of the
# previous nonterminal.
o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '
  patternCount = patternString.split(' ').length
  return [patternString, '$$ = $1;', options] unless action
  action = if match = unwrap.exec action then match[1] else "(#{action}())"

  # All runtime functions we need are defined on "yy"
  action = action.replace /\bnew /g, '$&yy.'
  action = action.replace /\b(?:Block\.wrap|extend)\b/g, 'yy.$&'

  # Returns a function which adds location data to the first parameter passed
  # in, and returns the parameter.  If the parameter is not a node, it will
  # just be passed through unaffected.
  addLocationDataFn = (first, last) ->
    if not last
      "yy.addLocationDataFn(@#{first})"
    else
      "yy.addLocationDataFn(@#{first}, @#{last})"

  action = action.replace /LOC\(([0-9]*)\)/g, addLocationDataFn('$1')
  action = action.replace /LOC\(([0-9]*),\s*([0-9]*)\)/g, addLocationDataFn('$1', '$2')

  [patternString, "$$ = #{addLocationDataFn(1, patternCount)}(#{action});", options]

# Grammatical Rules
# -----------------

# In all of the rules that follow, you'll see the name of the nonterminal as
# the key to a list of alternative matches. With each match's action, the
# dollar-sign variables are provided by Jison as references to the value of
# their numeric position, so in this rule:
#
#     "Expression UNLESS Expression"
#
# `$1` would be the value of the first `Expression`, `$2` would be the token
# for the `UNLESS` terminal, and `$3` would be the value of the second
# `Expression`.
grammar =

  # The **Root** is the top-level node in the syntax tree. Since we parse bottom-up,
  # all parsing must end here.
  Root: [
    o '',                                       -> new Block
    o 'Body'
  ]

  # Any list of statements and expressions, separated by line breaks or semicolons.
  Body: [
    o 'Line',                                   -> Block.wrap [$1]
    o 'Body TERMINATOR Line',                   -> $1.push $3
    o 'Body TERMINATOR'
  ]

  # Block and statements, which make up a line in a body. YieldReturn is a
  # statement, but not included in Statement because that results in an ambigous
  # grammar.
  Line: [
    o 'Expression'
    o 'Statement'
    o 'YieldReturn'
  ]

  # Pure statements which cannot be expressions.
  Statement: [
    o 'Return'
    o 'Comment'
    o 'STATEMENT',                              -> new Literal $1
  ]

  # All the different types of expressions in our language. The basic unit of
  # CoffeeScript is the **Expression** -- everything that can be an expression
  # is one. Blocks serve as the building blocks of many other rules, making
  # them somewhat circular.
  Expression: [
    o 'Value'
    o 'Invocation'
    o 'Code'
    o 'Operation'
    o 'Assign'
    o 'If'
    o 'Try'
    o 'While'
    o 'For'
    o 'Switch'
    o 'Class'
    o 'Throw'
    o 'Yield'
  ]

  Yield: [
    o 'YIELD',                                  -> new Op $1, new Value new Literal ''
    o 'YIELD Expression',                       -> new Op $1, $2
    o 'YIELD FROM Expression',                  -> new Op $1.concat($2), $3
  ]

  # An indented block of expressions. Note that the [Rewriter](rewriter.html)
  # will convert some postfix forms into blocks for us, by adjusting the
  # token stream.
  Block: [
    o 'INDENT OUTDENT',                         -> new Block
    o 'INDENT Body OUTDENT',                    -> $2
  ]

  # A literal identifier, a variable name or property.
  Identifier: [
    o 'IDENTIFIER',                             -> new Literal $1
  ]

  # Alphanumerics are separated from the other **Literal** matchers because
  # they can also serve as keys in object literals.
  AlphaNumeric: [
    o 'NUMBER',                                 -> new Literal $1
    o 'String'
  ]

  String: [
    o 'STRING',                                 -> new Literal $1
    o 'STRING_START Body STRING_END',           -> new Parens $2
  ]

  Regex: [
    o 'REGEX',                                  -> new Literal $1
    o 'REGEX_START Invocation REGEX_END',       -> $2
  ]

  # All of our immediate values. Generally these can be passed straight
  # through and printed to JavaScript.
  Literal: [
    o 'AlphaNumeric'
    o 'JS',                                     -> new Literal $1
    o 'Regex'
    o 'DEBUGGER',                               -> new Literal $1
    o 'UNDEFINED',                              -> new Undefined
    o 'NULL',                                   -> new Null
    o 'BOOL',                                   -> new Bool $1
  ]

  # Assignment of a variable, property, or index to a value.
  Assign: [
    o 'Assignable = Expression',                -> new Assign $1, $3
    o 'Assignable = TERMINATOR Expression',     -> new Assign $1, $4
    o 'Assignable = INDENT Expression OUTDENT', -> new Assign $1, $4
    o 'Assignable TypeAnnotation = Expression',                -> console.log($2); return new Assign $1, $4
    o 'Assignable TypeAnnotation = TERMINATOR Expression',     -> console.log($2); return new Assign $1, $5
    o 'Assignable TypeAnnotation = INDENT Expression OUTDENT', -> console.log($2); return new Assign $1, $5
  ]

  # Assignment when it happens within an object literal. The difference from
  # the ordinary **Assign** is that these allow numbers and strings as keys.
  AssignObj: [
    o 'ObjAssignable',                          -> new Value $1
    o 'ObjAssignable : Expression',             -> new Assign LOC(1)(new Value $1), $3, 'object',
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'ObjAssignable :
       INDENT Expression OUTDENT',              -> new Assign LOC(1)(new Value $1), $4, 'object',
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'SimpleObjAssignable = Expression',       -> new Assign LOC(1)(new Value $1), $3, null,
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'SimpleObjAssignable =
       INDENT Expression OUTDENT',              -> new Assign LOC(1)(new Value $1), $4, null,
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'Comment'
  ]

  SimpleObjAssignable: [
    o 'Identifier'
    o 'ThisProperty'
  ]

  ObjAssignable: [
    o 'SimpleObjAssignable'
    o 'AlphaNumeric'
  ]

  # A return statement from a function body.
  Return: [
    o 'RETURN Expression',                      -> new Return $2
    o 'RETURN',                                 -> new Return
  ]

  YieldReturn: [
    o 'YIELD RETURN Expression',                -> new YieldReturn $3
    o 'YIELD RETURN',                           -> new YieldReturn
  ]

  # A block comment.
  Comment: [
    o 'HERECOMMENT',                            -> new Comment $1
  ]

  # The **Code** node is the function literal. It's defined by an indented block
  # of **Block** preceded by a function arrow, with an optional parameter
  # list.
  Code: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Block', -> new Code $2, $5, $4
    o 'FuncGlyph Block',                        -> new Code [], $2, $1
  ]

  # CoffeeScript has two different symbols for functions. `->` is for ordinary
  # functions, and `=>` is for functions bound to the current value of *this*.
  FuncGlyph: [
    o '->',                                     -> 'func'
    o '=>',                                     -> 'boundfunc'
  ]

  # An optional, trailing comma.
  OptComma: [
    o ''
    o ','
  ]

  # The list of parameters that a function accepts can be of any length.
  ParamList: [
    o '',                                       -> []
    o 'Param',                                  -> [$1]
    o 'ParamList , Param',                      -> $1.concat $3
    o 'ParamList OptComma TERMINATOR Param',    -> $1.concat $4
    o 'ParamList OptComma INDENT ParamList OptComma OUTDENT', -> $1.concat $4
  ]

  # A single parameter in a function definition can be ordinary, or a splat
  # that hoovers up the remaining arguments.
  Param: [
    o 'ParamVar',                               -> new Param $1
    o 'ParamVar ...',                           -> new Param $1, null, on
    o 'ParamVar = Expression',                  -> new Param $1, $3
    o '...',                                    -> new Expansion
  ]

  # Function Parameters
  ParamVar: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array'
    o 'Object'
  ]

  # A splat that occurs outside of a parameter list.
  Splat: [
    o 'Expression ...',                         -> new Splat $1
  ]

  # Variables and properties that can be assigned to.
  SimpleAssignable: [
    o 'Identifier',                             -> new Value $1
    o 'Value Accessor',                         -> $1.add $2
    o 'Invocation Accessor',                    -> new Value $1, [].concat $2
    o 'ThisProperty'
  ]

  # Everything that can be assigned to.
  Assignable: [
    o 'SimpleAssignable'
    o 'Array',                                  -> new Value $1
    o 'Object',                                 -> new Value $1
  ]

  # The types of things that can be treated as values -- assigned to, invoked
  # as functions, indexed into, named as a class, etc.
  Value: [
    o 'Assignable'
    o 'Literal',                                -> new Value $1
    o 'Parenthetical',                          -> new Value $1
    o 'Range',                                  -> new Value $1
    o 'This'
  ]

  # The general group of accessors into an object, by property, by prototype
  # or by array index or slice.
  Accessor: [
    o '.  Identifier',                          -> new Access $2
    o '?. Identifier',                          -> new Access $2, 'soak'
    o ':: Identifier',                          -> [LOC(1)(new Access new Literal('prototype')), LOC(2)(new Access $2)]
    o '?:: Identifier',                         -> [LOC(1)(new Access new Literal('prototype'), 'soak'), LOC(2)(new Access $2)]
    o '::',                                     -> new Access new Literal 'prototype'
    o 'Index'
  ]

  # Indexing into an object or array using bracket notation.
  Index: [
    o 'INDEX_START IndexValue INDEX_END',       -> $2
    o 'INDEX_SOAK  Index',                      -> extend $2, soak : yes
  ]

  IndexValue: [
    o 'Expression',                             -> new Index $1
    o 'Slice',                                  -> new Slice $1
  ]

  # In CoffeeScript, an object literal is simply a list of assignments.
  Object: [
    o '{ AssignList OptComma }',                -> new Obj $2, $1.generated
  ]

  # Assignment of properties within an object literal can be separated by
  # comma, as in JavaScript, or simply by newline.
  AssignList: [
    o '',                                                       -> []
    o 'AssignObj',                                              -> [$1]
    o 'AssignList , AssignObj',                                 -> $1.concat $3
    o 'AssignList OptComma TERMINATOR AssignObj',               -> $1.concat $4
    o 'AssignList OptComma INDENT AssignList OptComma OUTDENT', -> $1.concat $4
  ]

  # Class definitions have optional bodies of prototype property assignments,
  # and optional references to the superclass.
  Class: [
    o 'CLASS',                                           -> new Class
    o 'CLASS Block',                                     -> new Class null, null, $2
    o 'CLASS EXTENDS Expression',                        -> new Class null, $3
    o 'CLASS EXTENDS Expression Block',                  -> new Class null, $3, $4
    o 'CLASS SimpleAssignable',                          -> new Class $2
    o 'CLASS SimpleAssignable Block',                    -> new Class $2, null, $3
    o 'CLASS SimpleAssignable EXTENDS Expression',       -> new Class $2, $4
    o 'CLASS SimpleAssignable EXTENDS Expression Block', -> new Class $2, $4, $5
  ]

  # Ordinary function invocation, or a chained series of calls.
  Invocation: [
    o 'Value OptFuncExist Arguments',           -> new Call $1, $3, $2
    o 'Invocation OptFuncExist Arguments',      -> new Call $1, $3, $2
    o 'SUPER',                                  -> new Call 'super', [new Splat new Literal 'arguments']
    o 'SUPER Arguments',                        -> new Call 'super', $2
  ]

  # An optional existence check on a function.
  OptFuncExist: [
    o '',                                       -> no
    o 'FUNC_EXIST',                             -> yes
  ]

  # The list of arguments to a function call.
  Arguments: [
    o 'CALL_START CALL_END',                    -> []
    o 'CALL_START ArgList OptComma CALL_END',   -> $2
  ]

  # A reference to the *this* current object.
  This: [
    o 'THIS',                                   -> new Value new Literal 'this'
    o '@',                                      -> new Value new Literal 'this'
  ]

  # A reference to a property on *this*.
  ThisProperty: [
    o '@ Identifier',                           -> new Value LOC(1)(new Literal('this')), [LOC(2)(new Access($2))], 'this'
  ]

  # The array literal.
  Array: [
    o '[ ]',                                    -> new Arr []
    o '[ ArgList OptComma ]',                   -> new Arr $2
  ]

  # Inclusive and exclusive range dots.
  RangeDots: [
    o '..',                                     -> 'inclusive'
    o '...',                                    -> 'exclusive'
  ]

  # The CoffeeScript range literal.
  Range: [
    o '[ Expression RangeDots Expression ]',    -> new Range $2, $4, $3
  ]

  # Array slice literals.
  Slice: [
    o 'Expression RangeDots Expression',        -> new Range $1, $3, $2
    o 'Expression RangeDots',                   -> new Range $1, null, $2
    o 'RangeDots Expression',                   -> new Range null, $2, $1
    o 'RangeDots',                              -> new Range null, null, $1
  ]

  # The **ArgList** is both the list of objects passed into a function call,
  # as well as the contents of an array literal
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList: [
    o 'Arg',                                              -> [$1]
    o 'ArgList , Arg',                                    -> $1.concat $3
    o 'ArgList OptComma TERMINATOR Arg',                  -> $1.concat $4
    o 'INDENT ArgList OptComma OUTDENT',                  -> $2
    o 'ArgList OptComma INDENT ArgList OptComma OUTDENT', -> $1.concat $4
  ]

  # Valid arguments are Blocks or Splats.
  Arg: [
    o 'Expression'
    o 'Splat'
    o '...',                                     -> new Expansion
  ]

  # Just simple, comma-separated, required arguments (no fancy syntax). We need
  # this to be separate from the **ArgList** for use in **Switch** blocks, where
  # having the newlines wouldn't make sense.
  SimpleArgs: [
    o 'Expression'
    o 'SimpleArgs , Expression',                -> [].concat $1, $3
  ]

  # The variants of *try/catch/finally* exception handling blocks.
  Try: [
    o 'TRY Block',                              -> new Try $2
    o 'TRY Block Catch',                        -> new Try $2, $3[0], $3[1]
    o 'TRY Block FINALLY Block',                -> new Try $2, null, null, $4
    o 'TRY Block Catch FINALLY Block',          -> new Try $2, $3[0], $3[1], $5
  ]

  # A catch clause names its error and runs a block of code.
  Catch: [
    o 'CATCH Identifier Block',                 -> [$2, $3]
    o 'CATCH Object Block',                     -> [LOC(2)(new Value($2)), $3]
    o 'CATCH Block',                            -> [null, $2]
  ]

  # Throw an exception object.
  Throw: [
    o 'THROW Expression',                       -> new Throw $2
  ]

  # Parenthetical expressions. Note that the **Parenthetical** is a **Value**,
  # not an **Expression**, so if you need to use an expression in a place
  # where only values are accepted, wrapping it in parentheses will always do
  # the trick.
  Parenthetical: [
    o '( Body )',                               -> new Parens $2
    o '( INDENT Body OUTDENT )',                -> new Parens $3
  ]

  # The condition portion of a while loop.
  WhileSource: [
    o 'WHILE Expression',                       -> new While $2
    o 'WHILE Expression WHEN Expression',       -> new While $2, guard: $4
    o 'UNTIL Expression',                       -> new While $2, invert: true
    o 'UNTIL Expression WHEN Expression',       -> new While $2, invert: true, guard: $4
  ]

  # The while loop can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression. There is no do..while.
  While: [
    o 'WhileSource Block',                      -> $1.addBody $2
    o 'Statement  WhileSource',                 -> $2.addBody LOC(1) Block.wrap([$1])
    o 'Expression WhileSource',                 -> $2.addBody LOC(1) Block.wrap([$1])
    o 'Loop',                                   -> $1
  ]

  Loop: [
    o 'LOOP Block',                             -> new While(LOC(1) new Literal 'true').addBody $2
    o 'LOOP Expression',                        -> new While(LOC(1) new Literal 'true').addBody LOC(2) Block.wrap [$2]
  ]

  # Array, object, and range comprehensions, at the most generic level.
  # Comprehensions can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression.
  For: [
    o 'Statement  ForBody',                     -> new For $1, $2
    o 'Expression ForBody',                     -> new For $1, $2
    o 'ForBody    Block',                       -> new For $2, $1
  ]

  ForBody: [
    o 'FOR Range',                              -> source: (LOC(2) new Value($2))
    o 'FOR Range BY Expression',                -> source: (LOC(2) new Value($2)), step: $4
    o 'ForStart ForSource',                     -> $2.own = $1.own; $2.name = $1[0]; $2.index = $1[1]; $2
  ]

  ForStart: [
    o 'FOR ForVariables',                       -> $2
    o 'FOR OWN ForVariables',                   -> $3.own = yes; $3
  ]

  # An array of all accepted values for a variable inside the loop.
  # This enables support for pattern matching.
  ForValue: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array',                                  -> new Value $1
    o 'Object',                                 -> new Value $1
  ]

  # An array or range comprehension has variables for the current element
  # and (optional) reference to the current index. Or, *key, value*, in the case
  # of object comprehensions.
  ForVariables: [
    o 'ForValue',                               -> [$1]
    o 'ForValue , ForValue',                    -> [$1, $3]
  ]

  # The source of a comprehension is an array or object with an optional guard
  # clause. If it's an array comprehension, you can also choose to step through
  # in fixed-size increments.
  ForSource: [
    o 'FORIN Expression',                               -> source: $2
    o 'FOROF Expression',                               -> source: $2, object: yes
    o 'FORIN Expression WHEN Expression',               -> source: $2, guard: $4
    o 'FOROF Expression WHEN Expression',               -> source: $2, guard: $4, object: yes
    o 'FORIN Expression BY Expression',                 -> source: $2, step:  $4
    o 'FORIN Expression WHEN Expression BY Expression', -> source: $2, guard: $4, step: $6
    o 'FORIN Expression BY Expression WHEN Expression', -> source: $2, step:  $4, guard: $6
  ]

  Switch: [
    o 'SWITCH Expression INDENT Whens OUTDENT',            -> new Switch $2, $4
    o 'SWITCH Expression INDENT Whens ELSE Block OUTDENT', -> new Switch $2, $4, $6
    o 'SWITCH INDENT Whens OUTDENT',                       -> new Switch null, $3
    o 'SWITCH INDENT Whens ELSE Block OUTDENT',            -> new Switch null, $3, $5
  ]

  Whens: [
    o 'When'
    o 'Whens When',                             -> $1.concat $2
  ]

  # An individual **When** clause, with action.
  When: [
    o 'LEADING_WHEN SimpleArgs Block',            -> [[$2, $3]]
    o 'LEADING_WHEN SimpleArgs Block TERMINATOR', -> [[$2, $3]]
  ]

  # The most basic form of *if* is a condition and an action. The following
  # if-related rules are broken up along these lines in order to avoid
  # ambiguity.
  IfBlock: [
    o 'IF Expression Block',                    -> new If $2, $3, type: $1
    o 'IfBlock ELSE IF Expression Block',       -> $1.addElse LOC(3,5) new If $4, $5, type: $3
  ]

  # The full complement of *if* expressions, including postfix one-liner
  # *if* and *unless*.
  If: [
    o 'IfBlock'
    o 'IfBlock ELSE Block',                     -> $1.addElse $3
    o 'Statement  POST_IF Expression',          -> new If $3, LOC(1)(Block.wrap [$1]), type: $2, statement: true
    o 'Expression POST_IF Expression',          -> new If $3, LOC(1)(Block.wrap [$1]), type: $2, statement: true
  ]

  # Arithmetic and logical operators, working on one or more operands.
  # Here they are grouped by order of precedence. The actual precedence rules
  # are defined at the bottom of the page. It would be shorter if we could
  # combine most of these rules into a single generic *Operand OpSymbol Operand*
  # -type rule, but in order to make the precedence binding possible, separate
  # rules are necessary.
  Operation: [
    o 'UNARY Expression',                       -> new Op $1 , $2
    o 'UNARY_MATH Expression',                  -> new Op $1 , $2
    o '-     Expression',                      (-> new Op '-', $2), prec: 'UNARY_MATH'
    o '+     Expression',                      (-> new Op '+', $2), prec: 'UNARY_MATH'

    o '-- SimpleAssignable',                    -> new Op '--', $2
    o '++ SimpleAssignable',                    -> new Op '++', $2
    o 'SimpleAssignable --',                    -> new Op '--', $1, null, true
    o 'SimpleAssignable ++',                    -> new Op '++', $1, null, true

    # [The existential operator](http://jashkenas.github.com/coffee-script/#existence).
    o 'Expression ?',                           -> new Existence $1

    o 'Expression +  Expression',               -> new Op '+' , $1, $3
    o 'Expression -  Expression',               -> new Op '-' , $1, $3

    o 'Expression MATH     Expression',         -> new Op $2, $1, $3
    o 'Expression **       Expression',         -> new Op $2, $1, $3
    o 'Expression SHIFT    Expression',         -> new Op $2, $1, $3
    o 'Expression COMPARE  Expression',         -> new Op $2, $1, $3
    o 'Expression <        Expression',         -> new Op $2, $1, $3
    o 'Expression >        Expression',         -> new Op $2, $1, $3
    o 'Expression LOGIC    Expression',         -> new Op $2, $1, $3
    o 'Expression |        Expression',         -> new Op $2, $1, $3
    o 'Expression &        Expression',         -> new Op $2, $1, $3
    o 'Expression RELATION Expression',         ->
      if $2.charAt(0) is '!'
        new Op($2[1..], $1, $3).invert()
      else
        new Op $2, $1, $3

    o 'SimpleAssignable COMPOUND_ASSIGN
       Expression',                             -> new Assign $1, $3, $2
    o 'SimpleAssignable COMPOUND_ASSIGN
       INDENT Expression OUTDENT',              -> new Assign $1, $4, $2
    o 'SimpleAssignable COMPOUND_ASSIGN TERMINATOR
       Expression',                             -> new Assign $1, $4, $2
    o 'SimpleAssignable EXTENDS Expression',    -> new Extends $1, $3
  ]

  # TypeScript compatible Type
  # https://github.com/Microsoft/TypeScript/blob/master/doc/spec.md#a1-types

  ## BEGIN HACK
  BindingIdentifier: [
    o 'IDENTIFIER', -> {type:"BindingIdentifier", IDENTIFIER:$1}
  ]

  BindingPattern: []

  IdentifierReference: [
    o 'IDENTIFIER', -> {type:"IdentifierReference", IDENTIFIER:$1}
  ]

  IdentifierName: [
    o 'IDENTIFIER', -> {type:"IdentifierName", IDENTIFIER:$1}
  ]

  StringLiteral: [
    o 'String'
  ]

  NumericLiteral: [
    o 'NUMBER'
  ]
  ## END HACK

  TypeParameters: [
    o '< TypeParameterList >',    -> $2
  ]

  TypeParameterList: [
    o '',                                      -> []
    o 'TypeParameter',                         -> [$1]
    o 'TypeParameterList , TypeParameter', -> $1.concat $3
  ]

  TypeParameter: [
    o 'BindingIdentifier'
    #o 'BindingIdentifier Constraint'
  ]

  ###
  Constraint: [
    o 'EXTENDS Type', -> ["Constraint", $2]
  ]
  ###

  TypeArguments: [
    o '< TypeArgumentList >', -> $2
  ]

  TypeArgumentList: [
    o 'TypeArgument',                    -> [$1]
    o 'TypeArgumentList , TypeArgument', -> $1.concat $3
  ]

  TypeArgument: [
    o 'Type'
  ]

  Type: [
    o 'UnionOrIntersectionOrPrimaryType'
    o 'FunctionType'
    #o 'ConstructorType'
  ]

  UnionOrIntersectionOrPrimaryType: [
    o 'UnionType'
    o 'IntersectionOrPrimaryType'
  ]

  IntersectionOrPrimaryType: [
    o 'IntersectionType'
    o 'PrimaryType'
  ]

  PrimaryType: [
    o 'ParenthesizedType'
    #o 'PredefinedType'
    o 'TypeReference'
    o 'ObjectType'
    o 'ArrayType'
    o 'TupleType'
    o 'TypeQuery'
  ]

  ParenthesizedType: [
    o '( Type )', -> $2
  ]
  ###
  PredefinedType: [
    o 'any'
    o 'number'
    o 'boolean'
    o 'string'
    o 'symbol'
    o 'void'
  ]
  ###
  TypeReference: [
    o 'TypeName',               -> {type: "TypeReference", TypeName:$1}
    o 'TypeName TypeArguments', -> {type: "TypeReference", TypeName:$1, TypeArguments:$2}
  ]

  TypeName: [
    o 'IdentifierReference',            -> [$1]
    o 'TypeName . IdentifierReference', -> $1.concat $3 # HACK
    # conflict
    # o 'NamespaceName . IdentifierReference', -> ["TypeName", $1.concat $3]
  ]
  ###
  Conflict in grammar: multiple actions possible when lookahead token is = in state 233
  - reduce by rule: NamespaceName -> IdentifierReference
  - reduce by rule: TypeName -> IdentifierReference
  NamespaceName: [
    o 'IdentifierReference',                 -> [$1]
    o 'NamespaceName . IdentifierReference', -> $1.concat $3
  ]
  ###

  ObjectType: [
    o '{ }',          -> {type:"ObjectType", TypeBody:null}
    o '{ TypeBody }', -> {type:"ObjectType", TypeBody:$2}
  ]

  TypeBody: [
    o 'TypeMemberList'
    o 'TypeMemberList ,', -> $1
    o 'TypeMemberList ;', -> $1
  ]

  TypeMemberList: [
    o 'TypeMember',                  -> [$1]
    o 'TypeMemberList ; TypeMember', -> $1.concat $3
    o 'TypeMemberList , TypeMember', -> $1.concat $3
  ]

  TypeMember: [
    o 'PropertySignature'
    #o 'CallSignature'
    #o 'ConstructSignature'
    o 'IndexSignature'
    #o 'MethodSignature'
  ]

  ArrayType: [
    o 'PrimaryType INDEX_START INDEX_END', -> {type:"ArrayType", PrimaryType:$1}
    #o 'PrimaryType [ ]', -> {type:"ArrayType", PrimaryType:$1} # base grammer
  ]

  TupleType: [
    o '[ TupleElementTypes ]', -> {type:"TupleType", TupleElementTypes:$2}
  ]

  TupleElementTypes: [
    o 'TupleElementType',                     -> [$1]
    o 'TupleElementTypes , TupleElementType', -> $1.concat [$3]
  ]

  TupleElementType: [
    o 'Type'
  ]

  UnionType: [
    o 'UnionOrIntersectionOrPrimaryType | IntersectionOrPrimaryType', -> {type:"UnionType", UnionOrIntersectionOrPrimaryType:$1, IntersectionOrPrimaryType:$3}
  ]

  IntersectionType: [
    o 'IntersectionOrPrimaryType & PrimaryType', -> {type:"IntersectionType", IntersectionOrPrimaryType:$1, PrimaryType:$3}
  ]

  FunctionType: [
    o '( ) => Type',                              -> {type:"FunctionType", Type:$4}
    #o '( ParameterList ) => Type',                -> {type:"FunctionType", ParameterList:$2, Type:$5}
    #o 'TypeParameters ( ) => Type',               -> {type:"FunctionType", TypeParameters:$1, Type:$5}
    #o 'TypeParameters ( ParameterList ) => Type', -> {type:"FunctionType", TypeParameters:$1, ParameterList:$3, Type:$6}
  ]
  ###
  ConstructorType: [
    o 'NEW ( ) => Type',                              -> ["ConstructorType", null, null, $4]
    o 'NEW ( ParameterList ) => Type',                -> ["ConstructorType", null, $2, $5]
    o 'NEW TypeParameters ( ) => Type',               -> ["ConstructorType", $1, null, $5]
    o 'NEW TypeParameters ( ParameterList ) => Type', -> ["ConstructorType", $1, $3, $6]
  ]
  ###
  TypeQuery: [
    o 'TYPEOF TypeQueryExpression', -> {type:"TypeQuery", TypeQueryExpression:$2}
  ]

  TypeQueryExpression: [
    o 'IdentifierReference',                  -> [$1]
    o 'TypeQueryExpression . IdentifierName', -> $1.concat $3
  ]

  PropertySignature: [
    o 'PropertyName',                  -> {type:"PropertySignature", PropertyName:$1}
    o 'PropertyName ?',                -> {type:"PropertySignature", PropertyName:$1, optional:true}
    o 'PropertyName TypeAnnotation',   -> {type:"PropertySignature", PropertyName:$1, TypeAnnotation:$2}
    o 'PropertyName ? TypeAnnotation', -> {type:"PropertySignature", PropertyName:$1, TypeAnnotation:$3, optional:true}
    o 'PropertyName ?::: Type',        -> {type:"PropertySignature", PropertyName:$1, TypeAnnotation:{type:"TypeAnnotation", Type:$3}, optional:true}
  ]

  PropertyName: [
    o 'IdentifierName'
    o 'StringLiteral'
    o 'NumericLiteral'
  ]

  TypeAnnotation: [
    o '::: Type', -> {type:"TypeAnnotation", Type:$2}
  ]
  ###
  CallSignature: [
    o '( )',                               -> {type:"CallSignature"}
    o 'TypeParameters ( )',                -> {type:"CallSignature", TypeParameters:$1}
    o '( ParameterList )',                 -> {type:"CallSignature", ParameterList:$2}
    o '( ) TypeAnnotation',                -> {type:"CallSignature", TypeAnnotation:$3}
    o 'TypeParameters ( ParameterList )',  -> {type:"CallSignature", TypeParameters:$1, ParameterList:$3}
    o '( ParameterList ) TypeAnnotation',  -> {type:"CallSignature", ParameterList:$2, TypeAnnotation:$4}
    o 'TypeParameters ( ) TypeAnnotation', -> {type:"CallSignature", TypeParameters:$1, TypeAnnotation:$4}
    o 'TypeParameters ( ParameterList ) TypeAnnotation', -> {type:"CallSignature", TypeParameters:$1, ParameterList:$3, TypeAnnotation:$4}
  ]
  ###
  ParameterList: [
    o 'RequiredParameterList', -> [$1]
    #o 'OptionalParameterList', -> [$1]
    #o 'RestParameter',         -> [$1]
    #o 'RequiredParameterList , OptionalParameterList', -> $1.concat $3
    #o 'RequiredParameterList , RestParameter',         -> $1.concat $3
    #o 'OptionalParameterList , RestParameter',         -> $1.concat $3
    #o 'RequiredParameterList , OptionalParameterList , RestParameter', -> $1.concat $3, $5
  ]

  RequiredParameterList: [
    o 'RequiredParameter',                         -> [$1]
    o 'RequiredParameterList , RequiredParameter', -> $1.concat $3
  ]

  RequiredParameter: [
    o 'BindingIdentifierOrPattern',                       -> {type:"RequiredParameter", BindingIdentifierOrPattern:$1}
    #o 'AccessibilityModifier BindingIdentifierOrPattern', -> ["RequiredParameter", $1, $2, null]
    #o 'BindingIdentifierOrPattern TypeAnnotation',        -> {type:"RequiredParameter", BindingIdentifierOrPattern:$1, TypeAnnotation:$2}
    #o 'AccessibilityModifier BindingIdentifierOrPattern TypeAnnotation', -> ["RequiredParameter", $1, $2, $3]
    #o 'BindingIdentifier ::: StringLiteral',                -> {type:"RequiredParameter", BindingIdentifierOrPattern:$1, TypeAnnotation:$2}
  ]
  ###
  AccessibilityModifier: [
    o "public"
    o "private"
    o "protected"
  ]
  ###
  BindingIdentifierOrPattern: [
    o 'BindingIdentifier'
    o 'BindingPattern'
  ]
  ###
  OptionalParameterList: [
    o 'OptionalParameter', -> [$1]
    o 'OptionalParameterList , OptionalParameter', -> $1.concat $3
  ]

  OptionalParameter: [
    o 'BindingIdentifierOrPattern ?', -> ["OptionalParameter", {BindingIdentifierOrPattern:$1, Optional:$2}]
    #o 'AccessibilityModifier BindingIdentifierOrPattern ?', -> ["OptionalParameter", {AccessibilityModifier:$1, BindingIdentifierOrPattern:$2, Optional:$3}]
    o 'BindingIdentifierOrPattern ? TypeAnnotation', -> ["OptionalParameter", {BindingIdentifierOrPattern:$1, Optional:$2, TypeAnnotation:$3}]
    #o 'AccessibilityModifier BindingIdentifierOrPattern ? TypeAnnotation', -> ["OptionalParameter", {AccessibilityModifier:$1, BindingIdentifierOrPattern:$2, Optional:$3, TypeAnnotation:$4}]
    o 'BindingIdentifierOrPattern Initializer',                       -> ["OptionalParameter", {BindingIdentifierOrPattern: $1, Initializer:$2}]
    #o 'AccessibilityModifier BindingIdentifierOrPattern Initializer', -> ["OptionalParameter", {AccessibilityModifier:$1, BindingIdentifierOrPattern: $2, Initializer:$3}]
    o 'BindingIdentifierOrPattern TypeAnnotation Initializer',        -> ["OptionalParameter", {BindingIdentifierOrPattern:$1, TypeAnnotation:$2, Initializer:$3}]
    #o 'AccessibilityModifier BindingIdentifierOrPattern TypeAnnotation Initializer', -> ["OptionalParameter", {AccessibilityModifier:$1, BindingIdentifierOrPattern: $2, TypeAnnotation:$3, Initializer:$4}]
    o 'BindingIdentifier ? : StringLiteral', -> ["OptionalParameter", {BindingIdentifierOrPattern:$1, Optional:$2, StringLiteral:$4}]
  ]

  RestParameter: [
    o '... BindingIdentifier TypeAnnotation', -> {type:"RestParameter", BindingIdentifier:$1, TypeAnnotation:$3}
  ]

  ConstructSignature: [
    o 'NEW ( )',                               -> {type:"ConstructSignature"}
    o 'NEW TypeParameters ( )',                -> {type:"ConstructSignature", TypeParameters:$2}
    o 'NEW ( ParameterList )',                 -> {type:"ConstructSignature", ParameterList:$3}
    o 'NEW ( ) TypeAnnotation',                -> {type:"ConstructSignature", TypeAnnotation:$4}
    o 'NEW TypeParameters ( ParameterList )',  -> {type:"ConstructSignature", TypeParameters:$2, ParameterList:$4}
    o 'NEW ( ParameterList ) TypeAnnotation',  -> {type:"ConstructSignature", ParameterList:$3, TypeAnnotation:$5}
    o 'NEW TypeParameters ( ) TypeAnnotation', -> {type:"ConstructSignature", TypeParameters:$2, TypeAnnotation:$5}
    o 'NEW TypeParameters ( ParameterList ) TypeAnnotation', -> {type:"ConstructSignature", TypeParameters:$2, ParameterList:$4, TypeAnnotation:$6}
  ]
  ###
  IndexSignature: [
    o '[ BindingIdentifier : string ] TypeAnnotation', -> {type:"IndexSignature", BindingIdentifier:$2, IndexType:$3, TypeAnnotation:$6}
    o '[ BindingIdentifier : number ] TypeAnnotation', -> {type:"IndexSignature", BindingIdentifier:$2, IndexType:$3, TypeAnnotation:$6}
  ]
  ###
  MethodSignature: [
    o 'PropertyName CallSignature',   -> {type:"MethodSignature", PropertyName:$1, CallSignature:$3}
    o 'PropertyName ? CallSignature', -> {type:"MethodSignature", PropertyName:$1, CallSignature:$3, optional:true}
  ]

  TypeAliasDeclaration: [
    o 'type BindingIdentifier = Type',                -> ["TypeAliasDeclaration", $2, null, $4]
    o 'type BindingIdentifier TypeParameters = Type', -> ["TypeAliasDeclaration", $2, $3, $5]
  ]
  ###

# Precedence
# ----------

# Operators at the top of this list have higher precedence than the ones lower
# down. Following these rules is what makes `2 + 3 * 4` parse as:
#
#     2 + (3 * 4)
#
# And not:
#
#     (2 + 3) * 4
operators = [
  ['left',      '.', '?.', '::', '?::']
  ['left',      'CALL_START', 'CALL_END']
  ['nonassoc',  '++', '--']
  ['left',      '?']
  ['right',     'UNARY']
  ['right',     '**']
  ['right',     'UNARY_MATH']
  ['left',      'MATH']
  ['left',      '+', '-']
  ['left',      'SHIFT']
  ['left',      'RELATION']
  ['left',      'COMPARE', '<', '>']
  ['left',      'LOGIC', '|', '&']
  ['nonassoc',  'INDENT', 'OUTDENT']
  ['right',     'YIELD']
  ['right',     ':::']
  ['right',     '=', ':', 'COMPOUND_ASSIGN', 'RETURN', 'THROW', 'EXTENDS']
  ['right',     'FORIN', 'FOROF', 'BY', 'WHEN']
  ['right',     'IF', 'ELSE', 'FOR', 'WHILE', 'UNTIL', 'LOOP', 'SUPER', 'CLASS']
  ['left',      'POST_IF']
]

# Wrapping Up
# -----------

# Finally, now that we have our **grammar** and our **operators**, we can create
# our **Jison.Parser**. We do this by processing all of our rules, recording all
# terminals (every symbol which does not appear as the name of a rule above)
# as "tokens".
tokens = []
for name, alternatives of grammar
  grammar[name] = for alt in alternatives
    for token in alt[0].split ' '
      tokens.push token unless grammar[token]
    alt[1] = "return #{alt[1]}" if name is 'Root'
    alt

# Initialize the **Parser** with our list of terminal **tokens**, our **grammar**
# rules, and the name of the root. Reverse the operators because Jison orders
# precedence from low to high, and we have it high to low
# (as in [Yacc](http://dinosaur.compilertools.net/yacc/index.html)).
exports.parser = new Parser
  tokens      : tokens.join ' '
  bnf         : grammar
  operators   : operators.reverse()
  startSymbol : 'Root'
