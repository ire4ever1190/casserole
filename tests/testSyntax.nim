# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import casobj

type
  Optional*[T] {.cased.} = object
    case
    of Some:
      value: T
    of None: discard


suite "Unpacking":
  let
    someValue = Optional[string].Some("hello")
    noValue = Optional[string].None()

  test "Can unpack directly":
    Some(value) ?= someValue
    check value == "hello"

  test "Can unpack via branch":
    let default = if Some(value) ?== someValue: value
                  else: "Some default"

    check default == "hello"

  test "Can safely unpack via branch":
    let default = if Some(value) ?== noValue: value
                  else: "Some default"
    check default == "Some default"

  test "Can unpack via a case statement":
    let value = case someValue
                of Some(value): value
                else: "Nothing"
    check value == "hello"
