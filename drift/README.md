# drift

[![Package Version](https://img.shields.io/hexpm/v/drift)](https://hex.pm/packages/drift)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/drift/)

Drift is a Gleam library for creating asynchronous pure functional cores,
which can be wrapped with different I/O and timer implementations.
These cores can be used on both the Erlang and JavaScript targets.
Side effects are tracked by producing outputs on every step,
and executing the side effects is left to be done by a wrapping runtime.

## When to use drift?

You might want to use drift if:
* You have logic written in Gleam you want to run on both Erlang and JS,
  or in environments with very different I/O in some other way.
* Your logic has a lot of I/O or timers interleaved with other logic.
* You want to run deterministic (snapshot) tests on your logic.

You might want to _avoid_ drift if:
* Your I/O and timer logic is simple, with little interleaving.
  In this case, you can probably easily separate the pure parts without using
  drift, making the implementation simpler.
* You care a lot about performance. Given how drift is built,
  it will always have some performance overhead.

## Related packages

* [`drift_actor`](https://hexdocs.pm/drift_actor/) wraps a core written with drift in an OTP actor.
* [`drift_js`](https://hexdocs.pm/drift_js/) wraps a core written with drift in an event loop on the JS target.
* [`drift_record`](https://hexdocs.pm/drift_record/) contains utilities to record the inputs and 
  outputs of a drift core in a snapshot-testing friendly manner.

## Examples

You can find more comprehensive examples of how to use drift in the 
[`examples`](https://github.com/sbergen/drift/tree/main/examples)
directory in the repository.
The limited example below demonstrates the core concept of a stepper.

```sh
gleam add drift@1
```
```gleam
import drift
import gleam/option.{type Option, None, Some}

pub fn main() {
  // Start a new stepper with no IO/effects
  let #(stepper, _effect_ctx) = drift.new(0, Nil)

  // Handle a few steps.
  // Drift also supports timers and promise-like continuations.
  // Since we aren't using timers, we pass 0 as the timestamp.
  let assert drift.Continue([40], stepper, None) =
    drift.step(stepper, 0, Some(40), sum_numbers)

  let assert drift.Continue([42], stepper, None) =
    drift.step(stepper, 0, Some(2), sum_numbers)

  let assert drift.Stop([], 42) = drift.step(stepper, 0, None, sum_numbers)
}

fn sum_numbers(
  ctx: drift.Context(Option(Int), Int),
  state: Int,
  input: Option(Int),
) -> drift.Step(Int, Option(Int), Int, Nil) {
  case input {
    Some(number) -> {
      let sum = state + number
      ctx
      |> drift.output(sum)
      |> drift.continue(sum)
    }
    None -> drift.stop(ctx, state)
  }
}
```
