# Casserole 🍲

[Docs with examples](https://ire4ever1190.github.io/casserole/develop/casserole.html)

### Overview

Library that adds support for sum types/case objects with pattern matching. 

Features
- Sum types
- Pattern matching
- Pattern matching for `std/options`, `std/macros`, and `std/json`

### Example

```nim
import pkg/casserole
import std/options

let val = some("foo")

if Some(x) ?== val:
  echo x
```
