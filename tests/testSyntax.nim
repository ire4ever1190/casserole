# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, options, macros, json, setutils]

import casserole
import casserole/nimNodeSupport
import casserole/jsonNodeSupport

type
  Maybe*[L, R] {.cased.} = object
    case
    of Left:
      left: L
    of Right:
      right: R

  Node {.cased.} = tuple[
    Int: int,
    String: string,
    Void: nil,
    List: seq[Node]
  ]

suite "Unpacking":
  let
    someValue = Maybe[string, int].Left("hello")
    noValue = Maybe[string, int].Right(9)


  test "Can unpack directly":
    Left(value) ?= someValue
    check value == "hello"

  test "Can pattern match against value":
    check Left("hello") ?== Maybe[string, string].Left("hello")

  test "Can ignore a field":
    Left(_) ?= someValue
    check not declared(_)

  test "Can directly check":
    Left("hello") ?= someValue

  test "FieldDefect raised if checks fail":
    expect FieldDefect:
      Left("notHello") ?= someValue

  test "Can unpack via branch":
    let default = if Left(value) ?== someValue: value
                  else: "Some default"

    check default == "hello"

  test "Can safely unpack via branch":
    let default = if Left(value) ?== noValue: value
                  else: "Some default"
    check default == "Some default"

  test "Can unpack via a case statement":
    let value = case someValue
                of Left(value): value
                else: "Nothing"
    check value == "hello"

  test "Case statements can drop paranthesis":
    case some(9)
    of None: discard # Not needed since there are no fields
    of Some(_): discard # Needed because it has a field

  test "Case statements can be exhaustive":
    # The test is if this compiles
    let value = case noValue
                # Everything can be binded, so we've caught all the cases
                of Left(value): value
                of Right(1234): "Should never match"
                of Right(value): "Nothing"
    check value == "Nothing"

  test "Can compare values in case statements":
    check case someValue
          of Left("hello"): true
          of Right(_): false

  test "Can compare multiple values":
    check case someValue
          of Left("not hello"): false
          of Left(_): true
          of Right(_): false


  test "Can ignore values with `_`":
    let value = case noValue
                of Left(_): "left"
                of Right(_): "right"
    check value == "right"

  test "Raises branch defect for wrong branch":
    expect FieldDefect:
      Left(_) ?= Maybe[int, int].Right(1)

suite "Shorthand construction syntax":
  test "Can use short hand syntax":
    let id = Node.Int(1)
    Int(num) ?= id
    check num == 1

  test "Can use `nil` fields":
    let nothing = Node.Void()
    check Void() ?== nothing

suite "Wrapping Option":
  let
    someVal = some("hello")
    noneVal = none(string)

  test "Type is considered cased":
    check Option[string] is CasedObject

  test "Some can be unpacked directly":
    Some(v) ?= someVal
    check v == someVal.get()

  test "If statements work":
    let v = if Some(val) ?== someVal: val
            else: "Nothing"
    check v == someVal.get()

  test "Case statements work":
    let v = case noneVal
            of None: "Got nothing"
            of Some(v): v
    check v == "Got nothing"

suite "Wrapping NimNode":
  test "Type is considered cased":
    check NimNode is CasedObject

  test "Basic node":
    macro foo(x: untyped): string =
      let val = if StrLit(inner) ?== x: inner
                else: "Not Right"
      return newLit val

    check foo("hello") == "hello"
    check foo(9) == "Not Right"

suite "Wrapping JsonNode":
  test "Type is considered cased":
    check JsonNode is CasedObject

  test "Can match JString":
    let jsonStr = %"hello"
    let result = if JString(val) ?== jsonStr: val
                 else: "default"
    check result == "hello"

import ./auxOtherFile
test "Can import another type":
  check A(9) ?== SomeType.A(9)

suite "Comparison":
  test "Same branch and values are equal":
    check SomeType.A(9) == SomeType.A(9)
  test "Same branch and different values are not equal":
    check SomeType.A(1) != SomeType.A(2)
  test "Different branch are not equal":
    check SomeType.A(1) != SomeType.B("Hello")

test "Enum unrolling":
  type
    E = enum
      A
      B
      C
  var items: set[E]
  for item in unrollEnum(E):
    items.incl(item)
  check items == fullSet(E)
