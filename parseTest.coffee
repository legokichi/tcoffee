CoffeeScript = require("./lib/coffee-script")

test = (code, cb)->
  tokens = CoffeeScript.tokens(code)
  nodes = CoffeeScript.nodes(tokens)
  tokens = tokens.map (token)-> token[0]
  cb(code, tokens, nodes)

testTokens = (code, tokens, expect)->
  try
    throw new Error() unless tokens.length is expect.length
    throw new Error() unless tokens.every (token, i)-> tokens[i] is expect[i]
  catch
    console.error "#### token test failed: #{code}"
    console.dir tokens
    console.dir expect

testNode = (code, node, expect)->
  recur = (node, expect)->
    Object.keys(expect).every (key)->
      node[key]? && if typeof node[key] is "object" then recur(node[key], expect[key]) else node[key] is expect[key]
  unless recur(node, expect)
    console.error "#### node test failed: #{code}"
    console.dir node
    console.dir expect



test "n ::: number = 3", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "IDENTIFIER", "=", "NUMBER", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'TypeReference'
      TypeName: ["number"]

test "n ::: (number) = 3", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "(", "IDENTIFIER", ")", "=", "NUMBER", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'TypeReference'
      TypeName: ["number"]

test "n ::: A.number = 3", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "IDENTIFIER", ".", "IDENTIFIER", "=", "NUMBER", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'TypeReference'
      TypeName: ["A", "number"]

test "union ::: number | string = \"one\"", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "IDENTIFIER", "|", "IDENTIFIER", "=", "STRING", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'UnionType'
      UnionOrIntersectionOrPrimaryType:
        type: 'TypeReference'
        TypeName: ["number"]
      IntersectionOrPrimaryType:
        type: 'TypeReference'
        TypeName: ["string"]

test "union ::: (number | string | boolean) = \"one\"", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "(", "IDENTIFIER", "|", "IDENTIFIER", "|", "IDENTIFIER", ")", "=", "STRING", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'UnionType'
      UnionOrIntersectionOrPrimaryType:
        type: 'UnionType'
        UnionOrIntersectionOrPrimaryType:
          type: 'TypeReference'
          TypeName: ["number"]
        IntersectionOrPrimaryType:
          type: 'TypeReference'
          TypeName: ["string"]
      IntersectionOrPrimaryType:
        type: 'TypeReference'
        TypeName: ["boolean"]

test "intersection ::: number & string = 3", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "IDENTIFIER", "&", "IDENTIFIER", "=", "NUMBER", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'IntersectionType'
      IntersectionOrPrimaryType:
        type: 'TypeReference'
        TypeName: ["number"]
      PrimaryType:
        type: 'TypeReference'
        TypeName: ["string"]

test "array ::: string[] = [\"three\"]", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "IDENTIFIER", "INDEX_START", "INDEX_END", "=", "[", "STRING", "]", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'ArrayType'
      PrimaryType:
        type: 'TypeReference'
        TypeName: ["string"]


test "tuple ::: [number, string] = [3, \"three\"]", (code, tokens, nodes)->
  testTokens code, tokens, ["IDENTIFIER", ":::", "[", "IDENTIFIER", ",", "IDENTIFIER", "]", "=", "[", "NUMBER", ",", "STRING", "]", "TERMINATOR"]
  testNode code, nodes.expressions[0].type,
    type: 'TypeAnnotation'
    Type:
      type: 'TupleType'
      TupleElementTypes: [
        {type: 'TypeReference', TypeName: ["number"]}
        {type: 'TypeReference', TypeName: ["string"]}
      ]
