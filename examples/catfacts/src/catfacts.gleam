import drift
import drift/effect.{type Action, type Effect}
import gleam/dynamic/decode.{type Decoder}
import gleam/json
import gleam/string

/// This is the state of our cat facts fetcher.
pub opaque type State {
  /// We simply hold the number of facts published.
  State(fact_count: Int)
}

/// Specifies the available inputs for our cat facts logic.
pub type Input {
  /// A command to fetch a cat fact.
  /// The `Effect` type is used to complete the operation. 
  FetchFact(Effect(String))

  /// Represents a completed HTTP GET, from the wrapping runtime
  HttpGetCompleted(Continuation(String), String)
}

/// Specifies the outputs that the wrapping runtime must handle.
pub type Output {
  /// The runtime should fetch the given url,
  /// and then continue execution with the continuation.
  HttpGet(url: String, continuation: Continuation(String))

  /// Completes the fetch. The `Action` is an effect bound to a value.
  CompleteFetch(Action(String))
}

/// We are using a string for fatal errors to keep things simple
pub type Error =
  String

/// Since the continuation types is rather complex,
/// it's good to give it a type alias.
pub type Continuation(a) =
  drift.Continuation(a, State, Input, Output, Error)

/// The same applies to the stepping context
pub type Context =
  drift.Context(Input, Output)

/// ...and step type
pub type Step =
  drift.Step(State, Input, Output, Error)

/// Constructs a new state for cat facts.
pub fn new() -> State {
  State(1)
}

/// Handles an input, producing the step result.
pub fn handle_input(ctx: Context, state: State, input: Input) -> Step {
  case input {
    FetchFact(complete) -> fetch_fact(ctx, state, complete)
    HttpGetCompleted(continuation, result) ->
      drift.resume(ctx, state, continuation, result)
  }
}

// Note that all other functions can be private to the module:
// Only the initial state and input handling need to be public!

fn fetch_fact(ctx: Context, state: State, complete: Effect(String)) -> Step {
  let url = "https://catfact.ninja/fact"
  // We can perform continuations using the `await` function
  use ctx, state, result <- drift.await(ctx, state, HttpGet(url, _))

  case json.parse(result, decode_cat_fact()) {
    // We got valid cat fact json, complete the operation!
    Ok(fact) -> {
      let fact =
        "Cat fact #" <> string.inspect(state.fact_count) <> ": " <> fact
      ctx
      |> drift.perform(CompleteFetch, complete, fact)
      |> drift.continue(State(state.fact_count + 1))
    }

    // We failed to parse the json.
    // This would be better handled with an output indicating an error,
    // but we stop with an error for demonstration purposes.
    // No more cat facts can be fetched after this :(
    Error(error) -> drift.stop_with_error(ctx, string.inspect(error))
  }
}

/// Decodes the fact from the cat fact json
fn decode_cat_fact() -> Decoder(String) {
  decode.field("fact", decode.string, decode.success)
}
