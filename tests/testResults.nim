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

test "No issues if user has type called `Error`":
  proc hello(): Result[int, string] =
    result.error("Bad")
  Error(val) ?= hello()
  check val == "Bad"
