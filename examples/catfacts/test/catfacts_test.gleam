import birdie
import catfacts.{type Input, type Output}
import drift
import drift/record
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/option
import gleam/uri
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
    let assert [catfacts.HttpSend(_, continuation)] = outputs
    let response = ok_response("{ \"fact\": \"An interesting cat fact!\" }")
    record.input(recorder, catfacts.HttpGetCompleted(continuation, response))
  })
  |> record.to_log
  |> birdie.snap("Valid cat fact JSON fetching")
}

pub fn fetch_invalid_json_test() {
  new_recorder()
  |> record.input(catfacts.FetchFact(record.discard()))
  |> record.use_latest_outputs(fn(recorder, outputs) {
    let assert [catfacts.HttpSend(_, continuation)] = outputs
    let response = ok_response("Not valid json!")
    record.input(recorder, catfacts.HttpGetCompleted(continuation, response))
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

fn format_message(msg: record.Message(Input, Output, String)) {
  case msg {
    record.Input(input) ->
      case input {
        catfacts.FetchFact(complete) ->
          "Fetch fact #" <> int.to_string(drift.effect_id(complete))

        catfacts.HttpGetCompleted(continuation, result) ->
          "Complete HTTP GET #"
          <> int.to_string(drift.continuation_id(continuation))
          <> case result {
            Ok(response) -> " successfully: " <> response.body
            Error(error) -> " with error: " <> error
          }
      }
    record.Output(output) ->
      case output {
        catfacts.CompleteFetch(completion) ->
          "Complete fetch #"
          <> int.to_string(drift.effect_id(completion.effect))
          <> " with: "
          <> completion.argument

        catfacts.HttpSend(request:, continuation:) ->
          http.method_to_string(request.method)
          <> " "
          <> uri.to_string(request.to_uri(request))
          <> " - respond to #"
          <> int.to_string(drift.continuation_id(continuation))
      }
    record.Error(e) -> "Error: " <> e
  }
}

fn ok_response(body: String) -> Result(response.Response(String), String) {
  Ok(response.Response(200, [], body))
}
