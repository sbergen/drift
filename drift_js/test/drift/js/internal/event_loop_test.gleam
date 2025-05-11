import drift/js/internal/event_loop.{
  type Event, type EventLoop, AlreadyReceiving, AlreadyTicking, HandleInput,
  Stopped, Tick,
}
import gleam/javascript/promise.{type Promise, await}

pub fn receive_when_empty_test() {
  let loop = event_loop.start()

  use result <- await(receive_immediate(loop))
  let assert Error(Nil) = result as "should not receive when nothing sent"

  promise.resolve(Nil)
}

pub fn send_before_receive_test() {
  let loop = event_loop.start()

  event_loop.send(loop, 42)
  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(42)) = result as "message should be received"

  promise.resolve(Nil)
}

pub fn multiple_send_before_receive_test() {
  let loop = event_loop.start()

  event_loop.send(loop, 1)
  event_loop.send(loop, 2)

  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(1)) = result as "message should be received"

  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(2)) = result as "message should be received"

  use result <- await(receive_immediate(loop))
  let assert Error(Nil) = result as "messages should be exhausted"

  promise.resolve(Nil)
}

pub fn receive_before_send_test() {
  let loop = event_loop.start()

  let assert Ok(result) = event_loop.receive(loop)
  event_loop.send(loop, 42)

  use result <- await(timeout(result, 0))
  let assert Ok(HandleInput(42)) = result as "message should be received"

  promise.resolve(Nil)
}

pub fn double_receive_is_error_test() {
  let loop = event_loop.start()
  let _ = event_loop.receive(loop)
  let assert Error(AlreadyReceiving) = event_loop.receive(loop)
}

pub fn timeout_triggers_tick_test() {
  let loop = event_loop.start()

  let assert Ok(Nil) = event_loop.set_timeout(loop, 0)
  use result <- await(receive_immediate(loop))
  let assert Ok(Tick) = result

  promise.resolve(Nil)
}

pub fn send_cancels_timeout_test() {
  let loop = event_loop.start()

  let assert Ok(Nil) = event_loop.set_timeout(loop, 10)
  event_loop.send(loop, 0)
  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(0)) = result

  let assert Ok(result) = event_loop.receive(loop)
  use result <- await(timeout(result, 20))
  let assert Error(Nil) = result as "no timeout should be triggered"

  promise.resolve(Nil)
}

pub fn queued_receive_cancels_timeout_test() {
  let loop = event_loop.start()

  event_loop.send(loop, 0)
  let assert Ok(Nil) = event_loop.set_timeout(loop, 10)

  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(0)) = result

  let assert Ok(result) = event_loop.receive(loop)
  use result <- await(timeout(result, 20))
  let assert Error(Nil) = result as "no timeout should be triggered"

  promise.resolve(Nil)
}

pub fn interleaved_queued_receive_cancels_timeout_test() {
  let loop = event_loop.start()

  event_loop.send(loop, 0)
  event_loop.send(loop, 1)
  let assert Ok(Nil) = event_loop.set_timeout(loop, 10)

  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(0)) = result
  let assert Ok(Nil) = event_loop.set_timeout(loop, 10)

  use result <- await(receive_immediate(loop))
  let assert Ok(HandleInput(1)) = result

  let assert Ok(result) = event_loop.receive(loop)
  use result <- await(timeout(result, 20))
  let assert Error(Nil) = result as "no timeout should be triggered"

  promise.resolve(Nil)
}

pub fn double_timeout_is_error_test() {
  let loop = event_loop.start()

  let assert Ok(Nil) = event_loop.set_timeout(loop, 0)
  let assert Error(AlreadyTicking) = event_loop.set_timeout(loop, 0)
}

pub fn operations_are_failures_after_stop_test() {
  let loop = event_loop.start()
  event_loop.stop(loop)

  let assert Error(Stopped) = event_loop.receive(loop)
  let assert Error(Stopped) = event_loop.set_timeout(loop, 0)
}

pub fn error_if_stopped_triggers_test() {
  let loop = event_loop.start()

  let #(operation, _) = promise.start()
  let operation = event_loop.error_if_stopped(loop, operation, "error")
  event_loop.stop(loop)
  use result <- await(timeout(operation, 0))
  let assert Ok(Error("error")) = result

  promise.resolve(Nil)
}

pub fn error_if_stopped_stop_late_test() {
  let loop = event_loop.start()

  let #(operation, resolve) = promise.start()
  let operation = event_loop.error_if_stopped(loop, operation, "error")
  resolve(42)
  use result <- await(timeout(operation, 0))
  let assert Ok(Ok(42)) = result

  // This shouldn't trigger anything odd!
  event_loop.stop(loop)

  promise.resolve(Nil)
}

pub fn error_if_stopped_after_stop_test() {
  let loop = event_loop.start()
  event_loop.stop(loop)

  let #(operation, _) = promise.start()
  let operation = event_loop.error_if_stopped(loop, operation, "error")
  use result <- await(timeout(operation, 0))
  let assert Ok(Error("error")) = result

  promise.resolve(Nil)
}

pub fn receive_immediate(loop: EventLoop(i)) -> Promise(Result(Event(i), Nil)) {
  let assert Ok(next) = event_loop.receive(loop) as "should not be receiving"
  timeout(next, 0)
}

fn timeout(p: Promise(a), timeout: Int) -> Promise(Result(a, Nil)) {
  let timeout =
    promise.wait(timeout)
    |> promise.map(Error)
  promise.race_list([promise.map(p, Ok), timeout])
}
