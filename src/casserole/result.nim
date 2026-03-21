## Basic `Result[T, E]` style object that holds either a value or an error.
## This is useful when you want the caller to handle the error instead of bubbling
## it as an exception

import ../casserole

type
  Result[T, E] {.cased.} = tuple[
    Ok: T,
    Error: E
  ]

func ok*[T, E](res: out Result[T, E], val: T) =
  ## Initialises an existing result with `Ok` value.
  ## Useful for assigning the return variable
  res = Result[T, E].Ok(val)

func error*[T, E](res: out Result[T, E], err: E) =
  ## Initialises an existing result with `Error` value.
  ## Useful for assigning the return variable
  res = Result[T, E].Error(err)

template ok(val): Result =
  ## Infers the `Result` type based on the `result` variable
  result.ok(val)
  result

template error(err): Result =
  ## Infers the `Result` type based on the `result` variable
  result.error(err)
  result

template `?`*[T, E](res: Result[T, E]): T =
  ## Syntax sugar which returns `res` if its an error and returns
  ## the value if its ok
  case res
  of Ok(val): val
  of Error(_): return res

template catchEm[T](body: T): Result[T, CatchableError] =
  ## Runs `body` and catches any exceptions that are thrown.
  ## Defects are not caught and will bubble through
  runnableExamples:
    proc someExceptionalFunction() =
      raise (ref ValueError)(msg: "Did something wrong")

    # No exception bubbles past, we have caught it
    let val = catchEm(someExceptionalFunction())

    # We can now inspect it
    Error(err) ?= val
    assert err.msg == "Did something wrong"

  try:
    ok(body)
  except CatchableError as e:
    error(e)

proc `or`*[T, E0, E1](first: Result[T, E0], second: Result[T, E1]): Result[T, E1] =
  ## First tries to access the value in first, if that fails then it attempts to get it from the second.
  ## Returns the second error if both fail
  case first
  of Ok(_): first
  of Error(_):
    case second
    of Ok(_): second
    of Error(_): second
