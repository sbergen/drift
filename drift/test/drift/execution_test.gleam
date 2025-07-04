import drift

pub fn stop_test() {
  let #(stepper, _) = drift.new(40, Nil)
  let assert drift.Stop([84], 42) =
    drift.step(stepper, 0, 2, fn(ctx, state, input) {
      let sum = state + input
      ctx
      |> drift.output(2 * sum)
      |> drift.stop(sum)
    })
}

pub fn stop_with_error_test() {
  let #(stepper, _) = drift.new(40, Nil)
  let assert drift.StopWithError([84], "failed") =
    drift.step(stepper, 0, 2, fn(ctx, state, input) {
      let sum = state + input
      ctx
      |> drift.output(2 * sum)
      |> drift.stop_with_error("failed")
    })
}

pub fn chain_test() {
  let #(stepper, _) = drift.new(10, Nil)
  let assert drift.Stop([10, 100], 200) =
    drift.step(stepper, 0, 0, fn(ctx, state, _) {
      use ctx, state <- drift.chain(square(ctx, state))
      use ctx, state <- drift.chain(double(ctx, state))
      drift.stop(ctx, state)
    })
}

fn double(
  ctx: drift.Context(Int, Int),
  state: Int,
) -> drift.Step(Int, Int, Int, _) {
  ctx
  |> drift.output(state)
  |> drift.continue(2 * state)
}

fn square(
  ctx: drift.Context(Int, Int),
  state: Int,
) -> drift.Step(Int, Int, Int, _) {
  ctx
  |> drift.output(state)
  |> drift.continue(state * state)
}
