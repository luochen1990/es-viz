require 'coffee-mate/global'
{dep} = require('./dep')

#log -> json cartProd([1, 2, 3], ['a', 'b'])
#log -> json concat [[1], [2,3], [], [4]]
#log -> json concat [[1], [2,3], (filter((x) -> x >10) [1,2,3]), [4]]

uniqueOn = (f) -> combine(map (pluck 0)) groupOn(f)

# genGraph : List AST -> Graph Identifier () ()
genGraph = (asts) ->
  deps = asts.map(dep)
  #log -> deps
  #log -> json concat deps.map(({dec, dep}) -> cartProd(dec, dep))
  links = list map(([source, target]) -> {source, target, value: 1}) concat deps.map(({dec, dep}) -> list cartProd(dec, dep))
  outDeg = fromList map((g) -> [head(g).source, length(g)]) groupOn(pluck 'source') links
  inDeg = fromList map((g) -> [head(g).target, length(g)]) groupOn(pluck 'target') links
  nodes = list map((i) -> {id: i, group: 1, inDegree: (inDeg[i] ? 0), outDegree: (outDeg[i] ? 0)}) uniqueOn(identity) concat deps.map(({dec, dep}) -> concat([dec, dep]))
  return {nodes, links}

module.exports = {genGraph}

if module.parent is null
  asts = [
    'a = b(c)(d)'
    'b = (x) => x + d'
    'c = d * add(2)(1)'
    'f = add(1)(2)'
    'w = x + y + z'
    'u'
    'v'
  ]
  g0 = genGraph asts
  log -> g0

  fs = require('fs')
  fs.writeFileSync("./graph.json", prettyJson(g0))

