import drift.{type Step, type Timestamp}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import gleam/otp/actor
import gleam/result

pub opaque type IoDriver(s, i, o) {
  IoDriver(
    init: fn() -> s,
    input_selector: fn(s) -> Selector(i),
    output_handler: fn(s, o) -> Nil,
  )
}

pub fn using_io(
  init: fn() -> io,
  input_selector: fn(io) -> Selector(i),
  output_handler: fn(io, o) -> Nil,
) -> IoDriver(io, i, o) {
  IoDriver(init, input_selector, output_handler)
}

pub fn start(
  driver: IoDriver(io, i, o),
  timeout: Int,
  state: s,
  handle_input: fn(Step(s, t, o), Timestamp, i) -> Step(s, t, o),
  handle_timer: fn(Step(s, t, o), Timestamp, t) -> Step(s, t, o),
) -> Result(Subject(i), actor.StartError) {
  actor.new_with_initialiser(timeout, fn(mailbox) {
    let io_state = driver.init()

    let #(stepper, _) = drift.start(state, [])
    let state =
      State(
        stepper:,
        timer: None,
        io_state:,
        mailbox:,
        handle_output: driver.output_handler,
        handle_input:,
        handle_timer:,
      )

    let inputs = process.new_subject()

    let init =
      actor.initialised(state)
      |> actor.selecting(
        driver.input_selector(io_state)
        |> process.map_selector(HandleInput)
        |> process.select_map(inputs, HandleInput)
        |> process.select(mailbox),
      )
      |> actor.returning(inputs)

    Ok(init)
  })
  |> actor.on_message(handle_message)
  |> actor.start()
  |> result.map(fn(init) { init.data })
}

type Msg(i) {
  Tick
  HandleInput(i)
}

type State(s, io, i, t, o) {
  State(
    stepper: drift.Stepper(s, t),
    timer: Option(process.Timer),
    io_state: io,
    mailbox: Subject(Msg(i)),
    handle_output: fn(io, o) -> Nil,
    handle_input: fn(Step(s, t, o), Timestamp, i) -> Step(s, t, o),
    handle_timer: fn(Step(s, t, o), Timestamp, t) -> Step(s, t, o),
  )
}

fn handle_message(
  state: State(s, io, i, t, o),
  message: Msg(i),
) -> actor.Next(State(s, io, i, t, o), Msg(i)) {
  let now = now()
  let #(stepper, due_time, outputs) = case message {
    Tick -> drift.tick(state.stepper, now, state.handle_timer)
    HandleInput(input) ->
      drift.step(state.stepper, now, input, state.handle_input)
  }

  let timer =
    option.map(due_time, fn(due_time) {
      process.send_after(state.mailbox, int.max(now, due_time - now), Tick)
    })

  list.each(outputs, state.handle_output(state.io_state, _))
  actor.continue(State(..state, stepper:, timer:))
}

@external(erlang, "drift_actor_external", "now")
fn now() -> Int
