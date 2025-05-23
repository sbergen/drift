import drift.{type Context, type Effect, type EffectContext, type Step}
import drift/js/internal/event_loop.{type EventLoop, HandleInput, Tick}
import gleam/int
import gleam/javascript/promise.{type Promise, await}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

pub opaque type Runtime(i) {
  Runtime(loop: EventLoop(i))
}

/// Sends an input to be handled by the runtime.
pub fn send(runtime: Runtime(i), input: i) -> Nil {
  event_loop.send(runtime.loop, input)
}

pub fn call_forever(
  runtime: Runtime(i),
  make_request: fn(Effect(a)) -> i,
) -> Promise(Result(a, Nil)) {
  let #(promise, resolve) = promise.start()
  let deferred = drift.defer(resolve)

  event_loop.send(runtime.loop, make_request(deferred))
  event_loop.error_if_stopped(runtime.loop, promise, Nil)
}

pub fn start(
  state: s,
  io: io,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  handle_output: fn(EffectContext(io), o, fn(i) -> Nil) ->
    Result(EffectContext(io), e),
) -> #(Promise(Result(Nil, e)), Runtime(i)) {
  let loop = event_loop.start()
  let #(stepper, io) = drift.start(state, io)
  let send = event_loop.send(loop, _)
  let handle_output = fn(io, output) { handle_output(io, output, send) }
  let result = do_loop(loop, stepper, io, handle_input, handle_output)
  #(result, Runtime(loop))
}

fn do_loop(
  loop: EventLoop(i),
  stepper: drift.Stepper(s, i),
  io: io,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  handle_output: fn(io, o) -> Result(io, e),
) -> Promise(Result(Nil, e)) {
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
    drift.Stop(_effects) -> stop(loop, Ok(Nil))
    drift.StopWithError(_effects, error) -> stop(loop, Error(error))
  }
}

fn stop(loop: EventLoop(i), result: Result(a, e)) -> Promise(Result(a, e)) {
  event_loop.stop(loop)
  promise.resolve(result)
}

@external(javascript, "../../drift_js_external.mjs", "now")
pub fn now() -> Int
