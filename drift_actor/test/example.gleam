import drift.{type Deferred}
import drift/actor
import gleam/erlang/process.{type Selector}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import input

// This part is specific to Erlang and actors

pub fn main() -> Nil {
  let assert Ok(actor) =
    actor.using_io(new_io_driver, fn(driver, output) {
      case output {
        Prompt(prompt) -> {
          // Simulate async I/O
          let reply_to = process.new_subject()
          process.spawn(fn() {
            let assert Ok(result) = input.input(prompt)
            process.send(reply_to, result)
          })

          actor.InputSelectorChanged(
            driver,
            process.new_selector()
              |> process.select_map(reply_to, UserEntered),
          )
        }

        Print(text) -> {
          io.println(text)
          actor.IoOk(driver)
        }
      }
    })
    |> actor.start(1000, new_state(), handle_input)

  let assert Ok(_) =
    actor.call_forever(actor, StartPrompt("What's your name? ", _))
  let assert Ok(_) =
    actor.call_forever(actor, StartPrompt("Who's the best? ", _))

  process.send(actor, Stop)

  case process.subject_owner(actor) {
    Ok(actor_pid) -> wait_for_process(actor_pid)
    Error(_) -> Nil
  }
}

fn wait_for_process(pid: process.Pid) -> Nil {
  case process.is_alive(pid) {
    False -> Nil
    True -> {
      process.sleep(10)
      wait_for_process(pid)
    }
  }
}

fn new_io_driver() -> #(IoDriver, Selector(Input)) {
  #(IoDriver(io.println), process.new_selector())
}

type IoDriver {
  IoDriver(output: fn(String) -> Nil)
}

// Everything below is agnostic of I/O and timer implementations.
// It will echo everything with a one second delay (yes, it's ugly)
// and print all lines when Stop is triggered.

type State {
  State(
    completed_answers: List(String),
    active_prompt: Option(Deferred(Result(Nil, String))),
  )
}

type Input {
  StartPrompt(String, Deferred(Result(Nil, String)))
  UserEntered(String)
  TimeOut
  Stop
}

type Output {
  Prompt(String)
  Print(String)
}

type Context =
  drift.Context(Input, Output)

type Step =
  drift.Step(State, Input, Output, Nil)

fn new_state() -> State {
  State([], None)
}

fn handle_input(context: Context, state: State, input: Input) -> Step {
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
