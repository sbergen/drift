import birdie
import calculator
import drift
import drift/record.{discard}
import echoer
import exemplify
import gleam/option.{Some}
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn check_or_update_readme_test() {
  exemplify.update_or_check()
}

pub fn small_time_advance_test() {
  record.new(
    0,
    calculator.handle_input,
    format_calculator,
    Some(string.inspect),
  )
  |> record.input(calculator.Add(8))
  |> record.input(calculator.Divide(2))
  |> record.input(calculator.Solve)
  |> record.time_advance(6)
  |> record.time_advance(6)
  |> record.to_log
  |> birdie.snap("Advancing small increments ticks when going past deadline")
}

pub fn late_tick_test() {
  record.new(
    0,
    calculator.handle_input,
    format_calculator,
    Some(string.inspect),
  )
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(20)
  |> record.to_log
  |> birdie.snap("Testing late ticks should be possible")
}

pub fn exact_tick_test() {
  record.new(
    0,
    calculator.handle_input,
    format_calculator,
    Some(string.inspect),
  )
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(10)
  |> record.to_log
  |> birdie.snap("Advancing exactly to deadline ticks")
}

pub fn stop_with_error_test() {
  record.new(
    0,
    calculator.handle_input,
    format_calculator,
    Some(string.inspect),
  )
  |> record.input(calculator.Add(5))
  |> record.input(calculator.Divide(0))
  |> record.input(calculator.Divide(1))
  |> record.to_log
  |> birdie.snap("Stopping with error shows error")
}

pub fn input_after_stop_test() {
  record.new(
    0,
    calculator.handle_input,
    format_calculator,
    Some(string.inspect),
  )
  |> record.input(calculator.Solve)
  |> record.time_advance(10)
  |> record.input(calculator.Solve)
  |> record.to_log
  |> birdie.snap("Inputs are ignored after stopping")
}

pub fn effects_and_actions_test() {
  record.new(Nil, echoer.handle_input, format_echoer, Some(string.inspect))
  |> record.input(echoer.Echo(discard(), "Hello!", 1))
  |> record.input(echoer.Echo(discard(), "Hello again!!!", 3))
  |> record.to_log
  |> birdie.snap("Effect and action formatting")
}

pub fn effects_id_reset_test() {
  record.new(Nil, echoer.handle_input, format_echoer, Some(string.inspect))
  |> record.input(echoer.Echo(discard(), "Hello!", 1))
  |> record.to_log
  |> birdie.snap("Effect ids should be reset to 1")
}

fn format_calculator(
  msg: record.Message(calculator.Input, calculator.Output, String),
) -> String {
  case msg {
    record.Input(i) -> string.inspect(i)
    record.Output(o) -> string.inspect(o)
    record.Error(e) -> e
  }
}

fn format_echoer(
  msg: record.Message(echoer.Input, echoer.Output, String),
) -> String {
  case msg {
    record.Input(input) ->
      case input {
        echoer.Echo(effect, value, times) -> {
          "Echo "
          <> string.inspect(value)
          <> " "
          <> string.inspect(times)
          <> " times\n  - Using effect #"
          <> string.inspect(drift.effect_id(effect))
        }
      }

    record.Output(output) ->
      case output {
        echoer.Reply(action) ->
          "Reply: "
          <> string.inspect(action.argument)
          <> "\n  - Using effect #"
          <> string.inspect(drift.effect_id(action.effect))
      }

    record.Error(e) -> e
  }
}
