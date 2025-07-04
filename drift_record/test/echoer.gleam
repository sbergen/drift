//// Simple example using effects and actions

import drift.{type Action, type Effect}
import gleam/list

pub type Input {
  Echo(Effect(String), String, Int)
}

pub type Output {
  Reply(Action(String))
}

pub fn handle_input(
  context: drift.Context(Input, Output),
  state: Nil,
  input: Input,
) -> drift.Step(Nil, Input, Output, String) {
  let Echo(complete, value, times) = input
  let outputs = list.repeat(Reply(drift.bind_effect(complete, value)), times)

  context
  |> drift.output_many(outputs)
  |> drift.continue(state)
}
