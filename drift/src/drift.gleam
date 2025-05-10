//// `drift` is a library for creating highly asynchronous "functional cores",
//// which can be wrapped with different I/O and timer implementations,
//// depending on the environment they are running in.
//// The idea is that a stepper, which holds state and timers, can be updated
//// in steps, producing a new stepper, the next timer due time, and a list of
//// effects to be applied in the context it is running in.
//// `drift` provides a bunch of data types and functions to make handling
//// this easier.
//// Execution of the stepper should stop with the final effects applied.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// A monotonically increasing timestamp in milliseconds.
pub type Timestamp =
  Int

/// A handle to a timer. Can be used to cancel the timer.
pub opaque type Timer {
  Timer(id: Int)
}

/// The result of canceling a timer
pub type Cancelled {
  TimerNotFound
  Cancelled(time_remaining: Int)
}

type TimedInput(i) {
  TimedInput(id: Int, due_time: Timestamp, input: i)
}

type Timers(i) {
  Timers(id: Int, timers: List(TimedInput(i)))
}

/// Represents a deferred future value that can be resolved later.
pub opaque type Deferred(a) {
  Deferred(resolve: fn(a) -> Nil)
}

/// Builds a value that can be used to resolve a deferred value later
/// with the given function.
pub fn defer(resolve: fn(a) -> Nil) -> Deferred(a) {
  Deferred(resolve)
}

/// An effect to be applied to the context outside of the pure core.
pub type Effect(output) {
  /// Applies an output with the outside contexts I/O model.
  Output(output)
  /// Resolves a deferred value by executing the function.
  /// Execution is left to be done by the outside context,
  /// so that the stepping stays purely functional.
  ResolveDeferred(fn() -> Nil)
}

/// Represents the context in which a state is being manipulated within a step.
/// Can be used to add side effects while executing a step.
pub opaque type Context(input, output) {
  Context(
    start_time: Timestamp,
    timers: Timers(input),
    effects: List(Effect(output)),
  )
}

/// Gets the current timestamp from the context.
/// The timestamp is always the start time of the step
/// (time does not advance during a step, in order to keep things pure).
pub fn now(context: Context(_, _)) -> Timestamp {
  context.start_time
}

/// Returns a new context with a timer added to handle an input after a delay.
pub fn handle_after(
  context: Context(i, o),
  delay: Int,
  input: i,
) -> #(Context(i, o), Timer) {
  let timers = context.timers
  let id = timers.id
  let timer = TimedInput(id, context.start_time + delay, input)
  #(
    Context(..context, timers: Timers(id + 1, [timer, ..timers.timers])),
    Timer(id),
  )
}

/// Returns a new context with the given timer canceled.
pub fn cancel_timer(
  context: Context(i, o),
  to_cancel: Timer,
) -> #(Context(i, o), Cancelled) {
  let #(cancelled, new_timers) = {
    use #(canceled, timers), timer <- list.fold(
      context.timers.timers,
      #(TimerNotFound, []),
    )
    case timer.id == to_cancel.id {
      True -> #(Cancelled(timer.due_time - context.start_time), timers)
      False -> #(canceled, [timer, ..timers])
    }
  }

  #(
    Context(..context, timers: Timers(context.timers.id, new_timers)),
    cancelled,
  )
}

/// Returns a new context with all timers canceled.
pub fn cancel_all_timers(context: Context(i, o)) -> Context(i, o) {
  // Do not reset the id in case timer ids are still held onto!
  Context(..context, timers: Timers(context.timers.id, []))
}

/// Returns a new context with the given output added.
pub fn output(context: Context(i, o), output: o) -> Context(i, o) {
  Context(..context, effects: [Output(output), ..context.effects])
}

/// Returns a new context with the given outputs added.
pub fn output_many(context: Context(i, o), outputs: List(o)) -> Context(i, o) {
  list.fold(outputs, context, output)
}

/// Returns a new context which will resolve the deferred value to the given value.
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
/// Once a step is terminated (with or without error),
/// it can no longer be continued.
pub opaque type Step(state, input, output, error) {
  ContinueStep(context: Context(input, output), state: state)
  StopStep(effects: List(Effect(output)), error: Option(error))
}

/// If a step hasn't terminated, extracts the context and state from the step,
/// and returns a new step from the given function.
pub fn continue(
  step: Step(s, i, o, e),
  f: fn(Context(i, o), s) -> Step(s, i, o, e),
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(effects, state) -> f(effects, state)
    _ -> step
  }
}

/// Terminates a step by linking the given state to the context.
/// /// All effects in the context will be applied.
pub fn with_state(context: Context(i, o), state: s) -> Step(s, i, o, e) {
  ContinueStep(context, state)
}

/// Terminates a step without error.
/// All effects in the context will still be applied.
pub fn stop(context: Context(i, o)) -> Step(_, i, o, _) {
  StopStep(context.effects, None)
}

/// Terminates a step with and error.
/// All effects in the context will still be applied.
pub fn stop_with_error(context: Context(i, o), error: e) -> Step(_, i, o, e) {
  StopStep(context.effects, Some(error))
}

/// Holds the current state and active timers.
pub opaque type Stepper(state, input) {
  Stepper(state: state, timers: Timers(input))
}

/// Starts a new stepper with the given state.
pub fn start(state: s) -> Stepper(s, t) {
  Stepper(state, Timers(0, []))
}

/// Represents the next state of a stepper,
/// after applying one or more steps.
pub type Next(state, input, output, error) {
  /// Execution of the stepper should continue,
  /// effects should be applied, and if due_time is `Some`,
  /// `tick` should be called at that time.
  Continue(
    effects: List(Effect(output)),
    state: Stepper(state, input),
    due_time: Option(Timestamp),
  )

  Stop(effects: List(Effect(output)))

  /// Execution of the stepper should stop with the final effects applied.
  /// The given error should be applied in the executing context
  StopWithError(effects: List(Effect(output)), error: error)
}

/// Triggers all expired timers, and returns the next state of the stepper.
pub fn tick(
  stepper: Stepper(s, i),
  now: Timestamp,
  apply: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> Next(s, i, o, e) {
  let Stepper(state, timers) = stepper

  let #(to_trigger, remaining_timers) =
    list.partition(timers.timers, fn(timer) { timer.due_time <= now })
  let timers = Timers(timers.id, remaining_timers)

  to_trigger
  |> list.sort(fn(a, b) { int.compare(a.due_time, b.due_time) })
  |> list.fold(ContinueStep(Context(now, timers, []), state), fn(next, timer) {
    case next {
      ContinueStep(effects, state) -> apply(effects, state, timer.input)
      other -> other
    }
  })
  |> end_step()
}

/// Applies the given input to the stepper, using the provided function.
/// Returns the next state of the stepper.
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

/// Starts a new step
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
fn next_tick(timers: Timers(_)) -> Option(Timestamp) {
  case timers.timers {
    [] -> None
    [timer, ..rest] ->
      Some(
        list.fold(rest, timer.due_time, fn(min, timer) {
          int.min(min, timer.due_time)
        }),
      )
  }
}
