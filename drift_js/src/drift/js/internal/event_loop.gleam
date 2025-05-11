//// Mutable event loop for driving our stepper.

import gleam/javascript/promise.{type Promise}
import gleam/result

pub type Event(i) {
  Tick
  HandleInput(i)
}

pub type EventLoop(i)

@external(javascript, "../../../drift_event_loop.mjs", "init")
pub fn new() -> EventLoop(i)

@external(javascript, "../../../drift_event_loop.mjs", "send")
pub fn send(loop: EventLoop(i), input: i) -> Nil

@external(javascript, "../../../drift_event_loop.mjs", "set_timeout")
pub fn set_timeout(loop: EventLoop(i), after: Int) -> Result(Nil, Nil)

pub fn receive(loop: EventLoop(i)) -> Result(Promise(Event(i)), Nil) {
  let #(promise, resolve) = promise.start()
  receive_with_callback(loop, resolve)
  |> result.map(fn(_) { promise })
}

@external(javascript, "../../../drift_event_loop.mjs", "receive")
fn receive_with_callback(
  loop: EventLoop(i),
  callback: fn(Event(i)) -> Nil,
) -> Result(Nil, Nil)
