//// The erlang actor-based implementation for the drift catfacts example.

import catfacts
import drift.{type EffectContext}
import drift/actor
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
    actor.using_io(new_io, fn(io_state) { io_state.selector }, handle_output)
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
  IoState(self: Subject(catfacts.Input), selector: Selector(catfacts.Input))
}

fn new_io() -> IoState {
  let self = process.new_subject()
  let selector = process.new_selector() |> process.select(self)
  IoState(self, selector)
}

/// The main IO driver function for our Erlang cat facts implementation
fn handle_output(
  ctx: EffectContext(IoState),
  output: catfacts.Output,
) -> Result(EffectContext(IoState), String) {
  case output {
    // side effects must be completed outside of the pure context.
    // For simple side effects, we can just call `perform_effect`.
    catfacts.CompleteFetch(complete) -> Ok(drift.perform_effect(ctx, complete))

    // This is the main task we need to perform, an HTTP GET.
    catfacts.HttpSend(request:, continuation:) -> {
      // We return success here. Returning an error would terminate the actor.
      Ok({
        // The state stored in the context can be accessed with use_effect_context.
        use state <- drift.use_effect_context(ctx)

        // If we did a blocking request here, it would prevent the stepper
        // from handling any further messages, so we spawn a process for the request.
        // This is simplified example code, where the child process running into
        // an error would bring the whole actor down!
        // You'd probably want to handle this very differently in non-example code.
        process.spawn(fn() {
          let result =
            httpc.send(request)
            |> result.map_error(string.inspect)

          // Once the request is complete, we send a message to the subject
          // that is linked to the input selector, which will run the next step.
          process.send(
            state.self,
            catfacts.HttpGetCompleted(continuation, result),
          )
        })

        // We didn't modify the sate, so we just return it.
        state
      })
    }
  }
}
