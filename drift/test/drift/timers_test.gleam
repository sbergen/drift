import drift.{Continue}
import gleam/option.{None, Some}
import gleeunit/should

type Input {
  Input(Int)
}

pub fn timers_fire_in_order_test() {
  let #(stepper, _) = drift.new(Nil, Nil, Nil)
  let assert Continue([], stepper, Some(1100)) =
    drift.step(stepper, 1000, Input(0), fn(ctx, state, _) {
      let #(ctx, _) = drift.start_timer(ctx, 200, Input(0))
      let #(ctx, _) = drift.start_timer(ctx, 300, Input(1))
      let #(ctx, _) = drift.start_timer(ctx, 100, Input(2))
      drift.continue(ctx, state)
    })

  let assert Continue([], stepper, Some(1200)) =
    drift.tick(stepper, 1100, fn(ctx, state, input) {
      input |> should.equal(Input(2))
      drift.continue(ctx, state)
    })

  let assert Continue([], stepper, Some(1300)) =
    drift.tick(stepper, 1200, fn(ctx, state, input) {
      input |> should.equal(Input(0))
      drift.continue(ctx, state)
    })

  let assert Continue([], _, None) =
    drift.tick(stepper, 1300, fn(ctx, state, input) {
      input |> should.equal(Input(1))
      drift.continue(ctx, state)
    })

  Nil
}

pub fn cancel_timer_test() {
  let #(stepper, _) = drift.new(Nil, Nil, Nil)

  let assert Continue([], stepper, Some(1200)) =
    drift.step(stepper, 1000, Input(0), fn(ctx, state, _) {
      let #(ctx, timer0) = drift.start_timer(ctx, 100, Input(0))
      let #(ctx, _) = drift.start_timer(ctx, 200, Input(1))
      let #(ctx, timer2) = drift.start_timer(ctx, 300, Input(2))

      let assert #(ctx, drift.Cancelled(100)) = drift.cancel_timer(ctx, timer0)
      let assert #(ctx, drift.TimerNotFound) = drift.cancel_timer(ctx, timer0)

      let assert #(ctx, drift.Cancelled(300)) = drift.cancel_timer(ctx, timer2)

      drift.continue(ctx, state)
    })

  let assert Continue([], _, None) =
    drift.tick(stepper, 1200, fn(ctx, state, _) { drift.continue(ctx, state) })

  Nil
}

pub fn cancel_all_timers_test() {
  let #(stepper, _) = drift.new(Nil, Nil, Nil)

  let assert Continue([], _, None) =
    drift.step(stepper, 1000, Input(0), fn(ctx, state, _) {
      let #(ctx, _) = drift.start_timer(ctx, 100, Input(0))
      let #(ctx, _) = drift.start_timer(ctx, 200, Input(1))
      let #(ctx, _) = drift.start_timer(ctx, 300, Input(2))

      ctx
      |> drift.cancel_all_timers()
      |> drift.continue(state)
    })

  Nil
}

pub fn now_has_step_start_test() {
  let #(stepper, _) = drift.new(Nil, Nil, Nil)
  drift.step(stepper, 42, Input(0), fn(ctx, state, _) {
    drift.now(ctx) |> should.equal(42)
    drift.continue(ctx, state)
  })

  drift.step(stepper, 43, Input(0), fn(ctx, state, _) {
    drift.now(ctx) |> should.equal(43)
    drift.continue(ctx, state)
  })

  Nil
}
