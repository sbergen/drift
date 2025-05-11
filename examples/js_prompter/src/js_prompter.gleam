import drift/example/prompter.{type Input, StartPrompt}
import drift/js/runtime
import gleam/io
import gleam/javascript/promise

pub fn main() {
  let #(result, r) =
    runtime.start(
      prompter.new_state(),
      Nil,
      prompter.handle_input,
      handle_output,
    )

  use _ <- promise.await(
    runtime.call_forever(r, StartPrompt("What's your name?", _)),
  )

  use _ <- promise.await(
    runtime.call_forever(r, StartPrompt("Who's the best?", _)),
  )

  runtime.send(r, prompter.Stop)

  use result <- promise.await(result)
  let assert Ok(Nil) = result
  promise.resolve(Nil)
}

fn handle_output(
  state: Nil,
  output: prompter.Output,
  send: fn(Input) -> Nil,
) -> Result(Nil, e) {
  case output {
    prompter.Prompt(prompt) -> {
      io.println(prompt)
      read_line(fn(result) {
        let assert Ok(text) = result
        send(prompter.UserEntered(text))
      })
      Ok(state)
    }
    prompter.Print(text) -> {
      io.println(text)
      Ok(state)
    }
  }
}

@external(javascript, "./drift_js_example.mjs", "read_line")
fn read_line(callback: fn(Result(String, Nil)) -> Nil) -> Nil
