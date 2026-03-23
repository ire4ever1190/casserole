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
## I could show you how to make an `Option[T]` type but that would be redundant since this library supports `std/options`!
## This is documented in [optionSupport](casserole/optionSupport.html) and a similar pattern can be follow to support other types
runnableExamples:
  import std/options

  let val = some("Hello")

  if Some(value) ?== val:
    echo value
## This is used to support multiple types from the Nim standard library
## - [Options](casserole/optionSupport.html)
## - [Macros](casserole/nimNodeSupport.html)
## - [JsonNodes](casserole/jsonNodeSupport.html)
##
## There is also a helper library for [result type error handling](casserole/results.html)

import std/[macros, strutils, sequtils, options, typetraits, sugar]

import pkg/libdump/macros

import ./casserole/[optionSupport, nimNodeSupport, jsonNodeSupport]
export optionSupport, jsonNodeSupport

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

type
  PatternType = enum
    Ignored ## `_` parameter that we don't bind to anything or check value
    Binding ## Value gets binded to a parameter
    Value ## Value gets compared against a constant
  PatternField = tuple[ident: NimNode, index: int]
proc collectFields(pattern: NimNode): seq[PatternField] =
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


macro generateCases[D](c: CaseObject[D], discrimValue: D): untyped =
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

macro unrollEnumAux(e: typedesc[enum], itemIdent: static[string], body: untyped) =
  ## Auxillery macro that performs the unrolling.
  ## Needed so we can get type info

  # If we just copied the body then each `item` would just be set to the first value.
  # Instead we make the body a template and call that for each enum value, this way the compiler
  # handles reassigning everything
  let templateIdent = nskTemplate.genSym("iterBody")
  result = newStmtList(
    newProc(templateIdent, [newEmptyNode(), newIdentDefs(ident itemIdent, e)], body = body, procType = nnkTemplateDef),
  )
  let decl = e.getObjectDecl().get()
  for item in decl[1 .. ^1]:
    result &= newBlockStmt(newCall(templateIdent, item))

macro unrollEnum*(body: ForLoopStmt): untyped =
  ## Macro that unrolls an enum and runs the loop body for each instance.
  ## This is unrolled at compile time, so each iteration gets a static version of the value.
  ## Be careful with large enums since the body is copied for each enum value

  if body.len != 3 or body[0].kind notin {nnkIdent, nnkSym}:
    "Expecting for loop with a single variable".error(body)
  if body[1].len != 2:
    "Expecting a single argument containing an enum".error(body[1])
  return newCall(bindSym"unrollEnumAux", body[1][1], newLit body[0].strVal, body[2])

macro grabBranch(obj: CaseObject | CasedObject, branch: typed): enum =
  ## Helper macro to get around typing issues.
  ## If there is an enum branch with same name as the type, then the object is choosen which causes type errors.
  ## We get around this by looking up the type and returning a sym for the exact enum value
  # See if we can lookup the type and find the exact enum
  let decl = obj.getType().getObjectDecl()
  block:
    if decl.isSome():
      let objDecl = decl.get()
      let match = chain(
        ofKind({nnkObjectTy}),
        path({
          1: {nnkOfInherit},
          0: {nnkBracketExpr},
        })
      )
      let enumSym = decl
        .flatMap(match)
        .filter(parent => parent[0].eqIdent("CaseObject"))
        .map(parent => parent[1])
      if enumSym.isSome():
        let branch = if branch.kind == nnkStmtListExpr: branch[^1] else: branch
        return newDotExpr(enumSym.get(), branch)

  # Fall back, just get the enum value and access branch from that
  return newCall(bindSym"typeof", newCall(ident"currentBranch", obj)).newDotExpr(branch)

template grabTag(obj: CaseObject | CasedObject, name: untyped): enum =
  ## Helper for binding a `name` to the actual enum discriminator of `obj`
  ## Helps with symbol resolution issues
  grabBranch(obj, name)

template getBranch*[T: CaseObject](c: T, branch: untyped): tuple =
  ## Generic function that gets the branch value for any [CaseObject]
  generateCases(c, grabTag(c, branch))

template currentBranch*[D; T: CaseObject[D]](c: T): D =
  ## Returns the current state that a [CaseObject] is in
  c.kind

proc `==`*[T: CaseObject](left, right: T): bool =
  ## Compares two [CaseObject] and considers them equal if they
  ## have the same branch and values
  # Inital branch check
  if left.currentBranch() != right.currentBranch():
    return false

  # Now we can safely compare fields
  # TODO: Optimised version that generates a case statement so we don't check every field
  for branch in unrollEnum(typeof(left.currentBranch())):
    if left.currentBranch() == branch:
      return left.getBranch(branch) == right.getBranch(branch)

template branchCheck(obj, branch: untyped) =
  ## Inserts a branch check that raises a `FieldDefect` when accessing invalid branches.
  ## Disabled with `-d:danger`
  when not defined(danger):
    let currentBranch = obj.currentBranch
    # Narrow the type to handle ambigious identifiers (e.g. Result.Ok and TestStatus.Ok)
    let b: typeof(currentBranch) = branch

    if currentBranch != b:
      raise (ref FieldDefect)(msg: "Trying to access " & $b & " but object is " & $currentBranch)

type
  Pattern = object
    tag: string # Identifer pointing to the enum value
    fields: seq[PatternField]

proc parsePattern(node: NimNode): Pattern =
  if node.kind == nnkIdent:
    # Just the tag, don't care about fields
    return Pattern(tag: node.strVal)

  if node.kind != nnkCall or node[0].kind notin {nnkIdent, nnkSym}:
    "Expecting pattern to be in form `Branch(...)`".error(node)

  return Pattern(tag: node[0].strVal, fields: node.collectFields())

macro `?=`*(lhs: untyped, rhs: untyped): untyped =
  ## Unpacks a cased object into an expected type.
  ## Raises a field defect if its the wrong type
  runnableExamples:
    import std/options

    let opt = some(1)
    # Inserts `val` into scope
    Some(val) ?= opt
    assert val == opt.get()

  result = nnkLetSection.newTree()
  let
    pattern = lhs.parsePattern()
    tag = newCall(bindSym"grabTag", rhs, ident pattern.tag)
    branch = getBranch(rhs, tag)

  for (ident, idx) in pattern.fields:
    result &= newIdentDefs(ident, newEmptyNode(), newBracketExpr(branch, newLit idx))

  # We still need to add a check so field defects are thrown for bad branches
  result = newStmtList(
    newCall(bindSym"branchCheck", rhs, tag),
    result
  )

macro `?==`*(lhs: untyped, rhs: untyped): bool =
  ## Like [?=] except doesn't raise an error. This is meant
  ## to be used inside `if` statements for unpacking a value.
  ## Variables will still be added to scope for wrong branch, but won't be initialised
  runnableExamples:
    import std/options
    let opt = none(string)

    # Won't error if wrong branch
    if Some(value) ?== opt:
      # `value` can only be accessed inside if statement
      echo "Great, we have " & $value

  let
    pattern = lhs.parsePattern()
    branch = getBranch(rhs, ident pattern.tag)
    rightBranch = nskLet.genSym("rightBranch")

  result = newStmtList(
    newLetStmt(rightBranch, newCall(ident"==", getCurrentBranch(rhs), ident pattern.tag))
  )

  # First we need to generate all the variables these will get unpacked into.
  # Probs has performance issues since we are creating values even for wrong branch, but oh well
  let unpackBranch = newStmtList()
  for (ident, idx) in pattern.fields:
    # Get a new name, helps with making sure it binds
    let name = ident ident.strVal
    result &= newVarStmt(name, newCall("default", newCall("typeof", nnkBracketExpr.newTree(branch, newLit idx))))
    # Also add the corresponding call to set the variable if its the right branch
    unpackBranch &= newAssignment(name, newBracketExpr(branch, newLit idx))

  result &= nnkIfStmt.newTree(nnkElifBranch.newTree(rightBranch, unpackBranch))

  # Finally, let the user know if its safe to use the values
  result &= rightBranch

proc getBranchEnum[T: CasedObject](c: typedesc[T], e: enum): enum =
  typeof(c).D.e

macro `.()`*(obj: typedesc, tag: untyped, values: varargs[untyped]): untyped =
  ## This is used for constructor a cased object.
  ## Construction is done in the form `Object.Tag(params...)`
  # TODO: Support named field construction
  let tupleConstr = nnkTupleConstr.newTree()
  for value in values:
    tupleConstr &= value
  # TODO: Get a generic way

  result = nnkObjConstr.newTree(
    obj,
    newColonExpr(ident"kind", newCall(bindSym"grabTag", obj, ident tag.strVal)),
    newColonExpr(tag.strVal.getTagIdent(), tupleConstr)
  )

type NodeBranches = seq[tuple[tags: seq[string], fields: seq[NimNode]]]
  ## Store of tags and the IdentDefs that they map to

proc findObjectBranches(objectDecl: NimNode): NodeBranches =
  ## Finds all branches that belong to an object
  let caseNodes = objectDecl[2][0]
  if caseNodes.kind != nnkRecCase:
    "Object must just have a single case statement and no other fields".error(caseNodes)

  for ofBranch in caseNodes[1 .. ^1]:
    let tags = ofBranch[0 ..< ^1].mapIt(it.strVal)
    let fields = ofBranch[^1]
    result &= (tags, fields.mapIt(it))

proc findBranches(node: NimNode): NodeBranches =
  ## Finds all branches to pull from a type
  case node.kind
  of nnkObjectTy:
    node.findObjectBranches()
  of nnkTupleTy:
    for field in node:
      let fields = if field[1].kind == nnkNilLit: @[] else: @[field]
      result &= (@[field[0].strVal], fields)
    result
  else:
    "Only objects and tuples can be turned into sumtypes".error(node)

macro cased*(inp: untyped): untyped =
  ## Generates a case class object based on [RFC#559](https://github.com/nim-lang/RFCs/issues/559)
  runnableExamples:
    type
      Optional[T] {.cased.} = object
        case
        of Some:
          value: T
        of None: discard
  ## There is also a shorthand syntax using tuples if you don't need multiple fields
  ## e.g. This is equivilant notation
  runnableExamples:
    type
      Optional[T] {.cased.} = tuple[
        Some: T,
        None: nil
      ]

  # Pull some info straight from the object
  let
    name = inp[0].basename.strVal
    genericParams = inp[1]
    isRef = inp[2].kind == nnkRefTy
    objectDecl = if isRef: inp[2][0] else: inp[2]
    isPublic = inp[0].isPublic

  proc maybePublic(inp: NimNode): NimNode =
    if isPublic: inp.public else: inp

  # Now gather all the branches. We want the names along with the fields that appear
  var branches = objectDecl.findBranches()

  # Using the possible tags, we need to build the enum
  let enumName = nskType.genSym(name & "Tag")


  let enumDecl = block:
    let body = nnkEnumTy.newTree(newEmptyNode())
    for (tags, _) in branches:
      body &= tags.mapIt(ident it)
    nnkTypeDef.newTree(enumName.maybePublic(), newEmptyNode(), body)

  # Now build the object. It will have each field be the name of the tag
  # with the value being a tuple
  let newObjectDecl = block:
    let caseStmt = nnkRecCase.newTree(newIdentDefs(ident"kind", enumName).maybePublic())
    # Add all the branches
    for (tags, fields) in branches:
      let ofBranch = newNimNode(nnkOfBranch).add(tags.mapIt(ident it))
      # TODO: Support multiple fields
      let fieldName = tags[0].getTagIdent()
      ofBranch &= nnkRecList.newTree(
        newIdentDefs(fieldName.maybePublic(), nnkTupleTy.newTree(fields))
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
  runnableExamples:
    import std/options

    case some(9)
    of Some(_): echo "Have something"
    of None(): echo "Have nothing"

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
      caseStmt &= nnkOfBranch.newTree(newCall(bindSym"grabTag", valueIdent, ident branch[0][0].strVal), body)
    of nnkElse:
      caseStmt &= branch
    else:
      "Unexpected node".error(branch)
  result &= caseStmt

# Extra modules to import so they are included in the docs
import casserole/results
