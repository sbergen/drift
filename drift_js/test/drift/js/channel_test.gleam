import drift/js/channel
import gleam/javascript/promise

pub fn send_before_receive_test() {
  let channel = channel.new()
  channel.send(channel, 42)
  use result <- promise.map(channel.receive(channel))
  assert result == Ok(42)
}

pub fn send_after_receive_test() {
  let channel = channel.new()
  let result_promise = channel.receive(channel)
  channel.send(channel, 42)
  use result <- promise.map(result_promise)
  assert result == Ok(42)
}

pub fn double_receive_test() {
  let channel = channel.new()
  let promise1 = channel.receive(channel)
  let promise2 = channel.receive(channel)

  use result2 <- promise.await(promise2)
  assert result2 == Error(Nil)

  channel.send(channel, 42)
  use result1 <- promise.map(promise1)
  assert result1 == Ok(42)
}

pub fn multiple_receive_test() {
  let channel = channel.new()

  channel.send(channel, 1)
  let promise1 = channel.receive(channel)

  channel.send(channel, 2)
  channel.send(channel, 3)
  let promise2 = channel.receive(channel)
  let promise3 = channel.receive(channel)

  use result <- promise.await(promise1)
  assert result == Ok(1)

  use result <- promise.await(promise2)
  assert result == Ok(2)

  use result <- promise.map(promise3)
  assert result == Ok(3)
}
