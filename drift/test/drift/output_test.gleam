import drift.{Continue}
import drift/effect.{type Action, type Effect}
import gleam/option.{None}

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
    [Plain(1), ActionOutput(_), Plain(2), Plain(3), Plain(4)],
    _,
    None,
  ) =
    drift.step(stepper, 1000, Input(0), fn(ctx, state, _) {
      ctx
      |> drift.output(Plain(1))
      |> drift.perform(ActionOutput, discard(), 42)
      |> drift.output_many([Plain(2), Plain(3)])
      |> drift.output(Plain(4))
      |> drift.continue(state)
    })

  Nil
}

fn discard() -> Effect(a) {
  effect.from(fn(_) { Nil })
}
