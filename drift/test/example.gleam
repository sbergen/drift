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
