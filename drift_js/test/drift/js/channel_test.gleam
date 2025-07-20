import drift/js/channel
import gleam/javascript/promise

pub fn send_before_receive_test() {
  let channel = channel.new()
  channel.send(channel, 42)
  use result <- promise.map(channel.receive_forever(channel))
  assert result == Ok(42)
}

pub fn send_after_receive_test() {
  let channel = channel.new()
  let result_promise = channel.receive_forever(channel)
  channel.send(channel, 42)
  use result <- promise.map(result_promise)
  assert result == Ok(42)
}

pub fn double_receive_forever_test() {
  let channel = channel.new()
  let promise1 = channel.receive_forever(channel)
  let promise2 = channel.receive_forever(channel)

  use result2 <- promise.await(promise2)
  assert result2 == Error(Nil)

  channel.send(channel, 42)
  use result1 <- promise.map(promise1)
  assert result1 == Ok(42)
}

pub fn multiple_receive_test() {
  let channel = channel.new()

  channel.send(channel, 1)
  let promise1 = channel.receive_forever(channel)

  channel.send(channel, 2)
  channel.send(channel, 3)
  let promise2 = channel.receive_forever(channel)
  let promise3 = channel.receive_forever(channel)

  use result <- promise.await(promise1)
  assert result == Ok(1)

  use result <- promise.await(promise2)
  assert result == Ok(2)

  use result <- promise.map(promise3)
  assert result == Ok(3)
}

pub fn receive_timeout_test() {
  let channel = channel.new()

  // Times out without value
  use result <- promise.await(channel.receive(channel, 1))
  assert result == Error(channel.ReceiveTimeout)

  // Can receive after
  channel.send(channel, 42)
  use result <- promise.map(channel.receive(channel, 10))
  assert result == Ok(42)

  // Can receive after previous timeout expires
  let pending = channel.receive(channel, 20)
  use _ <- promise.await(promise.wait(10))
  channel.send(channel, 43)

  use result <- promise.map(pending)
  assert result == Ok(43)
  Nil
}

pub fn double_receive_test() {
  let channel = channel.new()
  channel.receive(channel, 100)
  use result <- promise.map(channel.receive(channel, 100))
  assert result == Error(channel.AlreadyReceiving)
}

pub fn try_receive_test() {
  let channel = channel.new()
  assert channel.try_receive(channel) == Error(Nil)
  channel.send(channel, 1)
  channel.send(channel, 2)
  assert channel.try_receive(channel) == Ok(1)
  assert channel.try_receive(channel) == Ok(2)
  assert channel.try_receive(channel) == Error(Nil)
}

pub fn nil_channel_test() {
  let channel = channel.new()
  channel.send(channel, Nil)
  assert channel.try_receive(channel) == Ok(Nil)
  assert channel.try_receive(channel) == Error(Nil)

  channel.send(channel, Nil)
  use result <- promise.map(channel.receive(channel, 10))
  assert result == Ok(Nil)
}
