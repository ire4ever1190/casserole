## This library supports making sum types without needing a separate enum with like variants.
## This gives support for having fields with the same name along with safe unpacking of values
runnableExamples:
  type
    # Types have the {.cased.} pragma to generate a sum type
    Optional*[T] {.cased.} = object
      # No need for an enum, just declare the branches!
      case
      of Some:
        # Can store multiple fields, in this example we just have the field `value`
        value: T
      of None: nil

  # The syntax of Object.Branch(...params) is used to construct the object
  let some = Optional[string].Some("hello")

  # You can then unpack a value inline (This throws a FieldDefect if you are wrong!)
  Some(value) ?= some
  assert value == "hello"

  # You can also safely unpack via if statements/expressions
  if Some(value) ?== some:
    echo "Safely got: " & value

  # Or case statements/expressions
  case some
  of Some(value):
    echo "Its " & value
  of None():
    echo "There was no value =("

import std/[macros, strutils, tables, sequtils]

{.experimental: "dotOperators".}




type
  CaseObject*[D] = object of RootObj
    ## Type class for accepting a case object

proc getTagIdent(tag: string): NimNode =
  ## Returns the identifier for a tag
  return tag.toLowerAscii().ident

proc collectFields(pattern: NimNode): seq[tuple[ident: NimNode, index: int]] =
  ## Returns all the fields in a pattern.
  ## - `ident`: what identifier it should be unpacked into
  ## - `index`: Index into the tuple of the branch this field belongs to

  for i in 1 ..< pattern.len:
    result &= (pattern[i], i - 1)

macro `?=`*(lhs: untyped, rhs: CaseObject): untyped =
  ## Unpacks a cased object into an expected type.
  ## Raises a field defect if its the wrong type
  result = nnkLetSection.newTree()

  let branch = newDotExpr(rhs, lhs[0].strVal.getTagIdent())

  for i in 1 ..< lhs.len:
    result &= newIdentDefs(lhs[i], newEmptyNode(), nnkBracketExpr.newTree(branch, newLit i - 1))

macro `?==`*(lhs: untyped, rhs: CaseObject): bool =
  ## Like [?=] except doesn't raise an error. This is meant
  ## to be used inside `if` statements for unpacking a value.
  ## Variables will still be added to scope for wrong branch, but won't be initialised
  let
    branch = newDotExpr(rhs, lhs[0].strVal.getTagIdent())
    rightBranch = newCall(ident"==", newDotExpr(rhs, ident"kind"), lhs[0])

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

block:
  type
    OptionalTag = enum
      Some
      None
    Optional[T] = object of CaseObject[OptionalTag]
      case kind: OptionalTag
      of Some:
        some: (T,)
      of None:
        none: tuple[]

# proc add(parent: NimNode, children: openArray[NimNode]) =
#   for child in children:
#     parent &= child

proc newBracketExpr(a, b: NimNode): NimNode =
  ## Helper syntax for making bracket expr
  return nnkBracketExpr.newTree(a, b)

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
  echo result.toStrLit
  echo result.treeRepr
