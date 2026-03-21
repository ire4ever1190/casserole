## This module implements support for using [std/options](https://nim-lang.org/docs/options.html)
## with pattern matching
runnableExamples:
  import casserole
  import std/options

  proc tryGet[T](items: openArray[T], i: int): Option[T] =
    ## Tries to get a value at index `i`. Returns `None`
    ## if index is out of range
    if i in 0 ..< items.len:
      some(items[i])
    else:
      none(T)

  let items = @[1, 2, 3]

  # Can unpack directly, not much different to `.get()`
  Some(firstValue) ?= items.tryGet(0)

  # Now we can check and unpack in a single call
  if Some(mightExist) ?== items.tryGet(1):
    echo mightExist


import std/options

type
  OptionTag* = enum
    Some ## When `Option` has a value
    None ## When `Option` has no value

template getBranch*(o: Option, branch: static[OptionTag]): tuple =
  ## Returns either the value or an empty tuple
  when branch == Some:
    (value: o.get())
  else:
    default(tuple[])

template currentBranch*(o: Option): OptionTag =
  ## Maps `Option` to an `OptionTag`
  if o.isSome(): Some else: None
