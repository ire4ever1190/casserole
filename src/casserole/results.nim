## Basic `Result[T, E]` style object that holds either a value or an error.
## This is useful when you want the caller to handle the error instead of bubbling
## it as an exception.
##
## Based a lot on [results](https://github.com/arnetheduck/nim-results/blob/master/results.nim) by arnetheduck

import ../casserole
import std/sugar

type
  Result*[T, E] {.cased.} = tuple
    Ok: T ## A value is contained, no issues
    Error: E ## Something happened and there is an error that should be checked

func ok*[T, E](res: out Result[T, E], val: T) =
  ## Initialises an existing result with `Ok` value.
  ## Useful for assigning the return variable
  runnableExamples:
    proc main(): Result[string, int] =
      result.ok("Hello World")
    assert Ok(_) ?== main()

  res = Result[T, E].Ok(val)

func error*[T, E](res: out Result[T, E], err: E) =
  ## Initialises an existing result with `Error` value.
  ## Useful for assigning the return variable
  runnableExamples:
    proc main(): Result[string, int] =
      result.error(QuitFailure)
    assert Error(_) ?== main()

  res = Result[T, E].Error(err)

func map*[T, R, E](res: Result[T, E], body: T -> R): Result[R, E] {.effectsOf: body.}=
  ## Performs an operation on a result (if it didn't fail) and returns that
  ## as a new result
  case res
  of Error(_): res
  of Ok(val): ok(body(val))

func flatMap*[T, R, E](res: Result[T, E], body: T -> Result[R, E]): Result[R, E] {.effectsOf: body.} =
  ## Like [map] except it flattens the result
  case res
  of Error(_): res
  of Ok(val): body(val)

template ok*(val): Result =
  ## Infers the `Result` type based on the `result` variable
  runnableExamples:
    proc main(): Result[string, int] =
      ok("Hello World")
  result.ok(val)
  result

template error*(err): Result =
  ## Infers the `Result` type based on the `result` variable
  runnableExamples:
    proc main(): Result[string, int] =
      error(QuitFailure)
  result.error(err)
  result

template `?`*[T, E](res: Result[T, E]): T =
  ## Syntax sugar which returns `res` if its an error and returns
  ## the value if its ok
  runnableExamples:
    proc mightFail(inp: int): Result[int, string] =
      if inp > 10: error("Too high: " & $inp)
      else: ok(inp * 2)

    proc someCalc(): Result[int, string] =
      # First call passes, but second call fails and causes whole function to return
      ok ?mightFail(4) + ?mightFail(15)

    Error(msg) ?= someCalc()
    assert msg == "Too high: 15"

  case res
  of Ok(val): val
  of Error(_): return res

template catchEm*[T](body: T): Result[T, ref CatchableError] =
  ## Runs `body` and catches any exceptions that are thrown.
  ## Defects are not caught and will bubble through
  runnableExamples:
    proc someExceptionalFunction(): Result[string, ref CatchableError] =
      raise (ref ValueError)(msg: "Did something wrong")

    # No exception bubbles past, we have caught it
    let val = catchEm(someExceptionalFunction())

    # We can now inspect it
    Error(err) ?= val
    assert err.msg == "Did something wrong"

  try:
    Result[T, ref CatchableError].Ok(body)
  except CatchableError as e:
    Result[T, ref CatchableError].Error(e)

proc `or`*[T, E0, E1](first: Result[T, E0], second: Result[T, E1]): Result[T, E1] =
  ## First tries to access the value in first, if that fails then it attempts to get it from the second.
  ## Returns the second error if both fail
  case first
  of Ok(_): first
  of Error(_):
    case second
    of Ok(_): second
    of Error(_): second

export casserole
