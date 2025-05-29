import drift
import drift/effect.{type Action, type Effect}
import gleam/string
import gleeunit/should

pub fn continuation_test() {
  let #(stepper, _) = drift.new("", Nil, Nil)
  let discard = effect.from(fn(_) { Nil })

  let assert drift.Continue([FetchString(fetch1)], stepper, _) =
    drift.step(stepper, 0, Append(1, discard), handle_input)

  let assert drift.Continue([FetchString(fetch2)], stepper, _) =
    drift.step(stepper, 0, Append(2, discard), handle_input)

  let assert drift.Continue([CompleteAppend(complete1)], stepper, _) =
    drift.step(stepper, 0, ReceivedString(fetch2, "wibble"), handle_input)

  let assert drift.Continue([CompleteAppend(complete2)], _stepper, _) =
    drift.step(stepper, 0, ReceivedString(fetch1, "wobble"), handle_input)

  complete1.argument |> should.equal("wibblewibble")
  complete2.argument |> should.equal("wibblewibblewobble")
}

type Error =
  Nil

type State =
  String

type Continuation(a) =
  drift.Continuation(a, State, Input, Output, Error)

type Input {
  Append(Int, Effect(String))
  ReceivedString(Continuation(String), String)
}

type Output {
  FetchString(Continuation(String))
  CompleteAppend(Action(String))
}

fn handle_input(
  context: drift.Context(Input, Output),
  state: State,
  input: Input,
) -> drift.Step(State, Input, Output, Nil) {
  case input {
    Append(times, complete) -> {
      use context, state, response <- drift.await(context, state, FetchString)
      let state = state <> string.repeat(response, times)
      context
      |> drift.perform(CompleteAppend, complete, state)
      |> drift.continue(state)
    }
    ReceivedString(continuation, result) -> {
      drift.resume(context, state, continuation, result)
    }
  }
}
