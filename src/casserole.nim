## This library supports making sum types without needing a separate enum with like variants.
## This gives support for having fields with the same name along with safe unpacking of values.
##
## For example, we could construct an `Result` type like so
runnableExamples:
  import casserole
  import std/random

  type
    # You must attach the `{.cased.}` pragma
    Result*[T, E] {.cased.} = object
      case
      of Ok:
        # Throw your fields into each branch
        value: T
      of Error:
        error: E

  # Looks like any other type
  proc possiblyFails(): Result[int, string] =
    if sample([true, false]):
      # Constructed by referencing the type and the branch
      Result[int, string].Ok(rand(100))
    else:
      Result[int, string].Error("Failed for some reason =(")

  let res = possiblyFails()

  # Can extract via pattern matching with `if`/`case` statements
  if Ok(randVal) ?== res:
    echo "We got: " & $randVal

  # Case statements check for exhaustiveness
  case res
  of Ok(randVal):
    echo "Was something"
  of Error(error):
    echo "It failed"
## I could show you how to make an `Option[T]` type but that would be redundant since this libray supports `std/options`!
runnableExamples:
  import std/options

  let val = some("Hello")

  # Everything works like in the example before (Branches are still Some/None)
  if Some(value) ?== val:
    echo value

import std/[macros, strutils, sequtils, options]

import pkg/libdump/macros

import ./casserole/optionSupport
export optionSupport

{.experimental: "dotOperators".}

type
  CaseObject*[D] = object of RootObj
    ## Type class for accepting a case object.
    ## `D` is the discriminator for the fields

  CasedObject*[D, R] = concept
    ## This gets implemented for custom types to integrate them into cased pattern matching.
    proc currentBranch(val: Self): D
      ## This must return the current discriminator value for an object
    proc getBranch(val: Self, branch: static[D]): R
      ## This must return the value of a branch. Can raise a fieldDefect if in wrong state

proc getTagIdent(tag: string): NimNode =
  ## Returns the identifier for a tag
  return tag.toLowerAscii().ident

proc collectFields(pattern: NimNode): seq[tuple[ident: NimNode, index: int]] =
  ## Returns all the fields in a pattern.
  ## - `ident`: what identifier it should be unpacked into
  ## - `index`: Index into the tuple of the branch this field belongs to

  for i in 1 ..< pattern.len:
    if not pattern[i].eqIdent("_"): # Don't generate for _
      result &= (pattern[i], i - 1)

proc getBranch(pattern, branch: NimNode): NimNode =
  ## Returns a call that retrives the branch value for an object
  return newCall("getBranch", pattern, branch)

proc getCurrentBranch(pattern: NimNode): NimNode =
  ## Returns a call that retrieves the current branch of an object
  return newCall("currentBranch", pattern)

proc newBracketExpr(a, b: NimNode): NimNode =
  ## Helper syntax for making bracket expr
  return nnkBracketExpr.newTree(a, b)


macro generateCases(c: CaseObject, discrimValue: enum): untyped =
  ## Generates all the `when` statements for getting a branch from
  ## the discriminator
  let branches = c.getObjectDecl().get()[2][0][1 .. ^1]
  result = nnkWhenStmt.newTree()

  # Just look through the generated variant object and line everything up
  for branch in branches:
    result &= nnkElifBranch.newTree(
      newCall(ident"==", discrimValue, branch[0]),
      newStmtList(newDotExpr(c, branch[1][0][0]))
    )
  result &= nnkElse.newTree(  nnkPragma.newTree(
    nnkExprColonExpr.newTree(
      newIdentNode("error"),
      newLit("Failed?")
    )
    )
  )
  echo result.toStrLit

proc getBranch*[D; T: CaseObject](c: T, branch: static[D]): tuple =
  ## Generic function that gets the branch value for any [CaseObject]
  generateCases(c, branch)

proc currentBranch*[D; T: CaseObject[D]](c: T): D =
  ## Returns the current state that a [CaseObject] is in
  c.kind

template branchCheck(obj, branch: untyped) =
  ## Inserts a branch check that raises a `FieldDefect` when accessing invalid branches.
  ## Disabled with `-d:danger`
  when not defined(danger):
    let currentBranch = obj.currentBranch
    if currentBranch != branch:
      raise (ref FieldDefect)(msg: "Trying to access " & $branch & " but object is " & $currentBranch)

macro `?=`*(lhs: untyped, rhs: CaseObject | CasedObject): untyped =
  ## Unpacks a cased object into an expected type.
  ## Raises a field defect if its the wrong type
  result = nnkLetSection.newTree()

  let branch = getBranch(rhs, ident lhs[0].strVal)

  for (ident, idx) in lhs.collectFields:
    result &= newIdentDefs(ident, newEmptyNode(), newBracketExpr(branch, newLit idx))

  # We still need to add a check so field defects are thrown for bad branches
  result = newStmtList(
    newCall(bindSym"branchCheck", rhs, lhs[0]),
    result
  )

macro `?==`*(lhs: untyped, rhs: CaseObject | CasedObject): bool =
  ## Like [?=] except doesn't raise an error. This is meant
  ## to be used inside `if` statements for unpacking a value.
  ## Variables will still be added to scope for wrong branch, but won't be initialised
  let
    branch = getBranch(rhs, ident lhs[0].strVal)
    rightBranch = newCall(ident"==", getCurrentBranch(rhs), lhs[0])

  result = newStmtList()

  # First we need to generate all the variables these will get unpacked into.
  # Probs has performance issues since we are creating values even for wrong branch, but oh well
  for (ident, idx) in lhs.collectFields:
    result &= newVarStmt(ident, newCall("default", newCall("typeof", nnkBracketExpr.newTree(branch, newLit idx))))

  # Now if its the right branch, we can perform the unpacking
  let unpackBranch = newStmtList()
  for (ident, idx) in lhs.collectFields:
    unpackBranch &= newAssignment(ident, nnkBracketExpr.newTree(branch, newLit idx))

  result &= nnkIfStmt.newTree(nnkElifBranch.newTree(rightBranch, unpackBranch))

  # Finally, let the user know if its safe to use the values
  result &= rightBranch

macro `.()`*(obj, tag: untyped, values: varargs[untyped]): untyped =
  ## This is used for constructor a cased object.
  ## Construction is done in the form `Object.Tag(params...)`
  # TODO: Support named field construction
  let tupleConstr = nnkTupleConstr.newTree()
  for value in values:
    tupleConstr &= value
  nnkObjConstr.newTree(
    obj,
    newColonExpr(ident"kind", tag),
    newColonExpr(tag.strVal.getTagIdent(), tupleConstr)
  )

macro cased*(inp: untyped): untyped =
  ## Generates a case class object based on [RFC#559](https://github.com/nim-lang/RFCs/issues/559)
  runnableExamples:
    type
      Optional[T] {.cased.} = object
        case
        of Some:
          value: T
        of None: discard

  # Pull some info straight from the object
  let
    name = inp[0].basename.strVal
    genericParams = inp[1]
    isRef = inp[2].kind == nnkRefTy
    objectDecl = if isRef: inp[2][0] else: inp[2]

  # Now gather all the branches. We want the names along with the fields that appear
  var branches: seq[tuple[tags: seq[string], fields: seq[NimNode]]]
  for ofBranch in objectDecl[2][0][1 .. ^1]:
    let tags = ofBranch[0 ..< ^1].mapIt(it.strVal)
    let fields = ofBranch[^1]
    branches &= (tags, fields.mapIt(it))

  # Using the possible tags, we need to build the enum
  let enumName = nskType.genSym(name & "Tag")
  let enumDecl = block:
    let body = nnkEnumTy.newTree(newEmptyNode())
    for (tags, _) in branches:
      body &= tags.mapIt(ident it)
    nnkTypeDef.newTree(enumName, newEmptyNode(), body)

  # Now build the object. It will have each field be the name of the tag
  # with the value being a tuple
  let newObjectDecl = block:
    let caseStmt = nnkRecCase.newTree(nnkIdentDefs.newTree(ident"kind", enumName, newEmptyNode()))
    # Add all the branches
    for (tags, fields) in branches:
      let ofBranch = newNimNode(nnkOfBranch).add(tags.mapIt(ident it))
      # TODO: Support multiple fields
      ofBranch &= nnkRecList.newTree(
        nnkIdentDefs.newTree(getTagIdent tags[0], nnkTupleTy.newTree(fields), newEmptyNode())
      )
      caseStmt &= ofBranch


    let objectTy = nnkObjectTy.newTree(newEmptyNode(), nnkOfInherit.newTree(newBracketExpr(bindSym"CaseObject", enumName)), caseStmt)
    if isRef: nnkRefTy.newTree(objectTy) else: objectTy

  result = nnkTypeSection.newTree(
    enumDecl,
    nnkTypeDef.newTree(inp[0], inp[1], newObjectDecl)
  )

macro `case`*(n: CasedObject | CaseObject): untyped =
  ## Macro that adds support for pattern matching via case statement/expression.
  ## This supports the same syntax as [?=]
  result = newStmtList()

  # We store the passed in object so it doesn't get reevaulated multiple times
  let valueIdent = nskLet.genSym"value"
  result &= newLetStmt(valueIdent, n[0])

  let caseStmt = nnkCaseStmt.newTree(getCurrentBranch(valueIdent))
  for branch in n[1 .. ^1]:
    case branch.kind
    of nnkOfBranch:
      let body = newStmtList(
        newCall(bindSym"?=", branch[0], valueIdent),
        branch[1]
      )
      caseStmt &= nnkOfBranch.newTree(branch[0][0], body)
    of nnkElse:
      caseStmt &= branch
    else:
      "Unexpected node".error(branch)
  result &= caseStmt
