//// The erlang actor-based implementation for the drift catfacts example.

import catfacts
import drift/actor
import drift/effect
import gleam/erlang/process.{type Selector, type Subject}
import gleam/httpc
import gleam/result
import gleam/string

/// A cat facts client
pub opaque type Catfacts {
  Catfacts(actor: Subject(catfacts.Input))
}

/// Starts a new cat facts actor.
pub fn new() -> Catfacts {
  // The init really shouldn't fail, so we just assert success.
  let assert Ok(actor) =
    actor.using_io(new_io, handle_output)
    |> actor.start(100, catfacts.new(), catfacts.handle_input)
  Catfacts(actor)
}

/// Wrapper function for performing the fetch in a blocking call,
/// as is typical for Erlang.
pub fn fetch(client: Catfacts) -> String {
  actor.call(client.actor, 2000, catfacts.FetchFact)
}

/// This holds the state for our IO context
type IoState {
  IoState(self: Subject(catfacts.Input))
}

fn new_io() -> #(IoState, Selector(catfacts.Input)) {
  let self = process.new_subject()
  let selector = process.new_selector() |> process.select(self)
  #(IoState(self), selector)
}

/// The main IO driver function for our Erlang cat facts implementation
fn handle_output(
  ctx: effect.Context(IoState, process.Selector(catfacts.Input)),
  output: catfacts.Output,
) -> Result(effect.Context(IoState, process.Selector(catfacts.Input)), String) {
  case output {
    // side effects must be completed outside of the pure context.
    // For simple side effects, we can just call `effect.perform`.
    catfacts.CompleteFetch(complete) -> Ok(effect.perform(ctx, complete))

    // This is the main task we need to perform, an HTTP GET.
    // We make the errors fatal here for simplicity, but in real situations,
    // it would be better to report the errors to the stepper.
    catfacts.HttpSend(request:, continuation:) -> {
      let result =
        httpc.send(request)
        |> result.map_error(string.inspect)

      // Report errors to the stepper.
      // Returning an error here would terminate the actor.
      Ok({
        use state <- effect.map_context(ctx)
        process.send(
          state.self,
          catfacts.HttpGetCompleted(continuation, result),
        )
        state
      })
    }
  }
}
