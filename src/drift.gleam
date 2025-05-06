//// `drift` is a library for creating highly asynchronous "functional cores",
//// which can be wrapped with different I/O and timer implementations,
//// depending on the environment they are running in.
//// The idea is that a stepper, which holds state and timers, can be updated
//// in steps, producing a new stepper, the next timer due time, and a list of
//// outputs. 
//// `drift` provides a bunch of data types and functions to make handling
//// this easier.
//// 
//// The core type is `Stepper(state, timer)`. It holds the current state and
//// active timers. The state within the stepper can be updated by using the
//// `Step(state, timer, output)` type in the following ways:
//// 1. `being_step` can be used to create a `Step`, and `end_step` to complete
////    it, yielding the final result.
//// 2. `tick` takes the current timestamp and a function to apply timer data to
////    a `Step`, and runs all expired timers.
//// 3. `step` is provided for convenience, and takes a function to apply an
////    input to a stepper.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// A monotonically increasing timestamp (we don't care about the unit).
pub type Timestamp =
  Int

/// A timer that wil expire when the timestamp increases to the due time.
/// Each timer holds arbitrary data, which the creator of the timer should
/// associate to an operation to execute.
/// If the timer is to be canceled, the creator of the timer needs to ensure
/// that the data is detailed enough to be identified uniquely.
pub type Timer(t) {
  Timer(due_time: Timestamp, data: t)
}

/// Holds the current state and active timers.
pub opaque type Stepper(state, timer) {
  Stepper(state: state, timers: List(Timer(timer)))
}

/// An ongoing stepper update, which may update the state, timers,
/// or produce outputs.
pub opaque type Step(state, timer, output) {
  Step(state: state, timers: List(Timer(timer)), outputs: List(output))
}

/// Create a new stepper with the initial state and timers.
pub fn start(
  state: s,
  timers: List(Timer(t)),
) -> #(Stepper(s, t), Option(Timestamp)) {
  #(Stepper(state, timers), next_tick(timers))
}

/// Updates the state within a step by applying a function to the current state.
pub fn map_state(step: Step(s, t, o), f: fn(s) -> s) -> Step(s, t, o) {
  Step(..step, state: f(step.state))
}

/// Replaces the state within a step.
pub fn replace_state(step: Step(s, t, o), state: s) -> Step(s, t, o) {
  Step(..step, state:)
}

/// Extracts the state from a step.
pub fn read_state(step: Step(s, t, o)) -> s {
  step.state
}

/// Starts a timer within a step.
pub fn start_timer(step: Step(s, t, o), timer: Timer(t)) -> Step(s, t, o) {
  Step(..step, timers: [timer, ..step.timers])
}

/// Cancels timers matching the given predicate within a step.
pub fn cancel_timers(
  step: Step(s, t, o),
  predicate: fn(Timer(t)) -> Bool,
) -> Step(s, t, o) {
  Step(
    ..step,
    timers: list.filter(step.timers, fn(timer) { !predicate(timer) }),
  )
}

/// Cancels all timers within a step.
pub fn cancel_all_timers(step: Step(s, t, o)) -> Step(s, t, o) {
  Step(..step, timers: [])
}

/// Adds an output within a step.
pub fn output(step: Step(s, t, o), output: o) -> Step(s, t, o) {
  Step(..step, outputs: [output, ..step.outputs])
}

/// Adds multiple outputs within a step.
pub fn output_many(step: Step(s, t, o), outputs: List(o)) -> Step(s, t, o) {
  // TODO: check the list operations below
  Step(..step, outputs: list.append(list.reverse(outputs), step.outputs))
}

/// Adds an output derived from the state within a step.
pub fn map_output(step: Step(s, t, o), make_output: fn(s) -> o) -> Step(s, t, o) {
  Step(..step, outputs: [make_output(step.state), ..step.outputs])
}

/// Triggers all expired timers.
/// Returns the new stepper, next tick due time, if any,
/// and the list of outputs to apply.
pub fn tick(
  state: Stepper(s, t),
  now: Timestamp,
  apply: fn(Step(s, t, o), Timestamp, t) -> Step(s, t, o),
) -> #(Stepper(s, t), Option(Timestamp), List(o)) {
  let Stepper(state, timers) = state
  let #(to_trigger, timers) =
    list.partition(timers, fn(timer) { timer.due_time <= now })

  let Step(state, timers, outputs) =
    to_trigger
    |> list.sort(fn(a, b) { int.compare(a.due_time, b.due_time) })
    |> list.fold(Step(state, timers, []), fn(transaction, timer) {
      apply(transaction, now, timer.data)
    })

  #(Stepper(state, timers), next_tick(timers), list.reverse(outputs))
}

/// Starts a new step to alter the state
pub fn begin_step(state: Stepper(s, t)) -> Step(s, t, _) {
  Step(state.state, state.timers, [])
}

/// Ends the current step.
/// Returns the new stepper, next tick due time, if any,
/// and the list of outputs to apply.
pub fn end_step(
  step: Step(s, t, o),
) -> #(Stepper(s, t), Option(Timestamp), List(o)) {
  let Step(state, timers, outputs) = step
  #(Stepper(state, timers), next_tick(timers), list.reverse(outputs))
}

/// Convenience function for running a step with a single function
/// taking the state, current time and input.
pub fn step(
  state: Stepper(s, t),
  now: Timestamp,
  input: i,
  apply: fn(Step(s, t, o), Timestamp, i) -> Step(s, t, o),
) -> #(Stepper(s, t), Option(Timestamp), List(o)) {
  state
  |> begin_step()
  |> apply(now, input)
  |> end_step
}

/// Convenience function to wrap the state within a tuple
/// returned by `end_step` or `step`.
/// Useful when hiding the use of `drift` from outside code.
pub fn wrap_state(
  result: #(Stepper(s, t), Option(Timestamp), List(o)),
  wrap: fn(Stepper(s, t)) -> a,
) -> #(a, Option(Timestamp), List(o)) {
  #(wrap(result.0), result.1, result.2)
}

/// Gets the next timer due time or `None` if there are no active timers.
fn next_tick(timers: List(Timer(_))) -> Option(Timestamp) {
  case timers {
    [] -> None
    [timer, ..rest] ->
      Some(
        list.fold(rest, timer.due_time, fn(min, timer) {
          int.min(min, timer.due_time)
        }),
      )
  }
}
