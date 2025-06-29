import birdie
import drift
import drift/record
import gleam/int
import gleam/option.{None}

pub fn main() {
  // Will produce this snapshot
  //   --> Adding: 40
  // <--   Sum: 40
  //   --> Adding: 2
  // <--   Sum: 42
  record.new(0, sum_input, format, None)
  |> record.input(40)
  |> record.input(2)
  |> record.to_log
  |> birdie.snap("Example of drift_record")
}

fn format(msg: record.Message(Int, Int, String)) -> String {
  case msg {
    record.Input(i) -> "Adding: " <> int.to_string(i)
    record.Output(i) -> "Sum: " <> int.to_string(i)
    record.Error(e) -> "Error: " <> e
  }
}

// This would normally be defined in the package being tested
fn sum_input(
  ctx: drift.Context(Int, Int),
  state: Int,
  input: Int,
) -> drift.Step(Int, Int, Int, String) {
  let sum = state + input
  ctx
  |> drift.output(sum)
  |> drift.continue(sum)
}
