## Ran into a lot of issues with symbol collision bugs

import std/[unittest, options]
import casserole
import casserole/results
import ./auxOtherFile

func id(i: int): Option[string] =
  some "hello"

test "Name doesn't bind when inside a generic":
  proc ifGeneric[T](x: T): string =
    if Some(a) ?== 9.id(): a else: ""

  proc caseGeneric[T](x: T): string =
    case 9.id()
    of Some(a): a
    else: ""

  proc unpackGeneric[T](x: T): string =
    Some(a) ?= 9.id()
    a

  check ifGeneric(1) == "hello"
  check caseGeneric(1) == "hello"
  check unpackGeneric(1) == "hello"


type
  Error = object
    msg: string
  Some = object
    l: int

suite "Symbol binding":
  # Issues found from the results library
  proc hello(): Result[int, string] =
    result.error("Bad")

  test "No issues if user has type called `Error`":

    Error(val) ?= hello()
    check val == "Bad"

  test "No issue with integrated types that have tag collision":
    Some(val) ?= some("hello")

  test "No issues unpacking":
    let idk = case hello()
              of Error(val): val
              of Ok(_): "Was fine?"
    check idk == "Bad"

  test "Can create object":
    let err = Result[int, Error].Error(Error(msg: "Hello"))
    Error(val) ?= err
    check val == Error(msg: "Hello")
