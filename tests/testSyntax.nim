# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, options]

import casobj

type
  Maybe*[L, R] {.cased.} = object
    case
    of Left:
      left: L
    of Right:
      right: R


suite "Unpacking":
  let
    someValue = Maybe[string, int].Left("hello")
    noValue = Maybe[string, int].Right(9)


  test "Can unpack directly":
    Left(value) ?= someValue
    check value == "hello"

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

  test "Case statements can be exhaustive":
    # The test is if this compiles
    let value = case noValue
                of Left(value): value
                of Right(value): "Nothing"
    check value == "Nothing"

suite "Wrapping Option":
  let
    someVal = some("hello")
    noneVal = none(string)

  test "Some can be unpacked directly":
    Some(v) ?= someVal
    check v == someVal.get()

  test "If statements work":
    let v = if Some(val) ?== someVal: val
            else: "Nothing"
    check v == someVal.get()

  test "Case statements work":
    let v = case noneVal
            of None(): "Got nothing"
            of Some(v): v
    check v == "Got nothing"
