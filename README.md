# Casserole 🍲

[Docs with examples](https://ire4ever1190.github.io/casserole/develop/casserole.html)

> [!NOTE]
> Sumtypes are an [official feature](https://nim-lang.org/docs/manual.html#types-sum-types) in Nim 2.4.0
> You'll likely want to use that instead

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
