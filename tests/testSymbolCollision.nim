## Ran into a lot of issues with symbol collision bugs

import std/[unittest, options]
import casserole
import casserole/results
import ./auxOtherFile

func id(i: int): Option[string] =
  some "hello"

type
  SomeSum {.cased.} = tuple
    Foo: int
    Bar: int

suite "Name doesn't bind when inside a generic":

  test "If unpacking":
    proc ifGeneric[T](x: T): string =
      if Some(a) ?== 9.id(): a else: ""
    check ifGeneric(1) == "hello"

  test "Case unpacking":
    proc caseGeneric(x: Option): string =
      case x
      of Some(a): a
      else: ""
    check caseGeneric(some("hello")) == "hello"

  test "Case unpacking with type not visible to `?=` macro":
    proc caseGeneric[T](x: T): int =
      case SomeSum.Foo(1)
      of Foo(a): a
      else: 1
    check caseGeneric(some[string]("hello")) == 1

  test "Raw unpacking":
    proc unpackGeneric[T](x: T): string =
      Some(a) ?= 9.id()
      a

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

  test "Branches in case statements don't have issues with collisions":
    let idk = case hello()
              of Error(val): val
              of Ok(_): "Was fine?"
    check idk == "Bad"

  test "Can create object":
    let err = Result[int, Error].Error(Error(msg: "Hello"))
    Error(val) ?= err
    check val == Error(msg: "Hello")
