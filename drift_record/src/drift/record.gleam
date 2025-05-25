import drift.{type Context, type Step, type Timestamp}
import drift/effect.{type Effect}
import drift/record/format.{type Formatter}
import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub opaque type Recorder(s, i, o, e, f) {
  Recorder(
    stepper: drift.Stepper(s, i),
    apply_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
    formatter: Formatter(f, Message(i, o)),
    next_tick: Option(Timestamp),
    time: Timestamp,
    log: String,
    stopped: Bool,
  )
}

/// The union of inputs and outputs, to help with formatting.
pub type Message(i, o) {
  Input(i)
  Output(o)
}

pub fn new(
  state: s,
  apply_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  formatter: Formatter(f, Message(i, o)),
) -> Recorder(s, i, o, e, f) {
  let #(stepper, _effect_ctx) = drift.start(state, Nil)
  Recorder(stepper, apply_input, formatter, None, 0, "", False)
}

pub fn input(
  recorder: Recorder(s, i, o, e, f),
  input: i,
) -> Recorder(s, i, o, e, f) {
  let #(formatter, description) = format.value(recorder.formatter, Input(input))
  step_or_tick(Recorder(..recorder, formatter:), Some(input), description)
}

pub fn time_advance(
  recorder: Recorder(s, i, o, e, f),
  duration: Int,
) -> Recorder(s, i, o, e, f) {
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

pub fn flush(
  recorder: Recorder(s, i, o, e, f),
  what: String,
) -> Recorder(s, i, o, e, f) {
  Recorder(..recorder, log: "<flushed " <> what <> ">\n")
}

pub fn to_log(recorder: Recorder(s, i, o, e, f)) -> String {
  string.trim_end(recorder.log)
}

pub fn discard() -> Effect(a) {
  effect.from(fn(_) { Nil })
}

fn assert_ticks_exhausted(
  recorder: Recorder(s, i, o, e, f),
) -> Recorder(s, i, o, e, f) {
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
  recorder: Recorder(s, i, o, e, f),
  input: Option(i),
  description: String,
) -> Recorder(s, i, o, e, f) {
  use <- bool.lazy_guard(recorder.stopped, fn() {
    let log =
      recorder.log <> " =!!= Already stopped, ignoring: " <> description <> "\n"
    Recorder(..recorder, log:)
  })

  let log = recorder.log <> "  --> " <> description <> "\n"

  let next = case input {
    Some(input) ->
      drift.step(recorder.stepper, recorder.time, input, recorder.apply_input)
    None -> drift.tick(recorder.stepper, recorder.time, recorder.apply_input)
  }

  let #(formatter, outputs) =
    format.list(recorder.formatter, list.map(next.outputs, Output))
  let log = log <> "<--   " <> format_list("", outputs) <> "\n"

  case next {
    drift.Continue(_outputs, stepper, next_tick) ->
      Recorder(..recorder, stepper:, log:, formatter:, next_tick:)

    drift.Stop(_outputs) -> {
      let log = log <> "===== Stopped!\n"
      Recorder(..recorder, log:, formatter:, next_tick: None, stopped: True)
    }

    drift.StopWithError(_outputs, error) -> {
      let log = log <> "  !!  " <> string.inspect(error) <> "\n"
      Recorder(..recorder, log:, formatter:, next_tick: None, stopped: True)
    }
  }
}

// Can't use string.inspect on a list of strings, as it adds quotes
fn format_list(str: String, values: List(String)) -> String {
  case str, values {
    str, [] -> "[" <> str <> "]"
    "", [head, ..rest] -> format_list(head, rest)
    str, [head, ..rest] -> format_list(str <> ", " <> head, rest)
  }
}
