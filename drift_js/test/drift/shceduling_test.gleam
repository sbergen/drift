import drift
import drift/js/channel.{type Channel}
import drift/js/runtime
import gleam/javascript/promise.{type Promise}
import gleam/list

type State {
  State(value: Int, remaining_sends: Int)
}

// Checks that a single runtime that sends messages to itself repeatedly
// still allows other runtimes to run.
pub fn multiple_runtime_scheduling_test() -> Promise(Nil) {
  let results = channel.new()
  let #(termination1, runtime1) =
    runtime.start(State(1, 5), fn(_) { results }, handle_input, handle_output)
  let #(termination2, runtime2) =
    runtime.start(State(2, 5), fn(_) { results }, handle_input, handle_output)

  // Kick off the event handling
  runtime.send(runtime1, Nil)
  runtime.send(runtime2, Nil)

  // Wait for termination
  use _ <- promise.await(termination1)
  use _ <- promise.await(termination2)

  assert channel_to_list(results, []) == [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]

  promise.resolve(Nil)
}

fn handle_output(
  context: drift.EffectContext(channel.Channel(Int)),
  value: Int,
  send: fn(Nil) -> Nil,
) -> Result(drift.EffectContext(channel.Channel(Int)), Nil) {
  // Send who was scheduled to results
  let results = drift.read_effect_context(context)
  channel.send(results, value)

  // Trigger another input to be handled
  send(Nil)
  Ok(context)
}

fn handle_input(
  ctx: drift.Context(a, Int),
  state: State,
  _,
) -> drift.Step(State, a, Int, c) {
  case state.remaining_sends {
    0 -> drift.stop(ctx, state)
    remaining_sends ->
      ctx
      |> drift.output(state.value)
      |> drift.continue(State(..state, remaining_sends: remaining_sends - 1))
  }
}

fn channel_to_list(channel: Channel(a), values: List(a)) -> List(a) {
  case channel.try_receive(channel) {
    Ok(value) -> channel_to_list(channel, [value, ..values])
    Error(Nil) -> list.reverse(values)
  }
}
