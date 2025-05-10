import birdie
import drift.{Continue}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

type Input {
  Append(String)
  Yank
  PrintMe
  Stop
  PrintTime
}

type Output {
  Print(String)
}

type Step =
  drift.Step(List(String), Input, Output, Nil)

type Next =
  drift.Next(List(String), Input, Output, Nil)

pub fn example_use_test() {
  let state = drift.start(["Hello, World!"])

  let assert Continue([], state, Some(10)) =
    state
    |> drift.begin_step(0)
    |> drift.handle_after(10, PrintTime)
    |> drift.end_step()

  let assert Continue([], state, Some(10)) =
    step(state, 0, Append("Wibble!"), apply_input)

  let assert Continue([], state, Some(20)) = drift.tick(state, 10, apply_input)

  let assert Continue([], state, Some(20)) =
    step(state, 15, Append("Wobble"), apply_input)

  let assert Continue([], state, Some(20)) =
    step(state, 16, Append("Wobble"), apply_input)

  let assert Continue([], state, Some(20)) = step(state, 17, Yank, apply_input)

  let assert Continue([], state, Some(30)) = drift.tick(state, 20, apply_input)

  let assert Continue([drift.Output(Print(log))], state, Some(30)) =
    step(state, 25, PrintMe, apply_input)

  let assert Continue([], _state, None) = step(state, 25, Stop, apply_input)

  birdie.snap(log, "Demonstrate some basic usage")
}

fn step(
  state: drift.Stepper(List(String), Input),
  now: drift.Timestamp,
  input: Input,
  apply: fn(Step, Input) -> Step,
) -> Next {
  state
  |> drift.begin_step(now)
  |> apply(input)
  |> drift.end_step()
}

fn apply_input(step: Step, input: Input) -> Step {
  case input {
    Append(message) -> {
      let now = drift.start_timestamp(step)
      use lines <- drift.update_state(step)
      [string.inspect(now) <> ": " <> message, ..lines]
    }

    PrintMe -> {
      drift.output_from_state(step, fn(lines) {
        Print(
          lines
          |> list.reverse
          |> string.join("\n"),
        )
      })
    }

    PrintTime -> {
      let now = drift.start_timestamp(step)
      let new_line = "It's now: " <> string.inspect(now)
      step
      |> drift.update_state(list.prepend(_, new_line))
      |> drift.handle_after(10, PrintTime)
    }

    Yank -> drift.update_state(step, list.drop(_, 1))
    Stop -> drift.cancel_all_timers(step)
  }
}
