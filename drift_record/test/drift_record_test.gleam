import birdie
import calculator
import drift/effect
import drift/record.{discard}
import drift/record/format
import echoer
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn small_time_advance_test() {
  record.new(0, calculator.handle_input, format_calculator())
  |> record.input(calculator.Add(8))
  |> record.input(calculator.Divide(2))
  |> record.input(calculator.Solve)
  |> record.time_advance(6)
  |> record.time_advance(6)
  |> record.to_log
  |> birdie.snap("Advancing small increments ticks when going past deadline")
}

pub fn late_tick_test() {
  record.new(0, calculator.handle_input, format_calculator())
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(20)
  |> record.to_log
  |> birdie.snap("Testing late ticks should be possible")
}

pub fn exact_tick_test() {
  record.new(0, calculator.handle_input, format_calculator())
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(10)
  |> record.to_log
  |> birdie.snap("Advancing exactly to deadline ticks")
}

pub fn stop_with_error_test() {
  record.new(0, calculator.handle_input, format_calculator())
  |> record.input(calculator.Add(5))
  |> record.input(calculator.Divide(0))
  |> record.input(calculator.Divide(1))
  |> record.to_log
  |> birdie.snap("Stopping with error shows error")
}

pub fn input_after_stop_test() {
  record.new(0, calculator.handle_input, format_calculator())
  |> record.input(calculator.Solve)
  |> record.time_advance(10)
  |> record.input(calculator.Solve)
  |> record.to_log
  |> birdie.snap("Inputs are ignored after stopping")
}

pub fn effects_and_actions_test() {
  record.new(Nil, echoer.handle_input, format_echoer())
  |> record.input(echoer.Echo(discard(), "Hello!"))
  |> record.input(echoer.Echo(discard(), "Hello again!"))
  |> record.to_log
  |> birdie.snap("Effect and action formatting")
}

fn format_calculator() -> format.Formatter(
  Nil,
  record.Message(calculator.Input, calculator.Output),
) {
  use msg <- format.stateless()
  case msg {
    record.Input(i) -> string.inspect(i)
    record.Output(o) -> string.inspect(o)
  }
}

fn format_echoer() -> format.Formatter(
  effect.Formatter,
  record.Message(echoer.Input, echoer.Output),
) {
  use formatter, msg <- format.stateful(effect.new_formatter())

  case msg {
    record.Input(input) ->
      case input {
        echoer.Echo(effect, value) -> {
          use effect <- format.map(formatter, effect.inspect, effect)
          "Echo(" <> effect <> ", " <> string.inspect(value) <> ")"
        }
      }

    record.Output(output) ->
      case output {
        echoer.Reply(action) -> {
          let assert Ok(action) =
            effect.inspect_action(formatter, action, string.inspect)
          #(formatter, "Reply(" <> action <> ")")
        }
      }
  }
}
