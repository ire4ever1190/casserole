import casserole
import casserole/results

import std/unittest

type SimpleError[T] = Result[T, string]

type Error = int

test "Can return ok value":
  proc hello(): SimpleError[int] =
    result.ok(1)
  Ok(val) ?= hello()
  check val == 1

suite "Symbol binding": # TODO: Move these tests somewhere more generic
  proc hello(): Result[int, string] =
    result.error("Bad")

  test "No issues if user has type called `Error`":

    Error(val) ?= hello()
    check val == "Bad"

  test "No issues unpacking":
    let idk = case hello()
              of Error(val): val
              of Ok(_): "Was fine?"
    check idk == "Bad"
