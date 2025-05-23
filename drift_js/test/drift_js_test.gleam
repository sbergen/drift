import drift.{type Context, type Step}
import drift/js/runtime.{type Runtime}
import gleam/javascript/promise.{type Promise, await}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn run_result_not_terminated_test() -> Promise(Nil) {
  let #(result, _rt) = start_without_io(Nil, noop)
  expect_incomplete(result, "run loop should not be terminated")
}

pub fn run_result_resolves_when_stopped_test() -> Promise(Nil) {
  use <- timeout(100)
  let #(result, rt) = start_without_io(Nil, stop)

  // Trigger the stop
  runtime.send(rt, Nil)
  use result <- await(result)
  let assert Ok(Nil) = result
  promise.resolve(Nil)
}

pub fn call_forever_after_stopped_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  // Trigger the stop
  runtime.send(rt, Nil)

  use result <- await(runtime.call_forever(rt, fn(_) { Nil }))
  let assert Error(Nil) = result

  promise.resolve(Nil)
}

fn noop(ctx: Context(i, o), state: s, _: i) -> Step(s, i, o, e) {
  ctx |> drift.with_state(state)
}

fn stop(ctx: Context(i, o), _tate: s, _: i) -> Step(s, i, o, e) {
  ctx |> drift.stop()
}

pub fn start_without_io(
  state: s,
  next: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> #(Promise(Result(Nil, e)), Runtime(i)) {
  runtime.start(state, Nil, next, fn(ctx, _, _) { Ok(ctx) })
}

fn timeout(after: Int, body: fn() -> Promise(a)) -> Promise(a) {
  promise.race_list([
    promise.wait(after) |> promise.map(fn(_) { panic as "Timed out!" }),
    body(),
  ])
}

fn expect_incomplete(p: Promise(a), why: String) -> Promise(Nil) {
  let timeout =
    promise.wait(0)
    |> promise.map(Ok)
  use result <- await(promise.race_list([promise.map(p, Error), timeout]))
  let assert Ok(Nil) = result as why
  promise.resolve(Nil)
}
