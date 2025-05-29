import birdie
import catfacts.{type Input, type Output}
import drift
import drift/effect
import drift/record
import gleam/option
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// Because steppers are purely functional, and we shouldn't care about
// the internal state, but rather the observable state of our code,
// snapshot testing the sequence of outputs in relation to inputs
// is a very powerful way to test!
pub fn fetch_valid_json_test() {
  new_recorder()
  |> record.input(catfacts.FetchFact(record.discard()))
  |> record.use_latest_outputs(fn(recorder, outputs) {
    let assert [catfacts.HttpGet(_, continuation)] = outputs
    let json = "{ \"fact\": \"An interesting cat fact!\" }"
    record.input(recorder, catfacts.HttpGetCompleted(continuation, json))
  })
  |> record.to_log
  |> birdie.snap("Valid cat fact JSON fetching")
}

pub fn fetch_invalid_json_test() {
  new_recorder()
  |> record.input(catfacts.FetchFact(record.discard()))
  |> record.use_latest_outputs(fn(recorder, outputs) {
    let assert [catfacts.HttpGet(_, continuation)] = outputs
    let json = "Not valid json!"
    record.input(recorder, catfacts.HttpGetCompleted(continuation, json))
  })
  |> record.to_log
  |> birdie.snap("Invalid cat fact JSON fetching")
}

fn new_recorder() {
  // To run snapshot tests, we only need to create a new state,
  catfacts.new()
  |> record.new(
    // provide the input handling function,
    catfacts.handle_input,
    // a function to format inputs and outputs into strings,
    format_message,
    // and optionally a function to format the final state.
    option.None,
  )
}

fn format_message(msg: record.Message(Input, Output)) {
  case msg {
    record.Input(input) ->
      case input {
        catfacts.FetchFact(complete) ->
          "Fetch fact #" <> string.inspect(effect.id(complete))

        catfacts.HttpGetCompleted(continuation, result) ->
          "Complete HTTP GET #"
          <> string.inspect(drift.continuation_id(continuation))
          <> " with: "
          <> result
      }
    record.Output(output) ->
      case output {
        catfacts.CompleteFetch(completion) ->
          "Complete fetch #"
          <> string.inspect(effect.id(completion.effect))
          <> " with: "
          <> string.inspect(completion.argument)

        catfacts.HttpGet(url:, continuation:) ->
          "GET "
          <> url
          <> " - respond to #"
          <> string.inspect(drift.continuation_id(continuation))
      }
  }
}
