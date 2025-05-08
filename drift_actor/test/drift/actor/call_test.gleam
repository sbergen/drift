import drift/actor
import drift/actor/echo_actor
import drift/actor/process_helper
import gleam/erlang/process
import gleam/list
import gleam/string
import gleeunit/should

pub fn call_forever_completes_call_test() {
  let a = echo_actor.new()
  let assert "Foo" = actor.call_forever(a, echo_actor.Echo("Foo", _))
  let assert "Bar" = actor.call_forever(a, echo_actor.Echo("Bar", _))
}

pub fn call_completes_call_test() {
  let a = echo_actor.new()
  let assert "Foo" = actor.call(a, 50, echo_actor.Echo("Foo", _))
  let assert "Bar" = actor.call(a, 50, echo_actor.Echo("Bar", _))
}

pub fn delayed_call_test() {
  let a = echo_actor.new()
  let assert "Foo" = actor.call(a, 50, echo_actor.EchoAfter("Foo", 1, _))
  let assert "Bar" = actor.call(a, 50, echo_actor.EchoAfter("Bar", 1, _))
}

pub fn concurrent_calls_test() {
  let a = echo_actor.new()

  list.range(0, 100)
  |> list.map(fn(i) {
    process.spawn(fn() {
      let str = string.inspect(i)
      let result = actor.call(a, 50, echo_actor.Echo(str, _))
      result |> should.equal(str)
    })
  })
  |> list.each(process_helper.wait_for_process)
}
