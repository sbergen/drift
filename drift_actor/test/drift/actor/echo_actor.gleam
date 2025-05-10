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

type Context =
  drift.Context(Input, Nil)

type Step =
  drift.Step(State, Input, Nil, Nil)

fn handle_input(context: Context, state: State, input: Input) -> Step {
  case input {
    Echo(value, to) ->
      context
      |> drift.resolve(to, value)
      |> drift.with_state(state)

    EchoAfter(value, after, reply_to) ->
      context
      |> drift.handle_after(after, FinishEcho(state.id, value))
      |> drift.with_state(State(
        state.id + 1,
        dict.insert(state.calls, state.id, reply_to),
      ))

    FinishEcho(id, value) ->
      case dict.get(state.calls, id) {
        Ok(reply_to) -> context |> drift.resolve(reply_to, value)
        Error(_) -> context
      }
      |> drift.with_state(state)
  }
}
