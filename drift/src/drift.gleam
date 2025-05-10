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

pub opaque type Context(input, output) {
  Context(
    start_time: Timestamp,
    timers: List(Timer(input)),
    effects: List(Effect(output)),
  )
}

pub fn now(context: Context(_, _)) -> Timestamp {
  context.start_time
}

/// Starts a timer within a step.
pub fn handle_after(
  context: Context(i, o),
  delay: Int,
  input: i,
) -> Context(i, o) {
  let timer = Timer(context.start_time + delay, input)
  Context(..context, timers: [timer, ..context.timers])
}

// TODO Cancel by ID instead
/// Returns an updated step with all matching timers canceled.
/// Does nothing if the step is terminated.
pub fn cancel_timers(
  context: Context(i, o),
  predicate: fn(i) -> Bool,
) -> Context(i, o) {
  Context(
    ..context,
    timers: list.filter(context.timers, fn(timer) { !predicate(timer.data) }),
  )
}

pub fn cancel_all_timers(context: Context(i, o)) -> Context(i, o) {
  Context(..context, timers: [])
}

pub fn output(context: Context(i, o), output: o) -> Context(i, o) {
  Context(..context, effects: [Output(output), ..context.effects])
}

pub fn output_many(context: Context(i, o), outputs: List(o)) -> Context(i, o) {
  list.fold(outputs, context, output)
}

pub fn resolve(
  context: Context(i, o),
  deferred: Deferred(a),
  result: a,
) -> Context(i, o) {
  let resolve = fn() { deferred.resolve(result) }
  Context(..context, effects: [ResolveDeferred(resolve), ..context.effects])
}

/// An ongoing stepper update, which may update the state, timers,
/// or produce outputs.
pub opaque type Step(state, input, output, error) {
  ContinueStep(context: Context(input, output), state: state)
  StopStep(effects: List(Effect(output)), error: Option(error))
}

pub fn continue(
  step: Step(s, i, o, e),
  f: fn(Context(i, o), s) -> Step(s, i, o, e),
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects, state) -> f(effects, state)
    _ -> step
  }
}

pub fn with_state(context: Context(i, o), state: s) -> Step(s, i, o, e) {
  ContinueStep(context, state)
}

pub fn stop(context: Context(i, o)) -> Step(_, i, o, _) {
  StopStep(context.effects, None)
}

pub fn stop_with_error(context: Context(i, o), error: e) -> Step(_, i, o, e) {
  StopStep(context.effects, Some(error))
}

/// Holds the current state and active timers.
pub opaque type Stepper(state, input) {
  Stepper(state: state, timers: List(Timer(input)))
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
pub fn tick(
  stepper: Stepper(s, i),
  now: Timestamp,
  apply: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> Next(s, i, o, e) {
  let Stepper(state, timers) = stepper
  let #(to_trigger, timers) =
    list.partition(timers, fn(timer) { timer.due_time <= now })

  to_trigger
  |> list.sort(fn(a, b) { int.compare(a.due_time, b.due_time) })
  |> list.fold(ContinueStep(Context(now, timers, []), state), fn(next, timer) {
    case next {
      ContinueStep(effects, state) -> apply(effects, state, timer.data)
      other -> other
    }
  })
  |> end_step()
}

pub fn step(
  stepper: Stepper(s, i),
  now: Timestamp,
  input: i,
  apply: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> Next(s, i, o, e) {
  stepper
  |> begin_step(now)
  |> continue(fn(context, state) { apply(context, state, input) })
  |> end_step()
}

/// Starts a new step to alter the state
pub fn begin_step(state: Stepper(s, i), now: Timestamp) -> Step(s, i, _, _) {
  let effects = Context(now, state.timers, [])
  ContinueStep(effects, state.state)
}

/// Ends the current step, yielding the next state.
pub fn end_step(step: Step(s, i, o, e)) -> Next(s, i, o, e) {
  case step {
    ContinueStep(Context(_, timers, effects), state) ->
      Continue(list.reverse(effects), Stepper(state, timers), next_tick(timers))

    StopStep(effects, Some(error)) ->
      StopWithError(list.reverse(effects), error)

    StopStep(effects, None) -> Stop(list.reverse(effects))
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
