//// Mutable event loop for driving our stepper.

import gleam/javascript/promise.{type Promise}
import gleam/result

pub type Event(i) {
  Tick
  HandleInput(i)
}

pub type EventLoop(i)

@external(javascript, "../../../drift_js_external.mjs", "init")
pub fn new() -> EventLoop(i)

/// Sends a message, which will a complete a promise returned from `receive`,
/// regardless of whether `receive` is called before or after `send`.
/// Will queue the value if call more times than `receive`.
/// Clears any previously set timeout.
@external(javascript, "../../../drift_js_external.mjs", "send")
pub fn send(loop: EventLoop(i), input: i) -> Nil

/// Sets the time to the next time `receive` should return `Tick`.
/// Only one timeout can be set at a time.
/// Returns an error if a timeout is already set.
@external(javascript, "../../../drift_js_external.mjs", "set_timeout")
pub fn set_timeout(loop: EventLoop(i), after: Int) -> Result(Nil, Nil)

/// Receives the next event, which will be either a `Tick` from `set_timeout`
/// or `HandleInput` from `send`.
/// If any timeout was set before the promise is resolved,
/// it will be canceled when the promise resolves.
/// Only one receive can be active at a time.
pub fn receive(loop: EventLoop(i)) -> Result(Promise(Event(i)), Nil) {
  let #(promise, resolve) = promise.start()
  receive_with_callback(loop, resolve)
  |> result.map(fn(_) { promise })
}

@external(javascript, "../../../drift_js_external.mjs", "receive")
fn receive_with_callback(
  loop: EventLoop(i),
  callback: fn(Event(i)) -> Nil,
) -> Result(Nil, Nil)
