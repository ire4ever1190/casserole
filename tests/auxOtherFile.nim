## Auxillary file so we can test pulling in symbols from other modules
import casserole


type
  SomeType* {.cased.} = tuple
    A: int
    B: string
