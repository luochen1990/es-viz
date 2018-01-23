require 'coffee-mate/global'
esprima = require('esprima')
{defineReducer} = require('ast-reducer')

parseNode = ((x) -> {rule: (x?.type ? 'null'), arg: x})
#defaultRule = (a) -> [a]
piecesReducer = defineReducer({name: 'Pieces', parseNode}) (impl) ->
  funcExpr = ({id, params, body}) -> @(body)

  impl('null') () -> [] #Dep.empty
  impl('File') ({program}) -> @(program)
  impl('Program') ({body}) -> body
  impl('ExpressionStatement') ({expression}) -> @(expression)
  impl('AssignmentExpression') ({left, right}) -> @(right)
  impl('BlockStatement') ({body}) -> body
  #impl('VariableDeclaration') ({declarations}) -> concat(declarations.map(@))
  #impl('VariableDeclarator') ({id, init}) -> @(init)
  impl('ReturnStatement') ({argument}) -> @(argument)
  impl('FunctionExpression') funcExpr
  #impl('CallExpression') ({callee, arguments: args}) -> Dep.union(@(callee))(Dep.unionAll(args.map(@)))
  #impl('MemberExpression') ({object, property}) -> @(object) #TODO: consider property
  #impl('Identifier') ({name}) -> Dep.singleton(name)
  #impl('Literal') ({value}) -> Dep.empty
  #impl('BinaryExpression') ({operator, left, right}) -> Dep.union(@(left))(@(right))
  impl('SequenceExpression') ({expressions}) -> expressions
  impl('ArrowFunctionExpression') funcExpr
  #impl('IfStatement') ({test, consequent, alternate}) -> Dep.union(@(test)) Dep.union(@(consequent)) @(alternate)
  #impl('ConditionalExpression') ({test, consequent, alternate}) -> Dep.union(@(test)) Dep.union(@(consequent)) @(alternate)
  #impl('UnaryExpression') ({operator, prefix, argument}) -> @(argument)
  #impl('ThisExpression') () -> Dep.empty
  #impl('ArrayExpression') ({elements}) -> Dep.unionAll(elements.map(@))
  #impl('ObjectExpression') ({properties}) -> Dep.unionAll(properties.map(@))
  #impl('Property') ({key, value, kind}) -> @(value)
  #impl('LogicalExpression') ({operator, left, right}) -> Dep.union(@(left))(@(right))
  impl('ThrowStatement') ({argument}) -> @(argument)
  impl('FunctionDeclaration') funcExpr
  #impl('WhileStatement') ({test, body}) -> Dep.union(@(test))(@(body))
  #impl('DoWhileStatement') ({body, test}) -> Dep.union(@(body))(@(test))
  #impl('UpdateExpression') ({operator, argument, prefix}) -> @(argument)

pieces = (i) ->
  _ast = if typeof i is 'string' then esprima.parseScript(i) else i
  piecesReducer.eval(_ast)

module.exports = {piecesReducer, pieces}

if module.parent is null
  code1 = """
    function add(a, b) {
      return a +
        // Weird formatting, huh?
        b;
    }

  sortOn = function(mapping, opts) {
  var localSort;
  localSort = localSortOn(mapping, opts);
  return function(arr, range) {
    return localSort(arr.slice(), range);
  };
  };

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

  log -> pieces code1

