import drift.{type Context, type Step}
import gleam/javascript/promise.{type Promise}

pub opaque type IoDriver(state, input, output, error) {
  IoDriver(
    state: state,
    input: Promise(input),
    handle_output: fn(state, output) -> Result(#(state, Promise(input)), error),
  )
}

pub fn using_io(
  state: state,
  initial_input: Promise(input),
  handle_output: fn(state, output) -> Result(#(state, Promise(input)), error),
) -> IoDriver(state, input, output, error) {
  IoDriver(state, initial_input, handle_output)
}

pub fn run(
  io: IoDriver(io, input, output, error),
  state: s,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> #(Promise(Result(Nil, e)), fn(input) -> Nil) {
  todo
}

pub fn never() -> Promise(a) {
  promise.start().0
}

type Input(i) {
  Tick
  Input(i)
}

type State {
  State
}

fn loop(
  io: IoDriver(io, input, output, error),
  input: Promise(Input(input)),
  state: s,
  handle_input: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) {
  use input <- promise.await(io.input)
  //drift.step()
  todo
}
