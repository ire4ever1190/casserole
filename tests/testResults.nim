import casserole
import casserole/results

import std/unittest

type SimpleError[T] = Result[T, string]

test "Can return ok value":
  proc hello(): SimpleError[int] =
    result.ok(1)
  Ok(val) ?= hello()
  check val == 1
