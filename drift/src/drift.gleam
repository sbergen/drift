//// `drift` is a library for creating highly asynchronous "functional cores",
//// which can be wrapped with different I/O and timer implementations,
//// depending on the environment they are running in.
//// The idea is that a stepper, which holds state and timers, can be updated
//// in steps, producing a new stepper, the next timer due time, and a list of
//// outputs. 
//// `drift` provides a bunch of data types and functions to make handling
//// this easier.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// A monotonically increasing timestamp in milliseconds.
pub type Timestamp =
  Int

/// A timer that wil expire when the timestamp increases to the due time.
/// Each timer holds arbitrary data, which the creator of the timer should
/// associate to an operation to execute.
/// If the timer is to be canceled, the creator of the timer needs to ensure
/// that the data is detailed enough to be identified uniquely.
pub opaque type Timer(t) {
  Timer(due_time: Timestamp, data: t)
}

/// Holds the current state and active timers.
pub opaque type Stepper(state, input) {
  Stepper(state: state, timers: List(Timer(input)))
}

/// Represents a deferred future value that can be resolved later.
pub opaque type Deferred(a) {
  Deferred(resolve: fn(a) -> Nil)
}

pub fn defer(resolve: fn(a) -> Nil) -> Deferred(a) {
  Deferred(resolve)
}

pub type Effect(output) {
  Output(output)
  ResolveDeferred(fn() -> Nil)
}

/// An ongoing stepper update, which may update the state, timers,
/// or produce outputs.
pub opaque type Step(state, input, output, error) {
  ContinueStep(
    effects: List(Effect(output)),
    start_time: Timestamp,
    state: state,
    timers: List(Timer(input)),
  )
  StopStep(
    effects: List(Effect(output)),
    start_time: Timestamp,
    error: Option(error),
  )
}

pub fn start_timestamp(step: Step(_, _, _, _)) -> Timestamp {
  step.start_time
}

/// Continues the step (unless terminated), by returning a new step
/// from the provided function operating on the current state.
pub fn continue(
  step: Step(s, i, o, e),
  f: fn(s) -> Step(s, i, o, e),
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(state:, ..) -> f(state)
    _ -> step
  }
}

/// Returns an updated step by applying a function to the current state within the step.
/// Does nothing if the step is terminated.
pub fn update_state(step: Step(s, i, o, e), f: fn(s) -> s) -> Step(s, i, o, e) {
  case step {
    ContinueStep(state:, ..) as continue ->
      ContinueStep(..continue, state: f(state))
    _ -> step
  }
}

/// Returns an updated step with a replaced state.
/// Does nothing if the step is terminated.
pub fn replace_state(step: Step(s, i, o, e), state: s) -> Step(s, i, o, e) {
  update_state(step, fn(_) { state })
}

/// Starts a timer within a step.
pub fn handle_after(
  step: Step(s, i, o, e),
  delay: Int,
  input: i,
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(timers:, start_time:, ..) as continue -> {
      let timer = Timer(start_time + delay, input)
      ContinueStep(..continue, timers: [timer, ..timers])
    }
    _ -> step
  }
}

/// Returns an updated step with all matching timers canceled.
/// Does nothing if the step is terminated.
pub fn cancel_timers(
  step: Step(s, i, o, e),
  predicate: fn(i) -> Bool,
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(timers:, ..) as continue ->
      ContinueStep(
        ..continue,
        timers: list.filter(timers, fn(timer) { !predicate(timer.data) }),
      )
    _ -> step
  }
}

/// Returns an updated step with all timers canceled.
/// Does nothing if the step is terminated.
pub fn cancel_all_timers(step: Step(s, i, o, e)) -> Step(s, i, o, e) {
  case step {
    ContinueStep(..) as continue -> ContinueStep(..continue, timers: [])
    _ -> step
  }
}

/// Returns an updated step with an added output.
/// Does nothing if the step is terminated.
pub fn output(step: Step(s, i, o, e), output: o) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects:, ..) as continue ->
      ContinueStep(..continue, effects: [Output(output), ..effects])
    _ -> step
  }
}

/// Returns an updated step with multiple added outputs.
/// Does nothing if the step is terminated.
pub fn output_many(step: Step(s, i, o, e), outputs: List(o)) -> Step(s, i, o, e) {
  list.fold(outputs, step, output)
}

/// Returns an updated step with an added output derived from the state.
/// Does nothing if the step is terminated.
pub fn output_from_state(
  step: Step(s, i, o, e),
  make_output: fn(s) -> o,
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(state:, effects:, ..) as continue ->
      ContinueStep(..continue, effects: [Output(make_output(state)), ..effects])
    _ -> step
  }
}

/// Returns an updated state that will eventually resolve the deferred value.
/// Does nothing if the step is terminated.
pub fn resolve(
  step: Step(s, i, o, e),
  deferred: Deferred(a),
  result: a,
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects:, ..) as continue -> {
      let resolve = fn() { deferred.resolve(result) }
      ContinueStep(..continue, effects: [ResolveDeferred(resolve), ..effects])
    }
    _ -> step
  }
}

/// Returns a new step that is stopped, and contains the effects of `step`.
/// If already stopped, the previous error (if any) will not be removed.
pub fn stop(step: Step(s, i, o, e)) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects:, start_time:, ..) ->
      StopStep(effects, start_time, None)
    StopStep(effects, start_time, error) -> StopStep(effects, start_time, error)
  }
}

/// Returns a new step that is stopped, and contains the effects of `step`.
/// If the step is already stopped an contains an error, that error will be kept.
/// If no error is present, the given error will be set.
pub fn stop_with_error(step: Step(s, i, o, e), error: e) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects:, start_time:, ..) ->
      StopStep(effects, start_time, None)
    StopStep(effects, start_time, old_error) ->
      StopStep(effects, start_time, option.or(old_error, Some(error)))
  }
}

pub fn start(state: s) -> Stepper(s, t) {
  Stepper(state, [])
}

pub type Next(state, input, output, error) {
  Continue(
    effects: List(Effect(output)),
    state: Stepper(state, input),
    due_time: Option(Timestamp),
  )
  Stop(effects: List(Effect(output)))
  StopWithError(effects: List(Effect(output)), error: error)
}

/// Triggers all expired timers.
/// Returns the new stepper, next tick due time, if any,
/// and the list of outputs to apply.
pub fn tick(
  state: Stepper(s, i),
  now: Timestamp,
  apply: fn(Step(s, i, o, e), i) -> Step(s, i, o, e),
) -> Next(s, i, o, e) {
  let Stepper(state, timers) = state
  let #(to_trigger, timers) =
    list.partition(timers, fn(timer) { timer.due_time <= now })

  to_trigger
  |> list.sort(fn(a, b) { int.compare(a.due_time, b.due_time) })
  |> list.fold(ContinueStep([], now, state, timers), fn(next, timer) {
    case next {
      ContinueStep(..) -> apply(next, timer.data)
      other -> other
    }
  })
  |> end_step()
}

/// Starts a new step to alter the state
pub fn begin_step(state: Stepper(s, i), now: Timestamp) -> Step(s, i, _, _) {
  ContinueStep([], now, state.state, state.timers)
}

/// Ends the current step, yielding the next state.
pub fn end_step(step: Step(s, i, o, e)) -> Next(s, i, o, e) {
  let effects = list.reverse(step.effects)
  case step {
    ContinueStep(state:, timers:, ..) ->
      Continue(effects, Stepper(state, timers), next_tick(timers))
    StopStep(error:, ..) ->
      case error {
        Some(error) -> StopWithError(effects, error)
        None -> Stop(effects)
      }
  }
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
