import drift/actor
import drift/effect
import drift/example/prompter.{StartPrompt, Stop, UserEntered}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/io
import gleam/option.{type Option, None, Some}
import input

pub fn main() -> Nil {
  let actor = new_prompter_actor()

  let assert Ok(Nil) = prompt(actor, "What's your name? ")
  let assert Ok(Nil) = prompt(actor, "Who's the best? ")

  process.send(actor, Stop)

  case process.subject_owner(actor) {
    Ok(actor_pid) -> wait_for_process(actor_pid)
    Error(_) -> Nil
  }
}

fn prompt(actor: Subject(prompter.Input), prompt: String) -> Result(Nil, String) {
  actor.call_forever(actor, StartPrompt(prompt, _))
}

fn wait_for_process(pid: process.Pid) -> Nil {
  case process.is_alive(pid) {
    False -> Nil
    True -> {
      process.sleep(10)
      wait_for_process(pid)
    }
  }
}

fn new_prompter_actor() -> process.Subject(prompter.Input) {
  let assert Ok(actor) =
    actor.using_io(new_io_driver, fn(driver, output) {
      case output {
        prompter.Prompt(prompt) -> {
          // Simulate async I/O
          let reply_to = process.new_subject()
          let pid =
            process.spawn(fn() {
              let assert Ok(result) = input.input(prompt)
              process.send(reply_to, result)
            })

          actor.InputSelectorChanged(
            effect.map_context(driver, fn(driver) {
              IoDriver(..driver, prompt_pid: Some(pid))
            }),
            process.new_selector()
              |> process.select_map(reply_to, UserEntered),
          )
        }

        prompter.Print(text) -> {
          io.println(text)
          actor.IoOk(driver)
        }

        prompter.CancelPrompt ->
          actor.IoOk(
            effect.map_context(driver, fn(driver) {
              case driver.prompt_pid {
                Some(pid) -> process.kill(pid)
                None -> Nil
              }
              IoDriver(..driver, prompt_pid: None)
            }),
          )

        prompter.CompletePrompt(action) ->
          actor.IoOk(effect.perform(driver, action))
      }
    })
    |> actor.start(1000, prompter.new_state(), prompter.handle_input)
  actor
}

fn new_io_driver() -> #(IoDriver, Selector(prompter.Input)) {
  #(IoDriver(io.println, None), process.new_selector())
}

type IoDriver {
  IoDriver(output: fn(String) -> Nil, prompt_pid: Option(process.Pid))
}
