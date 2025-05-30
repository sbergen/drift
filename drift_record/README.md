# drift_record

[![Package Version](https://img.shields.io/hexpm/v/drift_recorder)](https://hex.pm/packages/drift_recorder)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/drift_recorder/)

Record logs for `drift` cores, and use them in snapshot tests!

```sh
gleam add birdie@1
gleam add drift@1
gleam add drift_record@1
```
```gleam
import birdie
import drift
import drift/record
import gleam/option.{None}
import gleam/string

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

fn format(msg: record.Message(Int, Int)) -> String {
  case msg {
    record.Input(i) -> "Adding: " <> string.inspect(i)
    record.Output(i) -> "Sum: " <> string.inspect(i)
  }
}

// This would normally be defined in the package being tested
fn sum_input(
  ctx: drift.Context(Int, Int),
  state: Int,
  input: Int,
) -> drift.Step(Int, Int, Int, a) {
  let sum = state + input
  ctx
  |> drift.output(sum)
  |> drift.continue(sum)
}

```
