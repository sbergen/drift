import catfacts_erlang/catfacts
import gleam/erlang/process
import gleam/function
import gleam/io

/// This is how a user of the erlang package would use cat facts.
pub fn main() -> Nil {
  let client = catfacts.new()

  // We can use the same client from multiple processes:
  let child = process.spawn(fn() { io.println(catfacts.fetch(client)) })
  io.println(catfacts.fetch(client))

  // Finally, we need to wait for the child to terminate:
  process.monitor(child)
  process.new_selector()
  |> process.select_monitors(function.identity)
  |> process.selector_receive_forever

  Nil
}
