//// Simple example of a drift stepper for the tests

import drift

pub type Input {
  Add(Int)
  Multiply(Int)
  Divide(Int)
  Solve
  PublishResult
}

pub type Output {
  Calculating
  Result(Int)
}

pub fn handle_input(
  context: drift.Context(Input, Output),
  value: Int,
  input: Input,
) -> drift.Step(Int, Input, Output, String) {
  case input {
    Add(addend) -> drift.continue(context, value + addend)

    Divide(divisor) ->
      case divisor {
        0 -> drift.stop_with_error(context, "Div by zero!")
        divisor -> drift.continue(context, value / divisor)
      }

    Multiply(multiplier) -> drift.continue(context, value * multiplier)

    // Fake delay for "calculating"
    Solve -> {
      // This can't be canceled
      let #(context, _timer) = drift.handle_after(context, 10, PublishResult)
      context
      |> drift.output(Calculating)
      |> drift.continue(value)
    }

    PublishResult ->
      context
      |> drift.output(Result(value))
      |> drift.stop()
  }
}
