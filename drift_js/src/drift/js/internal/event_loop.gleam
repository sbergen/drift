//// Mutable event loop for driving our stepper.

import gleam/javascript/promise.{type Promise}
import gleam/result

pub type Event(i) {
  Tick
  HandleInput(i)
}

pub type EventLoopError {
  Stopped
  AlreadyReceiving
  AlreadyTicking
}

pub type EventLoop(i)

@external(javascript, "../../../drift_event_loop.mjs", "start")
pub fn start() -> EventLoop(i)

@external(javascript, "../../../drift_event_loop.mjs", "stop")
pub fn stop(loop: EventLoop(i)) -> Nil

pub fn error_if_stopped(
  loop: EventLoop(i),
  operation: Promise(a),
  error: e,
) -> Promise(Result(a, e)) {
  let #(time_out_promise, time_out) = promise.start()
  let callback = fn() { time_out(Error(error)) }
  register_stop_callback(loop, callback)

  promise.race_list([operation |> promise.map(Ok), time_out_promise])
  |> promise.tap(fn(_) { unregister_stop_callback(loop, callback) })
}

/// Sends a message, which will a complete a promise returned from `receive`,
/// regardless of whether `receive` is called before or after `send`.
/// Will queue the value if called more times than `receive`.
/// Clears any previously set timeout.
/// Will not return an error if the event loop has been stopped,
/// use `error_if_stopped` instead.
@external(javascript, "../../../drift_event_loop.mjs", "send")
pub fn send(loop: EventLoop(i), input: i) -> Nil

/// Sets the time to the next time `receive` should return `Tick`.
/// Only one timeout can be set at a time.
/// Returns an error if a timeout is already set.
@external(javascript, "../../../drift_event_loop.mjs", "set_timeout")
pub fn set_timeout(
  loop: EventLoop(i),
  after: Int,
) -> Result(Nil, EventLoopError)

/// Receives the next event, which will be either a `Tick` from `set_timeout`
/// or `HandleInput` from `send`.
/// If any timeout was set before the promise is resolved,
/// it will be canceled when the promise resolves.
/// Only one receive can be active at a time.
pub fn receive(loop: EventLoop(i)) -> Result(Promise(Event(i)), EventLoopError) {
  let #(promise, resolve) = promise.start()
  receive_with_callback(loop, resolve)
  |> result.map(fn(_) { promise })
}

@external(javascript, "../../../drift_event_loop.mjs", "receive")
fn receive_with_callback(
  loop: EventLoop(i),
  callback: fn(Event(i)) -> Nil,
) -> Result(Nil, EventLoopError)

@external(javascript, "../../../drift_event_loop.mjs", "register_stop_callback")
fn register_stop_callback(loop: EventLoop(i), callback: fn() -> Nil) -> Nil

@external(javascript, "../../../drift_event_loop.mjs", "unregister_stop_callback")
fn unregister_stop_callback(loop: EventLoop(i), callback: fn() -> Nil) -> Nil
