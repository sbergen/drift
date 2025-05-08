import drift
import drift/actor
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}

// Erlang part

pub fn new() -> Subject(Input) {
  let assert Ok(actor) =
    actor.using_io(fn() { #(Nil, process.new_selector()) }, fn(state, _) {
      actor.IoOk(state)
    })
    |> actor.start(100, State(None), handle_input)

  actor
}

// Generic part

pub type Input {
  Echo(String, drift.Deferred(String))
  // NOTE: This supports only a single caller ATM
  EchoAfter(String, Int, drift.Deferred(String))
  FinishEcho(String)
}

type State {
  State(delayed: Option(drift.Deferred(String)))
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
      |> drift.replace_state(State(Some(reply_to)))
      |> drift.start_timer(drift.Timer(now + after, FinishEcho(value)))

    FinishEcho(value) ->
      step
      |> drift.continue(fn(state) {
        case state.delayed {
          Some(reply_to) -> step |> drift.resolve(reply_to, value)
          None -> step
        }
      })
  }
}
