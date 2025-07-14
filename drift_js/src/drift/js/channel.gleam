import gleam/javascript/promise
import gleam/result

/// An unbounded single-consumer channel with synchronous sending
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
/// and it will resolve synchronously for errors.
/// Returning the error in the promise provides a more ergonomic interface,
/// even though it's always synchronous.
pub fn receive_forever(
  from channel: Channel(a),
) -> promise.Promise(Result(a, Nil)) {
  let #(promise, resolve) = promise.start()
  case channel_receive(channel, resolve) {
    Ok(_) -> promise.map(promise, Ok)
    Error(_) -> promise.resolve(Error(Nil))
  }
}

/// Returns a promise that will resolve with a value when the channel has one available,
/// or an error if the timeout (in milliseconds) is reached before a value is available
/// or a receive is already active.
/// The promise may resolve synchronously if a value is already available,
/// and it will resolve synchronously if a receive is already active.
pub fn receive(
  from channel: Channel(a),
  within timeout: Int,
) -> promise.Promise(Result(a, ReceiveError)) {
  let receive =
    receive_forever(channel)
    |> promise.map(result.replace_error(_, AlreadyReceiving))

  let timeout =
    promise.wait(timeout)
    |> promise.map(fn(_) {
      cancel_receive(channel)
      Error(ReceiveTimeout)
    })

  promise.race_list([receive, timeout])
}

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
fn cancel_receive(channel: Channel(a)) -> Nil
