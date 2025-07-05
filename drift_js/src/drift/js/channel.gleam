import gleam/javascript/promise

/// An unbounded multiple-producer, single-consumer channel.
/// Intended to be used similarly to an Erlang `Subject`
pub type Channel(a)

/// Creates a new channel.
@external(javascript, "../../drift_channel.mjs", "new_channel")
pub fn new() -> Channel(a)

/// Returns a promise that will resolve with a value when the channel has one available,
/// or an error, if a receive is already active.
/// The promise may resolve synchronously if a value is already available,
/// and it will resolve synchronously for errors.
/// Returning the error in the promise provides a more ergonomic interface,
/// even though it's always synchronous.
pub fn receive(channel: Channel(a)) -> promise.Promise(Result(a, Nil)) {
  let #(promise, resolve) = promise.start()
  case channel_receive(channel, resolve) {
    Ok(_) -> promise.map(promise, Ok)
    Error(_) -> promise.resolve(Error(Nil))
  }
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
