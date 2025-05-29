import catfacts_erlang/catfacts
import gleam/io

/// This is how a user of the erlang package would use cat facts.
pub fn main() -> Nil {
  let client = catfacts.new()

  // Fetch a few facts:
  io.println(catfacts.fetch(client))
  io.println(catfacts.fetch(client))
}
