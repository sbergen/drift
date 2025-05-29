import drift.{type Context, type Step}
import drift/effect.{type Effect}
import drift/js/internal/event_loop.{type EventLoop, HandleInput, Tick}
import gleam/int
import gleam/javascript/promise.{type Promise, await}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

pub opaque type Runtime(i) {
  Runtime(loop: EventLoop(i))
}

pub type CallError {
  RuntimeStopped
  CallTimedOut
}

/// Sends an input to be handled by the runtime.
pub fn send(runtime: Runtime(i), input: i) -> Nil {
  event_loop.send(runtime.loop, input)
}

pub fn call_forever(
  runtime: Runtime(i),
  make_request: fn(Effect(a)) -> i,
) -> Promise(Result(a, CallError)) {
  let #(promise, resolve) = promise.start()
  let deferred = effect.from(resolve)

  event_loop.send(runtime.loop, make_request(deferred))
  event_loop.error_if_stopped(runtime.loop, promise, RuntimeStopped)
}

pub fn call(
  runtime: Runtime(i),
  waiting timeout: Int,
  sending make_request: fn(Effect(a)) -> i,
) -> Promise(Result(a, CallError)) {
  let #(promise, resolve) = promise.start()
  let deferred = effect.from(resolve)

  event_loop.send(runtime.loop, make_request(deferred))
  let result =
    event_loop.error_if_stopped(runtime.loop, promise, RuntimeStopped)
  let timeout =
    promise.wait(timeout)
    |> promise.map(fn(_) { Error(CallTimedOut) })

  promise.race_list([result, timeout])
}

pub fn start(
  state: s,
  create_io: fn(Runtime(i)) -> io,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  handle_output: fn(effect.Context(io, Nil), o, fn(i) -> Nil) ->
    Result(effect.Context(io, Nil), e),
) -> #(Promise(Result(s, e)), Runtime(i)) {
  let loop = event_loop.start()
  let runtime = Runtime(loop)
  let #(stepper, io) = drift.new(state, create_io(runtime), Nil)
  let send = event_loop.send(loop, _)
  let handle_output = fn(io, output) { handle_output(io, output, send) }
  let result = do_loop(loop, stepper, io, handle_input, handle_output)
  #(result, runtime)
}

fn do_loop(
  loop: EventLoop(i),
  stepper: drift.Stepper(s, i),
  io: io,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  handle_output: fn(io, o) -> Result(io, e),
) -> Promise(Result(s, e)) {
  // TODO: Decide what to do with errors that shouldn't happen
  let assert Ok(next) = event_loop.receive(loop)
  use message <- await(next)
  let now = now()

  // Either tick or handle input
  let next = case message {
    Tick -> drift.tick(stepper, now, handle_input)
    HandleInput(input) -> drift.step(stepper, now, input, handle_input)
  }

  // Apply effects, no matter if stopped or not
  let io =
    list.fold(next.outputs, Ok(io), fn(io, output) {
      use io <- result.try(io)
      handle_output(io, output)
    })

  case next {
    drift.Continue(_effects, stepper, due_time) -> {
      case due_time {
        Some(due_time) -> {
          // TODO: Error handling
          let assert Ok(Nil) =
            event_loop.set_timeout(loop, int.max(0, due_time - now))
          Nil
        }

        None -> Nil
      }

      case io {
        Ok(io) -> do_loop(loop, stepper, io, handle_input, handle_output)
        Error(error) -> stop(loop, Error(error))
      }
    }
    drift.Stop(_effects, state) -> stop(loop, Ok(state))
    drift.StopWithError(_effects, error) -> stop(loop, Error(error))
  }
}

fn stop(loop: EventLoop(i), result: Result(a, e)) -> Promise(Result(a, e)) {
  event_loop.stop(loop)
  promise.resolve(result)
}

@external(javascript, "../../drift_js_external.mjs", "now")
pub fn now() -> Int
