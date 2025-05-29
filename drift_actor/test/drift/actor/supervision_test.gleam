import drift
import drift/actor
import gleam/erlang/process.{type Pid, type Subject}
import gleam/option.{Some}
import gleam/otp/actor as otp_actor
import gleam/otp/static_supervisor
import gleam/otp/supervision

pub fn supervision_test() {
  let children = process.new_subject()

  let assert Ok(supervisor) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(init_panicing_child(children))
    |> static_supervisor.start

  let assert Ok(#(pid1, inputs)) = process.receive(children, 10)
    as "Child should start"

  // This should trigger stopping with an error
  process.send(inputs, Nil)

  let assert Ok(#(pid2, _)) = process.receive(children, 10)
    as "Child should restart"

  let assert False = process.is_alive(pid1)
  let assert True = process.is_alive(pid2)

  process.send_exit(supervisor.pid)
}

fn init_panicing_child(
  subject: Subject(#(Pid, Subject(Nil))),
) -> supervision.ChildSpecification(Subject(Nil)) {
  supervision.worker(fn() {
    actor.using_io(fn() { #(Nil, process.new_selector()) }, fn(ctx, _) {
      Ok(ctx)
    })
    |> actor.builder(
      100,
      Nil,
      fn(ctx, _, _) { drift.stop_with_error(ctx, "Stepper failing!") },
      Some(subject),
      fn(inputs) { #(process.self(), inputs) },
    )
    |> otp_actor.start
  })
}
