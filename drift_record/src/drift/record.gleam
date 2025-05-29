import drift.{type Context, type Step, type Timestamp}
import drift/effect.{type Effect}
import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The state for recording the inputs and outputs of a stepper.
pub opaque type Recorder(s, i, o, e) {
  Recorder(
    stepper: drift.Stepper(s, i),
    apply_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
    formatter: fn(Message(i, o)) -> String,
    final_state_formatter: Option(fn(s) -> String),
    next_tick: Option(Timestamp),
    time: Timestamp,
    log: String,
    outputs: List(o),
    stopped: Bool,
  )
}

/// The union of inputs and outputs, to help with formatting.
pub type Message(i, o) {
  Input(i)
  Output(o)
}

/// Creates a new recorder, with the given state, behavior, and formatting.
pub fn new(
  state: s,
  apply_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  formatter: fn(Message(i, o)) -> String,
  final_state_formatter: Option(fn(s) -> String),
) -> Recorder(s, i, o, e) {
  drift.reset_ids()
  let #(stepper, _effect_ctx) = drift.new(state, Nil, Nil)
  Recorder(
    stepper:,
    apply_input:,
    formatter:,
    final_state_formatter:,
    next_tick: None,
    time: 0,
    log: "",
    outputs: [],
    stopped: False,
  )
}

/// Applies the given input to the stepper, and returns a new recorder
/// with the step recorded.
pub fn input(recorder: Recorder(s, i, o, e), input: i) -> Recorder(s, i, o, e) {
  let description = recorder.formatter(Input(input))
  step_or_tick(recorder, Some(input), description)
}

/// Advances the simulated time, and returns a new recorder with the results
/// of the possible timers being processed.
/// Note that if the time encompasses multiple timer due times,
/// all of them will be fired at the given time, not at their due time.
/// This enables testing what happens if the timers fire late.
pub fn time_advance(
  recorder: Recorder(s, i, o, e),
  duration: Int,
) -> Recorder(s, i, o, e) {
  let time = recorder.time + duration
  let recorder = {
    let log = recorder.log <> "  ... " <> string.inspect(time) <> " ms:\n"
    Recorder(..recorder, log:, time:)
  }

  case recorder.next_tick {
    Some(next) if next <= time ->
      recorder |> step_or_tick(None, "Tick") |> assert_ticks_exhausted
    _ -> recorder
  }
}

/// Flushes all previous state, and replaces it with a message containing
/// the provided description.
pub fn flush(
  recorder: Recorder(s, i, o, e),
  what: String,
) -> Recorder(s, i, o, e) {
  Recorder(..recorder, log: "<flushed " <> what <> ">\n")
}

/// Turns the recorded steps into a string, which can be used with 
/// snapshot testing libraries (e.g. birdie).
pub fn to_log(recorder: Recorder(s, i, o, e)) -> String {
  string.trim_end(recorder.log)
}

/// Applies the given function that produces the next state of the recorder
/// from the outputs of the previously executed step.
pub fn use_latest_outputs(
  recorder: Recorder(s, i, o, e),
  with: fn(Recorder(s, i, o, e), List(o)) -> Recorder(s, i, o, e),
) -> Recorder(s, i, o, e) {
  with(recorder, recorder.outputs)
}

/// A utility function that creates an effect which only discards its input.
/// You usually would not want to apply any side effects during snapshot testing.
pub fn discard() -> Effect(a) {
  effect.from(fn(_) { Nil })
}

fn assert_ticks_exhausted(
  recorder: Recorder(s, i, o, e),
) -> Recorder(s, i, o, e) {
  case recorder.next_tick {
    Some(next) if next <= recorder.time -> {
      let log =
        recorder.log
        <> "!!!!! Next tick at "
        <> string.inspect(next)
        <> " !!!!!\n"
      Recorder(..recorder, log:)
    }
    _ -> recorder
  }
}

fn step_or_tick(
  recorder: Recorder(s, i, o, e),
  input: Option(i),
  description: String,
) -> Recorder(s, i, o, e) {
  use <- bool.lazy_guard(recorder.stopped, fn() {
    let log =
      recorder.log
      <> " =!!= Already stopped, ignoring:\n      "
      <> pad_lines(description)
      <> "\n"
    Recorder(..recorder, log:)
  })

  let log = recorder.log <> "  --> " <> pad_lines(description) <> "\n"

  let next = case input {
    Some(input) ->
      drift.step(recorder.stepper, recorder.time, input, recorder.apply_input)
    None -> drift.tick(recorder.stepper, recorder.time, recorder.apply_input)
  }

  let outputs =
    next.outputs
    |> list.map(Output)
    |> list.map(recorder.formatter)
  let log = output_list(log, True, outputs)
  let recorder = Recorder(..recorder, outputs: next.outputs)

  case next {
    drift.Continue(_outputs, stepper, next_tick) ->
      Recorder(..recorder, stepper:, log:, next_tick:)

    drift.Stop(_outputs, state) -> {
      let log =
        log
        <> "===== Stopped!\n"
        <> case recorder.final_state_formatter {
          Some(format) -> format(state) <> "\n"
          None -> ""
        }
      Recorder(..recorder, log:, next_tick: None, stopped: True)
    }

    drift.StopWithError(_outputs, error) -> {
      let log = log <> "  !!  " <> string.inspect(error) <> "\n"
      Recorder(..recorder, log:, next_tick: None, stopped: True)
    }
  }
}

fn output_list(log: String, first: Bool, values: List(String)) -> String {
  case first, values {
    _, [] -> log
    True, [head, ..rest] ->
      { log <> "<--   " <> pad_lines(head) <> "\n" }
      |> output_list(False, rest)
    False, [head, ..rest] ->
      { log <> "      " <> pad_lines(head) <> "\n" }
      |> output_list(False, rest)
  }
}

fn pad_lines(output: String) -> String {
  string.split(output, "\n")
  |> string.join("\n      ")
}
