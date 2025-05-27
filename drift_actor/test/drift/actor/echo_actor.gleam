import drift
import drift/actor
import drift/effect.{type Action, type Effect}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

// Erlang part

pub fn new() -> Subject(Input) {
  let assert Ok(actor) =
    actor.using_io(fn() { #(Nil, process.new_selector()) }, fn(ctx, output) {
      let ApplyEcho(action) = output
      actor.IoOk(effect.perform(ctx, action))
    })
    |> actor.start(100, State(0, dict.new()), handle_input)

  actor
}

// Generic part

pub type Input {
  Echo(String, Effect(String))
  EchoAfter(String, Int, Effect(String))
  FinishEcho(Int, String)
}

pub type Output {
  ApplyEcho(Action(String))
}

type State {
  State(id: Int, calls: Dict(Int, Effect(String)))
}

type Context =
  drift.Context(Input, Output)

type Step =
  drift.Step(State, Input, Output, Nil)

fn handle_input(context: Context, state: State, input: Input) -> Step {
  case input {
    Echo(value, reply_to) ->
      context
      |> drift.perform(ApplyEcho, reply_to, value)
      |> drift.continue(state)

    EchoAfter(value, after, reply_to) -> {
      let #(context, _) =
        drift.start_timer(context, after, FinishEcho(state.id, value))
      drift.continue(
        context,
        State(state.id + 1, dict.insert(state.calls, state.id, reply_to)),
      )
    }

    FinishEcho(id, value) ->
      case dict.get(state.calls, id) {
        Ok(reply_to) -> drift.perform(context, ApplyEcho, reply_to, value)
        Error(_) -> context
      }
      |> drift.continue(state)
  }
}
