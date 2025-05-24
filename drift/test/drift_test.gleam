import birdie
import drift.{Continue}
import gleam/list
import gleam/option.{Some}
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

type Context =
  drift.Context(Input, Output)

pub fn example_use_test() {
  let #(state, _) = drift.start(["Hello, World!"], Nil)

  let assert Continue([], state, Some(10)) =
    state
    |> drift.begin_step(0)
    |> drift.chain(fn(context, state) {
      let #(context, _) = drift.handle_after(context, 10, PrintTime)
      context |> drift.continue(state)
    })
    |> drift.end_step()

  let assert Continue([], state, Some(10)) =
    drift.step(state, 0, Append("Wibble!"), apply_input)

  let assert Continue([], state, Some(20)) = drift.tick(state, 10, apply_input)

  let assert Continue([], state, Some(20)) =
    drift.step(state, 15, Append("Wobble"), apply_input)

  let assert Continue([], state, Some(20)) =
    drift.step(state, 16, Append("Wobble"), apply_input)

  let assert Continue([], state, Some(20)) =
    drift.step(state, 17, Yank, apply_input)

  let assert Continue([], state, Some(30)) = drift.tick(state, 20, apply_input)

  let assert Continue([Print(log)], state, Some(30)) =
    drift.step(state, 25, PrintMe, apply_input)

  let assert drift.Stop([]) = drift.step(state, 25, Stop, apply_input)

  birdie.snap(log, "Demonstrate some basic usage")
}

fn apply_input(context: Context, lines: List(String), input: Input) -> Step {
  case input {
    Append(message) -> {
      let now = drift.now(context)
      context
      |> drift.continue([string.inspect(now) <> ": " <> message, ..lines])
    }

    PrintMe -> {
      context
      |> drift.output(Print(
        lines
        |> list.reverse
        |> string.join("\n"),
      ))
      |> drift.continue(lines)
    }

    PrintTime -> {
      let now = drift.now(context)
      let new_line = "It's now: " <> string.inspect(now)
      let #(context, _) = drift.handle_after(context, 10, PrintTime)
      context |> drift.continue(list.prepend(lines, new_line))
    }

    Yank -> context |> drift.continue(list.drop(lines, 1))
    Stop -> context |> drift.stop()
  }
}
