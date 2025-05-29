# drift_js

[![Package Version](https://img.shields.io/hexpm/v/drift_js)](https://hex.pm/packages/drift_js)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/drift_js/)

`drift_js` provides a runtime for running `drift` steppers on JavaScript targets.

```sh
gleam add drift@1
gleam add drift_js@1
gleam add gleam_javascript@1
```
```gleam
import drift
import drift/js/runtime
import gleam/javascript/promise.{type Promise}
import gleam/option.{None, Some}

pub fn main() -> Promise(Nil) {
  // Start a stepper that adds all the numbers sent to it,
  // until None is encountered
  let #(result, rt) =
    runtime.start(
      0,
      fn(_runtime) {
        // We don't have any IO state in this example.
        Nil
      },
      fn(ctx, state, input) {
        case input {
          Some(input) -> drift.continue(ctx, state + input)
          None -> drift.stop(ctx, state)
        }
      },
      fn(ctx, _output, _send) {
        // There are no outputs, so we just return ok.
        Ok(ctx)
      },
    )

  runtime.send(rt, Some(40))
  runtime.send(rt, Some(2))
  runtime.send(rt, None)

  use sum <- promise.await(result)

  // Prints "Terminated(42)"
  echo sum

  promise.resolve(Nil)
}
```

