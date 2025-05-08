import drift.{
  type Deferred, type Step, type Timestamp, Continue, Stop, StopWithError,
}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result

pub type IoResult(state, input) {
  IoOk(state)
  FatalIoError(Dynamic)
  InputSelectorChanged(state, Selector(input))
}

pub opaque type IoDriver(state, input, output) {
  IoDriver(
    new: fn() -> #(state, Selector(input)),
    handle_output: fn(state, output) -> IoResult(state, input),
  )
}

pub fn without_io() -> IoDriver(Nil, input, output) {
  IoDriver(fn() { #(Nil, process.new_selector()) }, fn(state, _) { IoOk(state) })
}

pub fn using_io(
  new: fn() -> #(state, Selector(input)),
  handle_output: fn(state, output) -> IoResult(state, input),
) -> IoDriver(state, input, output) {
  IoDriver(new, handle_output)
}

pub fn start(
  io_driver: IoDriver(io, i, o),
  timeout: Int,
  state: s,
  handle_input: fn(Step(s, i, o, e), Timestamp, i) -> Step(s, i, o, e),
) -> Result(Subject(i), actor.StartError) {
  actor.new_with_initialiser(timeout, fn(self) {
    let #(io_state, input_selector) = io_driver.new()

    let stepper = drift.start(state)
    let handle_input = fn(s, t, i) { handle_input(s, t, i) }

    let inputs = process.new_subject()
    let base_selector =
      process.new_selector()
      |> process.select_map(inputs, HandleInput)
      |> process.select(self)

    let state =
      State(
        stepper:,
        timer: None,
        io_state:,
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

    Ok(init)
  })
  |> actor.on_message(handle_message)
  |> actor.start()
  |> result.map(fn(init) { init.data })
}

pub fn call_forever(
  subject: Subject(message),
  make_request: fn(Deferred(reply)) -> message,
) -> reply {
  process.call_forever(subject, fn(reply) {
    make_request(drift.defer(process.send(reply, _)))
  })
}

pub fn call(
  subject: Subject(message),
  waiting timeout: Int,
  sending make_request: fn(Deferred(reply)) -> message,
) -> reply {
  process.call(subject, timeout, fn(reply) {
    make_request(drift.defer(process.send(reply, _)))
  })
}

//==== Privates ====//

type Msg(i) {
  Tick
  HandleInput(i)
}

type State(state, io, input, output, error) {
  State(
    stepper: drift.Stepper(state, input),
    timer: Option(process.Timer),
    io_state: io,
    io_driver: IoDriver(io, input, output),
    self: Subject(Msg(input)),
    base_selector: Selector(Msg(input)),
    handle_input: fn(Step(state, input, output, error), Timestamp, input) ->
      Step(state, input, output, error),
  )
}

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

      drift.begin_step(state.stepper)
      |> state.handle_input(now, input)
      |> drift.end_step()
    }
  }

  // Apply effects, no matter if stopped or not
  let io_result =
    list.fold(next.effects, IoOk(state.io_state), fn(io_state, effect) {
      use io_state <- bind_io(io_state)
      case effect {
        drift.Output(output) -> state.io_driver.handle_output(io_state, output)
        drift.ResolveDeferred(resolve) -> {
          resolve()
          IoOk(io_state)
        }
      }
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
        IoOk(io_state) -> actor.continue(State(..state, io_state:))
        InputSelectorChanged(io_state, selector) ->
          actor.with_selector(
            actor.continue(State(..state, io_state:)),
            selector
              |> process.map_selector(HandleInput)
              |> process.merge_selector(state.base_selector),
          )
        FatalIoError(reason) -> actor.Stop(process.Abnormal(reason))
      }
    }

    Stop(_effects) -> actor.stop()

    StopWithError(_effects, reason) ->
      actor.Stop(process.Abnormal(dynamic.from(reason)))
  }
}

// Applies a mapping if not errored, carries over the latest selector
fn bind_io(
  result: IoResult(a, i),
  fun: fn(a) -> IoResult(b, i),
) -> IoResult(b, i) {
  case result {
    IoOk(a) -> fun(a)
    FatalIoError(e) -> FatalIoError(e)
    InputSelectorChanged(a, selector) ->
      case fun(a) {
        IoOk(b) -> InputSelectorChanged(b, selector)
        FatalIoError(e) -> FatalIoError(e)
        InputSelectorChanged(b, s) -> InputSelectorChanged(b, s)
      }
  }
}

@external(erlang, "drift_actor_external", "now")
@internal
pub fn now() -> Int
