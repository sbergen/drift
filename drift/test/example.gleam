import drift
import gleam/option.{type Option, None, Some}

pub fn main() {
  // Start a new stepper with no IO
  let #(stepper, _effect_ctx) = drift.new(0, Nil)

  // Handle a few step.
  // Drift also supports timers, which aren't use here!
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
