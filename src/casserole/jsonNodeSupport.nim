## This module implements support for pattern matching `JsonNode`.
## This maps to the [types defined in std/json](https://nim-lang.org/docs/json.html).
## The same enum is used
runnableExamples:
  import casserole
  import std/json

  let x = %"Hello"
  if JString(val) ?== x:
    assert val == "Hello"

import std/json

proc getBranch*(node: JsonNode, branch: static[JsonNodeKind]): tuple =
  ## Returns a tuple containing the values for the specified branch.
  ## See [the json module docs](https://nim-lang.org/docs/json.html) for the values
  when branch == JNull:
    default(tuple[])
  elif branch == JObject:
    (node.fields,)
  elif branch == JArray:
    (node.elems,)
  elif branch == JString:
    (node.str,)
  elif branch == JInt:
    (node.num,)
  elif branch == JFloat:
    (node.fnum,)
  elif branch == JBool:
    (node.bval,)

proc currentBranch*(node: JsonNode): JsonNodeKind =
  ## Returns the current branch (kind) of the JsonNode.
  ##
  ## This is equivalent to `node.kind` but provided for interface consistency.
  node.kind
