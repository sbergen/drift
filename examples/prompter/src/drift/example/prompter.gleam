//// Very simple example of a functional core using drift.
//// Doesn't do anything useful, just provides some async logic and timers.

import drift
import drift/effect.{type Action, type Effect}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The state of our logic. This can be opaque.
pub opaque type State {
  State(
    completed_answers: List(String),
    active_prompt: Option(Effect(Result(Nil, String))),
  )
}

pub fn new_state() -> State {
  State([], None)
}

/// Input type for any input we can handle.
pub type Input {
  StartPrompt(String, Effect(Result(Nil, String)))
  UserEntered(String)
  Stop
  Handle(InternalInput)
}

/// Outputs to be applied in the wrapping context
pub type Output {
  Prompt(String)
  CancelPrompt
  Print(String)
  CompletePrompt(Action(Result(Nil, String)))
}

/// Opaque type to hide inputs that shouldn't be used from the outside
pub opaque type InternalInput {
  TimeOut
}

type Context =
  drift.Context(Input, Output)

type Step =
  drift.Step(State, Input, Output, Nil)

/// The input handler function, which is used differently,
/// depending on the context it is used in.
pub fn handle_input(context: Context, state: State, input: Input) -> Step {
  case input {
    UserEntered(text) ->
      case state.active_prompt {
        Some(complete) ->
          context
          |> drift.perform(CompletePrompt, complete, Ok(Nil))
          |> drift.output(CancelPrompt)
        None -> panic as "No deferred value to resolve!"
      }
      |> drift.cancel_all_timers()
      |> drift.continue(
        State(..state, completed_answers: [text, ..state.completed_answers]),
      )

    StartPrompt(prompt, result) -> {
      let #(context, _) =
        case state.active_prompt {
          Some(complete) ->
            context
            |> drift.perform(
              CompletePrompt,
              complete,
              Error("Canceled by new prompt!"),
            )
            |> drift.output(CancelPrompt)
          None -> context
        }
        |> drift.output(Prompt(prompt))
        |> drift.start_timer(2000, Handle(TimeOut))

      context |> drift.continue(State(..state, active_prompt: Some(result)))
    }

    Stop ->
      context
      |> drift.output(Print("Your answers were:"))
      |> drift.output(Print(
        state.completed_answers
        |> list.reverse
        |> string.join("\n"),
      ))
      |> drift.output(CancelPrompt)
      |> drift.stop()

    Handle(TimeOut) ->
      case state.active_prompt {
        Some(complete) ->
          context
          |> drift.perform(CompletePrompt, complete, Error("Stopping!"))
        None -> context
      }
      |> drift.output(Print("Too slow!"))
      |> drift.output(CancelPrompt)
      |> drift.stop()
  }
}
