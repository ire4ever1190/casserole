## This module implements support for matching `NimNode` inside macros.
## This maps to the [ast outlined](https://nim-lang.org/docs/macros.html#the-ast-in-nim) in the docs

import std/[macros, options, strutils]
import libdump/macros

macro stripPrefix() =
  ## Strips a prefix from a series of enums, generating a new enum
  result = nnkEnumTy.newTree(newEmptyNode())
  for sym in bindSym("NimNodeKind").getObjectDecl().get()[1 .. ^1]:
    # I know this isn't right...
    let ident = if sym.eqIdent("nnkNone"): "NoneNode" else: sym.strVal.replace("nnk", "")
    result &= ident ident

  result = nnkTypeSection.newTree(nnkTypeDef.newTree(
    nnkPostFix.newTree(ident"*", ident"NodeBranch"),
    newEmptyNode(),
    result
  ))

stripPrefix()

proc getBranch*(node: NimNode, branch: static[NodeBranch]): tuple =
  ## Returns values like shown in the [docs](https://nim-lang.org/docs/macros.html#the-ast-in-nim)
  when branch in {NoneNode, Empty, NilLit}:
    default(tuple[])
  elif branch in CharLit..UInt64Lit:
    (node.intVal,)
  elif branch in FloatLit..Float64Lit:
    (node.floatVal,)
  elif branch in {StrLit..TripleStrLit, CommentStmt, Ident, Sym}:
    (node.strVal,)
  else:
    (node.sons,)

proc currentBranch*(node: NimNode): NodeBranch =
  ## Maps `NimNodeKind` to our simplified kind
  NodeBranch(node.kind.ord)
