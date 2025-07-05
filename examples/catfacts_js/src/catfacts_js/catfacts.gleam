import catfacts
import drift.{type EffectContext}
import drift/js/runtime.{type Runtime}
import gleam/fetch
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string

/// A cat facts client
pub opaque type Catfacts {
  Catfacts(runtime: Runtime(catfacts.Input))
}

/// Starts a new cat facts client.
pub fn new() -> Catfacts {
  // The terminal result can be accessed through the promise below,
  // but we aren't interested in it.
  let #(_terminal_result, rt) =
    runtime.start(
      catfacts.new(),
      fn(_) { Nil },
      catfacts.handle_input,
      handle_output,
    )
  Catfacts(rt)
}

/// Wrapper function for performing the fetch.
pub fn fetch(client: Catfacts) -> Promise(String) {
  use result <- promise.await(runtime.call(
    client.runtime,
    2000,
    catfacts.FetchFact,
  ))

  // For simplicity, we just translate the error to a string.
  // In a real situation errors should be handled properly.
  promise.resolve(case result {
    Ok(result) -> result
    Error(e) -> "Error: " <> string.inspect(e)
  })
}

/// The main IO driver function for our JS cat facts implementation
fn handle_output(
  ctx: EffectContext(Nil),
  output: catfacts.Output,
  send: fn(catfacts.Input) -> Nil,
) -> Result(EffectContext(Nil), String) {
  case output {
    // side effects must be completed outside of the pure context.
    // For simple side effects, we can just call `perform_effect`.
    catfacts.CompleteFetch(complete) -> Ok(drift.perform_effect(ctx, complete))

    // This is the main task we need to perform, an HTTP GET.
    // We make the errors fatal here for simplicity, but in real situations,
    // it would be better to report the errors to the stepper.
    catfacts.HttpSend(request:, continuation:) -> {
      // Fire and forget the HTTP request
      {
        use response <- promise.map(
          fetch.send(request)
          |> promise.try_await(fetch.read_text_body),
        )

        let result = result.map_error(response, string.inspect)
        send(catfacts.HttpGetCompleted(continuation, result))
      }

      Ok(ctx)
    }
  }
}
