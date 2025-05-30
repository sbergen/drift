import drift.{type Context, type Step, Continue, Stop, StopWithError}
import drift/effect.{type Effect}
import gleam/bool
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

/// The state of the wrapping actor.
/// /// Should not be used, but must be public for supporting actor builders.
pub opaque type State(state, io, input, output, error) {
  State(
    stepper: drift.Stepper(state, input),
    timer: Option(process.Timer),
    effect_ctx: effect.Context(io, Selector(input)),
    io_driver: IoDriver(io, input, output),
    self: Subject(Msg(input)),
    base_selector: Selector(Msg(input)),
    handle_input: fn(Context(input, output), state, input) ->
      Step(state, input, output, error),
  )
}

/// The message type of the wrapping actor.
/// Should not be used, but must be public for supporting actor builders.
pub opaque type Msg(i) {
  Tick
  HandleInput(i)
}

/// Holds the functions required to run the IO for a drift actor.
pub opaque type IoDriver(state, input, output) {
  IoDriver(
    init: fn() -> #(state, Selector(input)),
    handle_output: fn(effect.Context(state, Selector(input)), output) ->
      Result(effect.Context(state, Selector(input)), String),
  )
}

/// Sets up an `IoDriver` instance, for starting a drift actor.
pub fn using_io(
  init: fn() -> #(state, Selector(input)),
  handle_output: fn(effect.Context(state, Selector(input)), output) ->
    Result(effect.Context(state, Selector(input)), String),
) -> IoDriver(state, input, output) {
  IoDriver(init, handle_output)
}

/// Starts a simple actor linked to the current process. No supervision.
/// On success, messages sent to the returned `Subject` will be handled
/// by the given input handling function, and the actor will take care of
/// all state transitions.
pub fn start(
  io_driver: IoDriver(io, i, o),
  timeout: Int,
  state: s,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> Result(Subject(i), actor.StartError) {
  builder(io_driver, timeout, state, handle_input, None, fn(_) { Nil })
  |> actor.start()
  |> result.map(fn(init) { init.data })
}

/// Behaves like `start`, except that it provides an actor builder that allows
/// more configurability for advanced use cases, like supervision.
/// NOTE: Do not reconfigure `on_message`!
/// 
/// If provided, `report_to` will be sent a message returned by `make_report`
/// when the actor is initialized.
pub fn builder(
  io_driver: IoDriver(io, i, o),
  timeout: Int,
  state: s,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
  report_to: Option(Subject(r)),
  make_report: fn(Subject(i)) -> r,
) -> actor.Builder(State(s, io, i, o, e), Msg(i), Subject(i)) {
  actor.new_with_initialiser(timeout, fn(self) {
    let #(io_state, input_selector) = io_driver.init()

    let #(stepper, effect_ctx) = drift.new(state, io_state, input_selector)

    let inputs = process.new_subject()
    let base_selector =
      process.new_selector()
      |> process.select_map(inputs, HandleInput)
      |> process.select(self)

    let state =
      State(
        stepper:,
        timer: None,
        effect_ctx:,
        io_driver:,
        self:,
        base_selector:,
        handle_input:,
      )

    let init =
      actor.initialised(state)
      |> actor.selecting(
        input_selector
        |> process.map_selector(HandleInput)
        |> process.merge_selector(base_selector),
      )
      |> actor.returning(inputs)

    case report_to {
      Some(subject) -> process.send(subject, make_report(inputs))
      None -> Nil
    }

    Ok(init)
  })
  |> actor.on_message(handle_message)
}

/// This function will be called from the actor process
/// Similar to `process.call_forver`, but dispatches to the stepper. 
pub fn call_forever(
  actor: Subject(message),
  sending make_request: fn(Effect(reply)) -> message,
) -> reply {
  process.call_forever(actor, fn(reply_to) {
    make_request(effect.from(process.send(reply_to, _)))
  })
}

/// Similar to `process.call`, but dispatches to the stepper.
pub fn call(
  actor: Subject(message),
  waiting timeout: Int,
  sending make_request: fn(Effect(reply)) -> message,
) -> reply {
  process.call(actor, timeout, fn(reply_to) {
    make_request(effect.from(process.send(reply_to, _)))
  })
}

//==== Privates ====//

fn handle_message(
  state: State(s, io, i, o, e),
  message: Msg(i),
) -> actor.Next(State(s, io, i, o, e), Msg(i)) {
  let now = now()

  // Either tick or handle input
  let next = case message {
    Tick -> drift.tick(state.stepper, now, state.handle_input)

    HandleInput(input) -> {
      case state.timer {
        Some(timer) -> process.cancel_timer(timer)
        None -> process.TimerNotFound
      }

      drift.step(state.stepper, now, input, state.handle_input)
    }
  }

  // Apply effects, no matter if stopped or not
  let io_result =
    list.fold(next.outputs, Ok(state.effect_ctx), fn(io_state, output) {
      use io_state <- result.try(io_state)
      state.io_driver.handle_output(io_state, output)
    })

  case next {
    Continue(_effects, stepper, due_time) -> {
      // Start new timer if there's a due time
      let timer =
        due_time
        |> option.map(fn(due_time) {
          process.send_after(state.self, int.max(0, due_time - now), Tick)
        })

      let state = State(..state, stepper:, timer:)

      case io_result {
        Ok(effect_ctx) -> {
          let next = actor.continue(State(..state, effect_ctx:))
          use <- bool.guard(
            !effect.inputs_changed(effect_ctx, state.effect_ctx),
            next,
          )

          actor.with_selector(
            next,
            effect_ctx
              |> effect.inputs
              |> process.map_selector(HandleInput)
              |> process.merge_selector(state.base_selector),
          )
        }

        Error(reason) -> actor.stop_abnormal(reason)
      }
    }

    Stop(_effects, _state) -> actor.stop()

    StopWithError(_effects, reason) ->
      actor.stop_abnormal(string.inspect(reason))
  }
}

@external(erlang, "drift_actor_external", "now")
fn now() -> Int
