import drift.{type Action}
import drift/actor
import gleam/erlang/process.{type Subject}
import gleam/function

type Input {
  Sum(Int)
  Read(drift.Effect(Int))
  ChangeInputSelector
}

type Output {
  ReadResult(Action(Int))
  ChangeInputs
}

pub fn no_input_change_test() {
  let inputs = process.new_subject()
  let actor_subject = start_actor(inputs)

  // Receive the input subject, and send directly to it (not the actor)
  let assert Ok(inputs) = process.receive(inputs, 100)
  process.send(inputs, Sum(40))
  process.send(inputs, Sum(2))
  assert actor.call(actor_subject, 100, Read) == 42
}

pub fn input_change_test() {
  let inputs_source = process.new_subject()
  let actor_subject = start_actor(inputs_source)

  // Receive the input subject, and send directly to it (not the actor)
  let assert Ok(inputs) = process.receive(inputs_source, 100)
  process.send(inputs, Sum(40))

  // Change input selector
  process.send(actor_subject, ChangeInputSelector)

  // Now, receive the new inputs, and send to it
  let assert Ok(new_inputs) = process.receive(inputs_source, 100)
  process.send(new_inputs, Sum(2))

  // Sending to the old selector should be ignored
  process.send(inputs, Sum(100))

  assert actor.call(actor_subject, 100, Read) == 42
}

fn start_actor(inputs: Subject(Subject(Input))) -> Subject(Input) {
  // Actor that sums inputs and can switch input subjects
  let assert Ok(actor_subject) =
    actor.using_io(
      // the io state is the input selector
      fn() {
        let subject = process.new_subject()
        process.send(inputs, subject)
        process.new_selector() |> process.select(subject)
      },
      function.identity,
      fn(effect_ctx, output) {
        Ok(case output {
          ReadResult(result) -> {
            drift.perform_effect(effect_ctx, result)
          }
          ChangeInputs -> {
            use _old_inputs <- drift.use_effect_context(effect_ctx)
            let new_inputs = process.new_subject()
            process.send(inputs, new_inputs)

            let new_inputs =
              process.new_selector() |> process.select(new_inputs)
            new_inputs
          }
        })
      },
    )
    |> actor.start(100, 0, fn(ctx, state, input) {
      case input {
        Sum(value) -> ctx |> drift.continue(state + value)

        Read(reply_to) ->
          ctx
          |> drift.output(ReadResult(drift.bind_effect(reply_to, state)))
          |> drift.continue(state)

        ChangeInputSelector -> {
          ctx
          |> drift.output(ChangeInputs)
          |> drift.continue(state)
        }
      }
    })

  actor_subject
}
