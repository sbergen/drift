import drift.{type Timestamp}
import drift/actor
import gleam/erlang/process.{type Selector, type Subject}
import gleam/io
import gleam/list
import gleam/string
import input

// This part is specific to Erlang and actors

pub fn main() -> Nil {
  let assert Ok(actor) =
    actor.using_io(
      fn() {
        let inputs = process.new_subject()
        let input_pid = process.spawn(fn() { poll_input(inputs) })

        let inputs =
          process.new_selector()
          |> process.select_map(inputs, UserEntered)

        IoDriver(inputs, io.println, input_pid)
      },
      fn(driver) { driver.inputs },
      fn(driver, output) {
        let Print(text) = output
        driver.output(text)
      },
    )
    |> actor.start(1000, [], handle_input, handle_timer)

  process.sleep(5000)
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

fn poll_input(output: Subject(String)) -> Nil {
  let assert Ok(text) = input.input("> ")
  process.send(output, text)
  poll_input(output)
}

type IoDriver {
  IoDriver(
    inputs: Selector(Input),
    output: fn(String) -> Nil,
    input_pid: process.Pid,
  )
}

// Everything below is agnostic of I/O and timer implementations.
// It will echo everything with a one second delay (yes, it's ugly)
// and print all lines when Stop is triggered.

type Input {
  UserEntered(String)
  Stop
}

type Output {
  Print(String)
}

type Event {
  TimedPrint(String)
}

type Step =
  drift.Step(List(String), Event, Output)

fn handle_input(
  step: Step,
  now: Timestamp,
  input: Input,
) -> drift.Next(Step, Nil) {
  case input {
    UserEntered(text) ->
      step
      |> drift.map_state(list.prepend(_, text))
      |> drift.start_timer(drift.Timer(now + 1000, TimedPrint(text)))
      |> drift.Continue
    Stop ->
      step
      |> drift.map_output(fn(lines) {
        Print(lines |> list.reverse |> string.join("\n"))
      })
      |> drift.Stop
  }
}

fn handle_timer(step: Step, _now: Timestamp, event: Event) -> Step {
  case event {
    TimedPrint(text) -> drift.output(step, Print(text))
  }
}
