import drift.{type Action, type Context, type Effect, type Step}
import drift/js/runtime.{
  type Runtime, type TerminalResult, CallTimedOut, RuntimeStopped, Terminated,
}
import exemplify
import gleam/javascript/promise.{type Promise, await}
import gleam/list
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn check_or_update_readme_test() {
  exemplify.update_or_check()
}

pub fn run_result_not_terminated_test() -> Promise(Nil) {
  let #(result, _rt) = start_without_io(Nil, noop)
  expect_incomplete(result, "run loop should not be terminated")
}

pub fn run_result_resolves_when_stopped_test() -> Promise(Nil) {
  use <- timeout(100)
  let #(result, rt) = start_without_io(Nil, stop)

  // Trigger the stop
  runtime.send(rt, True)
  use result <- await(result)
  let assert runtime.Terminated(Nil) = result
  promise.resolve(Nil)
}

pub fn call_forever_completion_test() {
  use <- timeout(100)
  let #(_result, rt) = start_with_action_executor(Nil, apply)

  use result <- await(runtime.call_forever(rt, fn(effect) { #(effect, 42) }))
  let assert Ok(42) = result
  promise.resolve(Nil)
}

pub fn call_forever_after_stopped_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  // Trigger the stop
  runtime.send(rt, True)

  use result <- promise.await(runtime.call_forever(rt, fn(_) { False }))
  let assert Error(RuntimeStopped) = result
  promise.resolve(Nil)
}

pub fn call_forever_then_stop_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  let result = runtime.call_forever(rt, fn(_) { False })

  // Trigger the stop
  runtime.send(rt, True)

  use result <- promise.await(result)
  let assert Error(RuntimeStopped) = result
  promise.resolve(Nil)
}

pub fn call_completion_test() {
  use <- timeout(100)
  let #(_result, rt) = start_with_action_executor(Nil, apply)

  use result <- await(runtime.call(rt, 1000, fn(effect) { #(effect, 42) }))
  let assert Ok(42) = result
  promise.resolve(Nil)
}

pub fn call_after_stopped_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  // Trigger the stop
  runtime.send(rt, True)

  use result <- promise.await(runtime.call(rt, 1000, fn(_) { False }))
  let assert Error(RuntimeStopped) = result
  promise.resolve(Nil)
}

pub fn call_then_stop_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  let result = runtime.call(rt, 1000, fn(_) { False })

  // Trigger the stop
  runtime.send(rt, True)

  use result <- promise.await(result)
  let assert Error(RuntimeStopped) = result
  promise.resolve(Nil)
}

pub fn call_timeout_test() {
  use <- timeout(100)
  let #(_result, rt) = start_without_io(Nil, stop)

  let result = runtime.call(rt, 1, fn(_) { False })

  use result <- promise.await(result)
  let assert Error(CallTimedOut) = result

  promise.resolve(Nil)
}

pub fn send_after_0_is_delayed_test() {
  use <- timeout(100)

  let #(result, rt) =
    start_without_io([], fn(ctx, state, input) {
      let state = [input, ..state]
      case list.length(state) {
        4 -> drift.stop(ctx, state)
        _ -> drift.continue(ctx, state)
      }
    })

  runtime.send_after(rt, 0, "after1")
  runtime.send(rt, "immediate1")
  runtime.send_after(rt, 0, "after2")
  runtime.send(rt, "immediate2")
  use result <- promise.await(result)

  // Reverse list for clearer assertion
  let assert Terminated(result) = result
  let result = list.reverse(result)
  assert result == ["immediate1", "immediate2", "after1", "after2"]

  promise.resolve(Nil)
}

fn noop(ctx: Context(i, o), state: s, _: i) -> Step(s, i, o, e) {
  ctx |> drift.continue(state)
}

fn apply(
  ctx: Context(#(Effect(a), a), Action(a)),
  state: s,
  input: #(Effect(a), a),
) -> Step(s, #(Effect(a), a), Action(a), e) {
  ctx
  |> drift.output(drift.bind_effect(input.0, input.1))
  |> drift.continue(state)
}

fn stop(ctx: Context(Bool, o), state: s, stop: Bool) -> Step(s, Bool, o, e) {
  case stop {
    True -> drift.stop(ctx, state)
    False -> drift.continue(ctx, state)
  }
}

fn start_with_action_executor(
  state: s,
  next: fn(Context(i, Action(a)), s, i) -> Step(s, i, Action(a), e),
) -> #(Promise(TerminalResult(s, e)), Runtime(i)) {
  runtime.start(state, fn(_) { Nil }, next, fn(ctx, action, _) {
    drift.perform_effect(ctx, action)
    Ok(ctx)
  })
}

pub fn start_without_io(
  state: s,
  next: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> #(Promise(TerminalResult(s, e)), Runtime(i)) {
  runtime.start(state, fn(_) { Nil }, next, fn(ctx, _, _) { Ok(ctx) })
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
