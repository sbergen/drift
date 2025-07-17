import drift.{type Action, type Effect, Continue}
import gleam/option.{None, Some}

type Input {
  Input(Int)
}

type Output {
  Plain(Int)
  ActionOutput(Action(Int))
}

pub fn outputs_are_in_order_test() {
  let #(stepper, _) = drift.new(Nil, Nil)
  let assert Continue(
    [Plain(1), ActionOutput(_), Plain(2), Plain(3), Plain(4), Plain(5)],
    _,
    None,
  ) =
    drift.step(stepper, 1000, Input(0), fn(ctx, state, _) {
      ctx
      |> drift.output(Plain(1))
      |> drift.perform(ActionOutput, discard(), 42)
      |> drift.output_many([Plain(2), Plain(3)])
      |> drift.output_option(None)
      |> drift.output_option(Some(Plain(4)))
      |> drift.output(Plain(5))
      |> drift.continue(state)
    })

  Nil
}

fn discard() -> Effect(a) {
  drift.new_effect(fn(_) { Nil })
}
