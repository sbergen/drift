import drift
import drift/actor
import gleam/erlang/process.{type Pid, type Subject}
import gleam/function
import gleam/otp/static_supervisor
import gleam/otp/supervision

pub fn supervision_test() {
  let children = process.new_subject()
  let child_name = process.new_name("supervision_test")

  let assert Ok(supervisor) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(init_panicking_child(children, child_name))
    |> static_supervisor.start

  let assert Ok(#(pid1, inputs)) = process.receive(children, 10)
    as "Child should start"

  // This should trigger stopping with an error
  process.send(inputs, Nil)

  let assert Ok(#(pid2, _)) = process.receive(children, 10)
    as "Child should restart"

  assert !process.is_alive(pid1)
  assert process.is_alive(pid2)

  // We should be able to use the same named subject again,
  // to kill the newly spawned child.
  process.send(inputs, Nil)
  assert !process.is_alive(pid2)

  process.send_exit(supervisor.pid)
}

fn init_panicking_child(
  subject: Subject(#(Pid, Subject(Nil))),
  name: process.Name(Nil),
) -> supervision.ChildSpecification(Subject(Nil)) {
  supervision.worker(fn() {
    actor.using_io(
      //
      fn() { process.new_selector() },
      function.identity,
      fn(ctx, _) { Ok(ctx) },
    )
    |> actor.with_stepper(Nil, fn(ctx, _, _) {
      drift.stop_with_error(ctx, "Stepper failing!")
    })
    |> actor.named(name)
    |> actor.start(100, fn(inputs) {
      process.send(subject, #(process.self(), inputs))
      inputs
    })
  })
}
