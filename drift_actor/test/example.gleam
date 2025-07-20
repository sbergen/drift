import drift
import drift/actor
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import gleam/string

pub fn main() {
  // Start a stepper that adds all the numbers sent to it,
  // until None is encountered
  let assert Ok(started) =
    actor.using_io(
      // No external inputs in this example 
      with_initial_state: fn() { process.new_selector() },
      selecting_inputs: fn(selector) { selector },
      // Print all the outputs
      handling_outputs_with: fn(io_state, output) {
        io.println(string.inspect(output))
        Ok(io_state)
      },
    )
    // This defines the pure part:
    |> actor.with_stepper(
      with_initial_state: 0,
      handling_inputs_with: fn(ctx, state, input) {
        case input {
          Some(input) -> drift.continue(ctx, state + input)
          None ->
            ctx
            |> drift.output(state)
            |> drift.stop(state)
        }
      },
    )
    // Start the actor without wrapping the subject
    |> actor.start(100, fn(subject) { subject })

  let subject = started.data

  process.send(subject, Some(40))
  process.send(subject, Some(2))

  // This will terminate the actor, and print 42
  process.send(subject, None)

  // But we need to wait for the message to be handled...
  process.sleep(100)
}
