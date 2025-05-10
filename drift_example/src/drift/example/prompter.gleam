//// Very simple example of a functional core using drift.
//// Doesn't do anything useful, just provides some async logic and timers.

import drift.{type Deferred}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The state of our logic. This can be opaque.
pub opaque type State {
  State(
    completed_answers: List(String),
    active_prompt: Option(Deferred(Result(Nil, String))),
  )
}

pub fn new_state() -> State {
  State([], None)
}

/// Input type for any input we can handle.
/// Both IO-drive inputs and user-driven inputs need to be publicly constructible.
/// However, if you want to hide e.g. the "time out" command,
/// this type could be made opaque with functions to construct the public variants.
pub type Input {
  StartPrompt(String, Deferred(Result(Nil, String)))
  Stop
  // The result of a prompt (system input)
  UserEntered(String)
  // 
  TimeOut
}

/// Outputs to be applied in the wrapping context
pub type Output {
  Prompt(String)
  Print(String)
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
        Some(deferred) ->
          context
          |> drift.resolve(deferred, Ok(Nil))
        None -> panic as "No deferred value to resolve!"
      }
      |> drift.cancel_all_timers()
      |> drift.with_state(
        State(..state, completed_answers: [text, ..state.completed_answers]),
      )

    StartPrompt(prompt, result) -> {
      let #(context, _) =
        case state.active_prompt {
          Some(deferred) ->
            context |> drift.resolve(deferred, Error("Canceled by new prompt!"))
          None -> context
        }
        |> drift.output(Prompt(prompt))
        |> drift.handle_after(2000, TimeOut)

      context |> drift.with_state(State(..state, active_prompt: Some(result)))
    }

    Stop ->
      context
      |> drift.output(Print("Your answers were:"))
      |> drift.output(Print(
        state.completed_answers
        |> list.reverse
        |> string.join("\n"),
      ))
      |> drift.stop()

    TimeOut ->
      case state.active_prompt {
        Some(deferred) -> context |> drift.resolve(deferred, Error("Stopping!"))
        None -> context
      }
      |> drift.output(Print("Too slow!"))
      |> drift.stop()
  }
}
