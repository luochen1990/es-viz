require 'coffee-mate/global'
esprima = require('esprima')
{defineReducer} = require('ast-reducer')

_Set = {
  empty: new Set()
  singleton: (a) ->  new Set([a])
  union: (b) -> (a) -> r = new Set(b); a.forEach((x) -> r.add(x)); r #b.union(a)
  unionAll: (ss) -> ss.reduce(((a, r) -> _Set.union(a)(r)), _Set.empty)
  except: (a) -> (b) -> r = new Set(b); a.forEach((x) -> r.delete(x)); r #b.difference(a)
}

Dep = {
  empty: {dec: _Set.empty, dep: _Set.empty}
  singleton: (x) -> {dec: _Set.empty, dep: _Set.singleton(x)}
  shift: (a) -> {dec: a.dep, dep: _Set.empty} # shift dep to be dec
  reduce: (a) -> {dec: _Set.empty, dep: _Set.except(a.dec)(a.dep)} # reduce dec in dep
  union: (a) -> (b) -> {dec: _Set.union(a.dec)(b.dec), dep: _Set.union(a.dep)(b.dep)}
  unionAll: (ds) -> {dec: _Set.unionAll(ds.map(pluck 'dec')), dep: _Set.unionAll(ds.map(pluck 'dep'))}
}

parseNode = ((x) -> {rule: (x?.type ? 'null'), arg: x})
depReducer = defineReducer({name: 'Dep', parseNode}) (impl) ->
  funcExpr = ({id, params, body}) ->
    Dep.union(Dep.shift(@(id)))(Dep.reduce(Dep.union(Dep.shift(Dep.unionAll(params.map(@))))(@(body))))

  impl('null') () -> Dep.empty
  impl('File') ({program}) -> @(program)
  impl('Program') ({body}) -> Dep.unionAll(body.map(@))
  impl('ExpressionStatement') ({expression}) -> @(expression)
  impl('AssignmentExpression') ({left, right}) -> Dep.union(Dep.shift(@(left)))(@(right))
  impl('BlockStatement') ({body}) -> Dep.reduce(Dep.unionAll(body.map(@)))
  impl('VariableDeclaration') ({declarations}) -> Dep.unionAll(declarations.map(@))
  impl('VariableDeclarator') ({id, init}) -> Dep.union(Dep.shift(@(id)))(@(init))
  impl('ReturnStatement') ({argument}) -> Dep.reduce(@(argument))
  impl('FunctionExpression') funcExpr
  impl('CallExpression') ({callee, arguments: args}) -> Dep.union(@(callee))(Dep.unionAll(args.map(@)))
  impl('MemberExpression') ({object, property}) -> @(object) #TODO: consider property
  impl('Identifier') ({name}) -> Dep.singleton(name)
  impl('Literal') ({value}) -> Dep.empty
  impl('BinaryExpression') ({operator, left, right}) -> Dep.union(@(left))(@(right))
  impl('SequenceExpression') ({expressions}) -> Dep.unionAll(expressions.map(@))
  impl('ArrowFunctionExpression') funcExpr
  impl('IfStatement') ({test, consequent, alternate}) -> Dep.union(@(test)) Dep.union(@(consequent)) @(alternate)
  impl('ConditionalExpression') ({test, consequent, alternate}) -> Dep.union(@(test)) Dep.union(@(consequent)) @(alternate)
  impl('UnaryExpression') ({operator, prefix, argument}) -> @(argument)
  impl('ThisExpression') () -> Dep.empty
  impl('ArrayExpression') ({elements}) -> Dep.unionAll(elements.map(@))
  impl('ObjectExpression') ({properties}) -> Dep.unionAll(properties.map(@))
  impl('Property') ({key, value, kind}) -> @(value)
  impl('LogicalExpression') ({operator, left, right}) -> Dep.union(@(left))(@(right))
  impl('ThrowStatement') ({argument}) -> @(argument)
  impl('FunctionDeclaration') funcExpr
  impl('WhileStatement') ({test, body}) -> Dep.union(@(test))(@(body))
  impl('DoWhileStatement') ({body, test}) -> Dep.union(@(body))(@(test))
  impl('UpdateExpression') ({operator, argument, prefix}) -> @(argument)
  impl('NewExpression') ({callee, arguments: args}) -> Dep.union(@(callee))(Dep.unionAll(args.map(@)))
  impl('TryStatement') ({block, handler, finalizer}) -> Dep.union(@(block)) Dep.union(@(handler)) @(finalizer)
  impl('CatchClause') ({param, body}) -> Dep.reduce(Dep.union(Dep.shift(@(param)))(@(body)))
  impl('ObjectPattern') ({properties}) -> Dep.unionAll(properties.map(@))
  #impl('AssignmentProperty') ({value}) -> @(value)
  impl('ArrayPattern') ({elements}) -> Dep.unionAll(elements.map(@))
  impl('RestElement') ({argument}) -> @(argument)
  impl('TemplateLiteral') ({quasis, expressions}) -> Dep.unionAll(expressions.map(@))
  #impl('TaggedTemplateExpression') ({tag, quasi}) ->
  #impl('TemplateElement') ({tail, value}) ->

dep = (i) ->
  _ast = if typeof i is 'string' then esprima.parseScript(i) else i
  depReducer.eval(_ast)

module.exports = {depReducer, dep}

if module.parent is null
  code1 = """
    function add(a, b) {
      return a +
        // Weird formatting, huh?
        b;
    }
  """

  code2 = """
  sortOn = function(mapping, opts) {
  var localSort;
  localSort = localSortOn(mapping, opts);
  return function(arr, range) {
    return localSort(arr.slice(), range);
  };
  };
  """

  code3 = """
  localPartitionOn = function(p) {
  return function(arr, range) {
    var begin, i, j, num, ref, ref1;
    if (arr.length === 0) {
      return 0;
    }
    ref = range != null ? range : {}, begin = ref.begin, num = ref.num;
    if (begin == null) {
      begin = 0;
    }
    if (num == null) {
      num = arr.length - begin;
    }
    i = begin;
    j = begin + num - 1;
    while (i <= j) {
      while (i <= j && p(arr[i])) {
        ++i;
      }
      while (i <= j && !p(arr[j])) {
        --j;
      }
      if (i <= j) {
        ref1 = [arr[j], arr[i]], arr[i] = ref1[0], arr[j] = ref1[1];
        ++i;
        --j;
      }
    }
    return i - begin;
  };
  };
  """

  ast = esprima.parseScript(code2)
  log -> JSON.stringify ast, ((k, v) -> if k != 'loc' then v), 2

  try
    log -> dep code1
    log -> dep code2
    log -> dep code3
    log -> dep 'a = 1, b = a + 2, c = 3'
    log -> dep 'var a = 1, b = a + 2, c = 3'
    log -> dep '(a, b) => a + b + c'
    log -> dep ''
    log -> dep 'obj = {x: a, y: b}'
    log -> dep 'const inc = (y) => x = x + y'
    log -> dep 'var x = 1; const inc = (y) => x = x + y'
    log -> dep 'var a; a = b + c'
    log -> dep 'var a; a = a + b + c'
  catch e
    log -> e.stack
    log -> e.cause.stack

###
https://github.com/estree/estree/blob/master/es5.md

Node objects
Identifier
Literal
RegExpLiteral
Programs
Functions
Statements
ExpressionStatement
BlockStatement
EmptyStatement
DebuggerStatement
WithStatement
Control flow
ReturnStatement
LabeledStatement
BreakStatement
ContinueStatement
Choice
IfStatement
SwitchStatement
SwitchCase
Exceptions
ThrowStatement
TryStatement
CatchClause
Loops
WhileStatement
DoWhileStatement
ForStatement
ForInStatement
Declarations
FunctionDeclaration
VariableDeclaration
VariableDeclarator
Expressions
ThisExpression
ArrayExpression
ObjectExpression
Property
FunctionExpression
Unary operations
UnaryExpression
UnaryOperator
UpdateExpression
UpdateOperator
Binary operations
BinaryExpression
BinaryOperator
AssignmentExpression
AssignmentOperator
LogicalExpression
LogicalOperator
MemberExpression
ConditionalExpression
CallExpression
NewExpression
SequenceExpression
Patterns
###
