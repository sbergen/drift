import birdie
import calculator
import drift/record
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn small_time_advance_test() {
  record.new(0, calculator.handle_input, string.inspect)
  |> record.input(calculator.Add(8))
  |> record.input(calculator.Divide(2))
  |> record.input(calculator.Solve)
  |> record.time_advance(6)
  |> record.time_advance(6)
  |> record.to_log
  |> birdie.snap("Advancing small increments ticks when going past deadline")
}

pub fn late_tick_test() {
  record.new(0, calculator.handle_input, string.inspect)
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(20)
  |> record.to_log
  |> birdie.snap("Testing late ticks should be possible")
}

pub fn exact_tick_test() {
  record.new(0, calculator.handle_input, string.inspect)
  |> record.input(calculator.Add(42))
  |> record.input(calculator.Divide(4))
  |> record.input(calculator.Solve)
  |> record.time_advance(10)
  |> record.to_log
  |> birdie.snap("Advancing exactly to deadline ticks")
}

pub fn stop_with_error_test() {
  record.new(0, calculator.handle_input, string.inspect)
  |> record.input(calculator.Add(5))
  |> record.input(calculator.Divide(0))
  |> record.to_log
  |> birdie.snap("Stopping with error shows error")
}
