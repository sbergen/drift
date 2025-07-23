//// A channel, similar to a `gleam/erlang` `Subject`.
//// Provided for convenience, not required to use `drift_js`.

import gleam/javascript/promise.{type Promise}

/// An unbounded single-consumer channel with non-blocking sending
/// and asynchronous receiving.
/// Intended to be used similarly to a `gleam/erlang` `Subject`.
pub type Channel(a)

pub type ReceiveError {
  /// A promise previously returned from `receive` has not yet resolved.
  AlreadyReceiving
  /// The receive timed out
  ReceiveTimeout
}

/// Creates a new channel.
@external(javascript, "../../drift_channel.mjs", "new_channel")
pub fn new() -> Channel(a)

/// Returns a promise that will resolve with a value when the channel has one available,
/// or an error, if a receive is already active.
/// The promise may resolve synchronously if a value is already available,
/// and will resolve synchronously for errors.
/// Returning the error in the promise provides a more ergonomic interface,
/// even though it's always synchronous.
pub fn receive_forever(from channel: Channel(a)) -> Promise(Result(a, Nil)) {
  let #(promise, resolve) = promise.start()
  case channel_receive(channel, resolve) {
    Ok(_) -> promise.map(promise, Ok)
    Error(_) -> promise.resolve(Error(Nil))
  }
}

/// Returns a promise that will resolve with a value when the channel has one available.
/// The promise will resolve with an error if the timeout (in milliseconds) is
/// reached before a value is available, or if a receive is already active.
/// The promise may resolve synchronously if a value is already available,
/// and will resolve synchronously if a receive is already active.
pub fn receive(
  from channel: Channel(a),
  within timeout: Int,
) -> Promise(Result(a, ReceiveError)) {
  let #(promise, resolve) = promise.start()
  let receive = case channel_receive(channel, resolve) {
    Ok(_) -> promise.map(promise, Ok)
    Error(_) -> promise.resolve(Error(AlreadyReceiving))
  }

  let timeout =
    promise.wait(timeout)
    |> promise.map(fn(_) {
      cancel_receive(channel, resolve)
      Error(ReceiveTimeout)
    })

  promise.race_list([receive, timeout])
}

/// Tries to receive a value synchronously,
/// and returns an error if no value is available.
@external(javascript, "../../drift_channel.mjs", "try_receive")
pub fn try_receive(channel: Channel(a)) -> Result(a, Nil)

/// Sends a value to the channel, either completing a promise,
/// or queuing the value for future receives.
@external(javascript, "../../drift_channel.mjs", "send")
pub fn send(channel: Channel(a), value: a) -> Nil

@external(javascript, "../../drift_channel.mjs", "receive")
fn channel_receive(
  channel: Channel(a),
  callback: fn(a) -> Nil,
) -> Result(Bool, Nil)

@external(javascript, "../../drift_channel.mjs", "cancel_receive")
fn cancel_receive(channel: Channel(a), callback: fn(a) -> Nil) -> Nil
