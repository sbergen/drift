import drift
import drift/actor
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

// Erlang part

pub fn new() -> Subject(Input) {
  let assert Ok(actor) =
    actor.without_io()
    |> actor.start(100, State(0, dict.new()), handle_input)

  actor
}

// Generic part

pub type Input {
  Echo(String, drift.Deferred(String))
  EchoAfter(String, Int, drift.Deferred(String))
  FinishEcho(Int, String)
}

type State {
  State(id: Int, calls: Dict(Int, drift.Deferred(String)))
}

type Step =
  drift.Step(State, Input, Nil, Nil)

fn handle_input(step: Step, now: drift.Timestamp, input: Input) -> Step {
  case input {
    Echo(value, to) ->
      step
      |> drift.resolve(to, value)

    EchoAfter(value, after, reply_to) ->
      step
      |> drift.continue(fn(state) {
        step
        |> drift.start_timer(drift.Timer(
          now + after,
          FinishEcho(state.id, value),
        ))
        |> drift.replace_state(State(
          state.id + 1,
          dict.insert(state.calls, state.id, reply_to),
        ))
      })

    FinishEcho(id, value) ->
      step
      |> drift.continue(fn(state) {
        case dict.get(state.calls, id) {
          Ok(reply_to) -> step |> drift.resolve(reply_to, value)
          Error(_) -> step
        }
      })
  }
}
