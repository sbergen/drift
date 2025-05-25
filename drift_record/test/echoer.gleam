//// Simple example using effects and actions

import drift
import drift/effect.{type Action, type Effect}

pub type Input {
  Echo(Effect(String), String)
}

pub type Output {
  Reply(Action(String))
}

pub fn handle_input(
  context: drift.Context(Input, Output),
  state: Nil,
  input: Input,
) -> drift.Step(Nil, Input, Output, String) {
  let Echo(complete, value) = input

  context
  |> drift.perform(Reply, complete, value)
  |> drift.continue(state)
}
