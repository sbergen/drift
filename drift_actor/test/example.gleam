import drift
import drift/actor
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import gleam/string

pub fn main() {
  // Start a stepper that adds all the numbers sent to it,
  // until None is encountered
  let assert Ok(subject) =
    actor.using_io(
      fn() {
        // No inputs in this examples
        #(Nil, process.new_selector())
      },
      fn(ctx, output) {
        io.println(string.inspect(output))
        Ok(ctx)
      },
    )
    |> actor.start(100, 0, fn(ctx, state, input) {
      case input {
        Some(input) -> drift.continue(ctx, state + input)
        None ->
          ctx
          |> drift.output(state)
          |> drift.stop(state)
      }
    })

  process.send(subject, Some(40))
  process.send(subject, Some(2))

  // This will terminate the actor, and print 42
  process.send(subject, None)

  // But we need to wait for the message to be handled...
  process.sleep(100)
}
