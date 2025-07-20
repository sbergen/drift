//// Wraps a pure functional core defined with `drift` as an OTP actor.

import drift.{
  type Context, type Effect, type EffectContext, type Step, Continue, Stop,
  StopWithError,
}
import gleam/bool
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

/// The state of the wrapping actor.
type State(state, io, input, output, error) {
  State(
    stepper: drift.Stepper(state, input),
    timer: Option(process.Timer),
    effect_ctx: EffectContext(io),
    input_selector: Selector(input),
    io_driver: IoDriver(io, input, output),
    self: Subject(Msg(input)),
    base_selector: Selector(Msg(input)),
    handle_input: fn(Context(input, output), state, input) ->
      Step(state, input, output, error),
  )
}

/// The message type of the wrapping actor.
type Msg(i) {
  Tick
  HandleInput(i)
}

/// Holds the functions required to run the IO for a drift actor.
pub opaque type IoDriver(state, input, output) {
  IoDriver(
    init: fn() -> state,
    get_selector: fn(state) -> Selector(input),
    handle_output: fn(EffectContext(state), output) ->
      Result(EffectContext(state), String),
  )
}

/// Sets up an `IoDriver` instance, for starting a drift actor.
/// The init function will be called from the actor process,
/// and should return the initial state and input selector.
/// The output handler function gets the effect context and output as arguments,
/// and returns the new effect context or an error.
/// `get_selector` should extract the `Selector` for inputs from the io state.
pub fn using_io(
  with_initial_state init: fn() -> state,
  selecting_inputs get_selector: fn(state) -> Selector(input),
  handling_outputs_with handle_output: fn(EffectContext(state), output) ->
    Result(EffectContext(state), String),
) -> IoDriver(state, input, output) {
  IoDriver(init, get_selector, handle_output)
}

pub opaque type Builder(s, io, i, o, e) {
  Builder(
    io_driver: IoDriver(io, i, o),
    initial_state: s,
    handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
    name: Option(process.Name(i)),
  )
}

/// Configures the drift stepper to use with the actor,
/// this is the second mandatory step after configuring the IO,
/// after which other options are optional.
pub fn with_stepper(
  io_driver: IoDriver(io, i, o),
  with_initial_state initial_state: s,
  handling_inputs_with handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) {
  Builder(io_driver:, initial_state:, handle_input:, name: None)
}

/// Configures the actor to use a named process and subject for the inputs.
/// This allows using supervision and not invalidating previous subjects
/// on restarts.
pub fn named(
  builder: Builder(s, io, i, o, e),
  name: process.Name(i),
) -> Builder(s, io, i, o, e) {
  Builder(..builder, name: Some(name))
}

/// Starts the actor with the provided configuration, timeout and possible
/// extra initialization.
/// The extra initialization will happen as part of the actor initialization,
/// and contributes to the timeout limit.
/// If you want to do asynchronous initialization, consider sending a message
/// to another process.
pub fn start(
  builder: Builder(s, io, i, o, e),
  timeout: Int,
  init: fn(Subject(i)) -> result,
) -> Result(actor.Started(result), actor.StartError) {
  actor.new_with_initialiser(timeout, fn(self) {
    use inputs <- result.try(create_input_subject(builder.name))
    let io_state = builder.io_driver.init()
    let #(stepper, effect_ctx) = drift.new(builder.initial_state, io_state)

    let base_selector =
      process.new_selector()
      |> process.select_map(inputs, HandleInput)
      |> process.select(self)

    let input_selector = builder.io_driver.get_selector(io_state)

    let state =
      State(
        stepper:,
        timer: None,
        effect_ctx:,
        io_driver: builder.io_driver,
        input_selector:,
        self:,
        base_selector:,
        handle_input: builder.handle_input,
      )

    let initialised =
      actor.initialised(state)
      |> actor.selecting(
        input_selector
        |> process.map_selector(HandleInput)
        |> process.merge_selector(base_selector),
      )
      |> actor.returning(init(inputs))

    Ok(initialised)
  })
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn create_input_subject(
  name: Option(process.Name(i)),
) -> Result(Subject(i), String) {
  case name {
    Some(name) -> {
      use _ <- result.try(
        process.register(process.self(), name)
        |> result.replace_error("name already registered"),
      )
      Ok(process.named_subject(name))
    }
    None -> {
      Ok(process.new_subject())
    }
  }
}

/// Similar to `process.call_forever`, but dispatches to the stepper. 
pub fn call_forever(
  actor: Subject(message),
  sending make_request: fn(Effect(reply)) -> message,
) -> reply {
  process.call_forever(actor, fn(reply_to) {
    make_request(drift.new_effect(process.send(reply_to, _)))
  })
}

/// Similar to `process.call`, but dispatches to the stepper.
pub fn call(
  actor: Subject(message),
  waiting timeout: Int,
  sending make_request: fn(Effect(reply)) -> message,
) -> reply {
  process.call(actor, timeout, fn(reply_to) {
    make_request(drift.new_effect(process.send(reply_to, _)))
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
          let old_inputs = state.input_selector
          let new_inputs =
            state.io_driver.get_selector(drift.read_effect_context(effect_ctx))

          let next =
            actor.continue(
              State(..state, input_selector: new_inputs, effect_ctx:),
            )

          use <- bool.guard(new_inputs == old_inputs, next)
          actor.with_selector(
            next,
            new_inputs
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
