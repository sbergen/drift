import birdie
import drift
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

type Event {
  PrintTime
}

type Input {
  Append(String)
  Yank
  PrintMe
  Stop
}

type Output {
  Print(String)
}

type Step =
  drift.Step(List(String), Event, Output)

pub fn example_use_test() {
  let assert #(state, Some(10)) =
    drift.start(["Hello, World!"], [drift.Timer(10, PrintTime)])

  let assert #(state, Some(10), []) =
    drift.step(state, 0, Append("Wibble!"), apply_input)

  let assert #(state, Some(20), []) = drift.tick(state, 10, apply_event)

  let assert #(state, Some(20), []) =
    drift.step(state, 15, Append("Wobble"), apply_input)

  let assert #(state, Some(20), []) =
    drift.step(state, 16, Append("Wobble"), apply_input)

  let assert #(state, Some(20), []) = drift.step(state, 17, Yank, apply_input)

  let assert #(state, Some(30), []) = drift.tick(state, 20, apply_event)

  let assert #(state, Some(30), [Print(log)]) =
    drift.step(state, 25, PrintMe, apply_input)

  let assert #(_state, None, []) = drift.step(state, 25, Stop, apply_input)

  birdie.snap(log, "Demonstrate some basic usage")
}

fn apply_input(step: Step, now: drift.Timestamp, input: Input) -> Step {
  case input {
    Append(message) -> {
      use lines <- drift.map_state(step)
      [string.inspect(now) <> ": " <> message, ..lines]
    }

    PrintMe -> {
      let lines = drift.read_state(step)
      drift.output(
        step,
        Print(
          lines
          |> list.reverse
          |> string.join("\n"),
        ),
      )
    }

    Yank -> drift.map_state(step, list.drop(_, 1))
    Stop -> drift.cancel_all_timers(step)
  }
}

fn apply_event(step: Step, now: drift.Timestamp, event: Event) {
  case event {
    PrintTime -> {
      let new_line = "It's now: " <> string.inspect(now)
      step
      |> drift.map_state(list.prepend(_, new_line))
      |> drift.start_timer(drift.Timer(now + 10, PrintTime))
    }
  }
}
