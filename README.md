# Casserole 

Library that adds support for sum types/case objects with pattern matching. 
Also integrates with `std/options` for easy integration with existing code.

WIP so expect (and report) bugs that you encounter

## Example

```nim
import caseobj
import std/random

type
  Result*[T, E] {.cased.} = object
    case
    of Ok:
      value: T
    of Error: 
      error: E

# Looks like any other type
proc possiblyFails(): Result[int, string] =
  if sample([true, false]):
    # Constructed by referencing the type and the branch
    Result[int, string].Ok(rand(100))
  else:
    Result[int, string].Error("Failed for some reason =(")

let res = possiblyFails()

# Can extract via pattern matching with `if`/`case` statements
if Ok(randVal) ?= res:
  echo "We got: " & $randVal
  
# Case statements check for exhaustiveness
case res
of Ok(randVal):
  echo "Was something"
of Error(error):
  echo "It failed"
```
