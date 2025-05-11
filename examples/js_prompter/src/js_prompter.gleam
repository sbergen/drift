import drift/example/prompter.{type Input, StartPrompt}
import drift/js/runtime
import gleam/io
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import gleam/string

pub fn main() {
  let #(result, r) =
    runtime.start(
      prompter.new_state(),
      IoState(None),
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

  // Pause stdin and stdout, to see if we've canceled everything properly.
  // If all streams and timers are canceled, the process should exit.
  pause_io()
  promise.resolve(Nil)
}

type IoState {
  IoState(cancel_read_stdin: Option(fn() -> Nil))
}

fn handle_output(
  state: IoState,
  output: prompter.Output,
  send: fn(Input) -> Nil,
) -> Result(IoState, e) {
  case output {
    prompter.Prompt(prompt) -> {
      // Cancel previous read, if running (not super safe, just a demo)
      case state.cancel_read_stdin {
        Some(cancel) -> cancel()
        None -> Nil
      }

      io.println(prompt)
      let cancel =
        read_stdin(fn(text) {
          send(prompter.UserEntered(string.trim_end(text)))
        })

      Ok(IoState(Some(cancel)))
    }

    prompter.CancelPrompt -> {
      case state.cancel_read_stdin {
        Some(cancel) -> cancel()
        None -> Nil
      }

      Ok(IoState(None))
    }

    prompter.Print(text) -> {
      io.println(text)
      Ok(state)
    }
  }
}

@external(javascript, "./drift_js_example.mjs", "read_stdin")
fn read_stdin(callback: fn(String) -> Nil) -> fn() -> Nil

@external(javascript, "./drift_js_example.mjs", "pause_io")
fn pause_io() -> Nil
