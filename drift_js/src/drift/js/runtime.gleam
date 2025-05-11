import drift.{type Context, type Deferred, type Step}
import drift/js/internal/event_loop.{type EventLoop, HandleInput, Tick}
import gleam/int
import gleam/javascript/promise.{type Promise, await}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

pub opaque type Runtime(i) {
  Runtime(send: fn(i) -> Nil)
}

pub fn send(runtime: Runtime(i), input: i) -> Nil {
  runtime.send(input)
}

pub fn call_forever(
  runtime: Runtime(i),
  make_request: fn(Deferred(a)) -> i,
) -> Promise(a) {
  // TODO: Check that the runtime hasn't stopped!
  let #(promise, resolve) = promise.start()
  let deferred = drift.defer(resolve)
  runtime.send(make_request(deferred))
  promise
}

pub fn run(
  state: s,
  io: io,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  handle_output: fn(io, o, fn(i) -> Nil) -> Result(io, e),
) -> #(Promise(Result(Nil, e)), Runtime(i)) {
  let loop = event_loop.new()
  let stepper = drift.start(state)
  let send = event_loop.send(loop, _)
  let handle_output = fn(io, output) { handle_output(io, output, send) }
  let result = do_loop(loop, stepper, io, handle_input, handle_output)
  #(result, Runtime(send))
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
    list.fold(next.effects, Ok(io), fn(io, effect) {
      use io <- result.try(io)
      case effect {
        drift.Output(output) -> handle_output(io, output)
        drift.ResolveDeferred(resolve) -> {
          resolve()
          Ok(io)
        }
      }
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
        Error(error) -> promise.resolve(Error(error))
      }
    }
    drift.Stop(_effects) -> promise.resolve(Ok(Nil))
    drift.StopWithError(_effects, error) -> promise.resolve(Error(error))
  }
}

@external(javascript, "../../drift_js_external.mjs", "now")
pub fn now() -> Int
