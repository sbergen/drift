import drift
import drift/actor
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

// Erlang part

pub fn new() -> Subject(Input) {
  let assert Ok(actor) =
    actor.using_io(fn() { #(Nil, process.new_selector()) }, fn(ctx, output) {
      let ApplyEcho(effect, value) = output
      actor.IoOk(drift.apply(ctx, effect, value))
    })
    |> actor.start(100, State(0, dict.new()), handle_input)

  actor
}

// Generic part

pub type Input {
  Echo(String, drift.Effect(String))
  EchoAfter(String, Int, drift.Effect(String))
  FinishEcho(Int, String)
}

pub type Output {
  ApplyEcho(drift.Effect(String), String)
}

type State {
  State(id: Int, calls: Dict(Int, drift.Effect(String)))
}

type Context =
  drift.Context(Input, Output)

type Step =
  drift.Step(State, Input, Output, Nil)

fn handle_input(context: Context, state: State, input: Input) -> Step {
  case input {
    Echo(value, reply_to) ->
      context
      |> drift.output(ApplyEcho(reply_to, value))
      |> drift.with_state(state)

    EchoAfter(value, after, reply_to) -> {
      let #(context, _) =
        drift.handle_after(context, after, FinishEcho(state.id, value))
      drift.with_state(
        context,
        State(state.id + 1, dict.insert(state.calls, state.id, reply_to)),
      )
    }

    FinishEcho(id, value) ->
      case dict.get(state.calls, id) {
        Ok(reply_to) -> context |> drift.output(ApplyEcho(reply_to, value))
        Error(_) -> context
      }
      |> drift.with_state(state)
  }
}
