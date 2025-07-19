//// Define pure functional cores, which can be wrapped to handle side effects.
//// The state of the core is represented with a `Stepper`, which for each step,
//// handles an input and produces a new state and outputs.

import drift/internal/id
import drift/internal/timer
import gleam/list
import gleam/option.{type Option, None, Some}

/// A monotonically increasing timestamp, in milliseconds.
pub type Timestamp =
  Int

/// A handle to a timer. Can be used to cancel the timer.
pub type Timer =
  timer.Timer

/// The result of canceling a timer
pub type Cancelled {
  TimerNotFound
  Cancelled(time_remaining: Int)
}

/// Represents the context in which a state is being manipulated within a step.
/// Can be used to add side effects while executing a step.
pub opaque type Context(input, output) {
  Context(
    start_time: Timestamp,
    timers: timer.Timers(input),
    outputs: List(output),
  )
}

/// Gets the current timestamp from the context.
/// The timestamp is always the start time of the step
/// (time does not advance during a step, in order to keep things pure).
pub fn now(context: Context(_, _)) -> Timestamp {
  context.start_time
}

/// Returns a new context with a timer added to handle an input after a delay.
pub fn start_timer(
  context: Context(i, o),
  delay: Int,
  input: i,
) -> #(Context(i, o), Timer) {
  let #(timers, timer) =
    timer.add(context.timers, context.start_time + delay, input)
  #(Context(..context, timers:), timer)
}

/// Returns a new context with the given timer canceled.
pub fn cancel_timer(
  context: Context(i, o),
  to_cancel: Timer,
) -> #(Context(i, o), Cancelled) {
  let #(timers, cancelled) =
    timer.cancel(context.timers, context.start_time, to_cancel)

  #(Context(..context, timers:), case cancelled {
    None -> TimerNotFound
    Some(time_remaining) -> Cancelled(time_remaining)
  })
}

/// Returns a new context with all timers canceled.
pub fn cancel_all_timers(context: Context(i, o)) -> Context(i, o) {
  Context(..context, timers: timer.cancel_all(context.timers))
}

/// Returns a new context with the given output added.
pub fn output(context: Context(i, o), output: o) -> Context(i, o) {
  Context(..context, outputs: [output, ..context.outputs])
}

/// Returns a new context with the given outputs added.
pub fn output_many(context: Context(i, o), outputs: List(o)) -> Context(i, o) {
  list.fold(outputs, context, output)
}

/// Returns a new context with the given output added, if it was `Some`
pub fn output_option(
  context: Context(i, o),
  optional_output: Option(o),
) -> Context(i, o) {
  case optional_output {
    None -> context
    Some(value) -> output(context, value)
  }
}

/// A shorthand for outputting effects to be performed.
/// Example:
/// ```
/// context
///  |> drift.perform(SomeOutput, effect, state)
///  |> drift.continue(state)
/// ```
pub fn perform(
  context: Context(i, o),
  make_output: fn(Action(a)) -> o,
  effect: Effect(a),
  arg: a,
) -> Context(i, o) {
  output(context, make_output(bind_effect(effect, arg)))
}

/// An ongoing stepper update, which may update the state, timers,
/// or produce outputs.
/// Once a step is terminated (with or without error),
/// it can no longer be continued.
pub opaque type Step(state, input, output, error) {
  ContinueStep(context: Context(input, output), state: state)
  StopStep(outputs: List(output), state: state)
  StopStepWithError(outputs: List(output), error: error)
}

/// If a step hasn't terminated, extracts the context and state from the step,
/// and returns a new step from the given function.
pub fn chain(
  step: Step(s, i, o, e),
  f: fn(Context(i, o), s) -> Step(s, i, o, e),
) -> Step(s, i, o, e) {
  case step {
    ContinueStep(context, state) -> f(context, state)
    _ -> step
  }
}

/// Ends the current step, signalling to continue running the stepper.
/// All effects in the context should be applied by the wrapping runtime.
pub fn continue(context: Context(i, o), state: s) -> Step(s, i, o, e) {
  ContinueStep(context, state)
}

/// Terminates the stepper with the final state without error.
/// All effects in the context should still be applied by the wrapping runtime.
pub fn stop(context: Context(i, o), state: s) -> Step(s, i, o, _) {
  StopStep(context.outputs, state)
}

/// Terminates the stepper with an error.
/// All effects in the context should still be applied by the wrapping runtime.
pub fn stop_with_error(context: Context(i, o), error: e) -> Step(_, i, o, e) {
  StopStepWithError(context.outputs, error)
}

/// Represents a continuation in the purely functional context,
/// which will be called with a new context and state when resumed.
/// Allows handing external inputs of one type in a generic way in multiple
/// different use cases.
pub opaque type Continuation(a, state, input, output, error) {
  Continuation(
    id: Int,
    function: fn(Context(input, output), state, a) ->
      Step(state, input, output, error),
  )
}

/// Completes the current step with the given state, and adds the output
/// constructed by `make_output`. `continuation` will be executed with the new
/// context and state when it is resumed.
/// Designed to be used with `use`, e.g.
/// ```
/// use context, state, response <- drift.await(context, state, SomeOutput)
/// ```
pub fn await(
  context: Context(i, o),
  state: s,
  make_output: fn(Continuation(a, s, i, o, e)) -> o,
  continuation: fn(Context(i, o), s, a) -> Step(s, i, o, e),
) -> Step(s, i, o, e) {
  context
  |> output(make_output(Continuation(id.get(), continuation)))
  |> continue(state)
}

/// Resumes execution of a continuation.
pub fn resume(
  context: Context(i, o),
  state: s,
  continuation: Continuation(a, s, i, o, e),
  result: a,
) -> Step(s, i, o, e) {
  continuation.function(context, state, result)
}

/// Gets the id of the continuation. Should only really be needed for tests.
pub fn continuation_id(continuation: Continuation(_, _, _, _, _)) -> Int {
  continuation.id
}

/// Holds the current state and active timers.
pub opaque type Stepper(state, input) {
  Stepper(state: state, timers: timer.Timers(input))
}

/// Creates a new stepper with the given state for the pure and effectful parts.
pub fn new(state: s, io_state: io) -> #(Stepper(s, i), EffectContext(io)) {
  #(Stepper(state, timer.new()), EffectContext(io_state))
}

/// Represents the next state of a stepper,
/// after applying one or more steps.
pub type Next(state, input, output, error) {
  /// Execution of the stepper should continue,
  /// effects should be applied, and if `due_time` is `Some`,
  /// `tick` should be called at that time.
  Continue(
    outputs: List(output),
    state: Stepper(state, input),
    due_time: Option(Timestamp),
  )

  /// Execution of the stepper should stop with the final effects applied.
  /// The terminal state is also included.
  Stop(outputs: List(output), state: state)

  /// Execution of the stepper should stop with the final effects applied.
  /// The given error should be applied in the executing context
  StopWithError(outputs: List(output), error: error)
}

/// Triggers all expired timers, and returns the next state of the stepper.
pub fn tick(
  stepper: Stepper(s, i),
  now: Timestamp,
  apply: fn(Context(i, o), s, i) -> Step(s, i, o, e),
) -> Next(s, i, o, e) {
  let Stepper(state, timers) = stepper
  let #(timers, to_trigger) = timer.expired(timers, now)

  list.fold(
    to_trigger,
    ContinueStep(Context(now, timers, []), state),
    fn(next, input) {
      case next {
        ContinueStep(context, state) -> apply(context, state, input)
        other -> other
      }
    },
  )
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
  Context(now, stepper.timers, [])
  |> apply(stepper.state, input)
  |> end_step()
}

/// Ends the current step, yielding the next state.
fn end_step(step: Step(s, i, o, e)) -> Next(s, i, o, e) {
  case step {
    ContinueStep(Context(_, timers, effects), state) ->
      Continue(
        list.reverse(effects),
        Stepper(state, timers),
        timer.next_tick(timers),
      )

    StopStepWithError(effects, error) ->
      StopWithError(list.reverse(effects), error)

    StopStep(effects, state) -> Stop(list.reverse(effects), state)
  }
}

/// Represents a context in which effects may be applied.
/// May hold state (or Nil, if no state is needed).
/// An effect context can only be constructed when starting a stepper,
/// and transformed using `use_effect_context`.
pub opaque type EffectContext(s) {
  EffectContext(state: s)
}

/// Applies a function to the state of an effect context, returning a new
/// effect context.
pub fn use_effect_context(
  ctx: EffectContext(a),
  fun: fn(a) -> a,
) -> EffectContext(a) {
  EffectContext(fun(ctx.state))
}

/// Reads the state of an effect context.
pub fn read_effect_context(ctx: EffectContext(a)) -> a {
  ctx.state
}

/// Represents a side effect to be applied with a yet unknown value.
/// Side effects may be applied multiple times.
pub opaque type Effect(a) {
  Effect(id: Int, function: fn(a) -> Nil)
}

/// Represents a side effect to be performed once with a specific value.
/// Can only be run outside of the pure context.
pub type Action(a) {
  Action(effect: Effect(a), argument: a)
}

/// Constructs an effect from a function to be called with a value produced later.
/// Each `Effect` created is unique, even if they use the same function.
/// This serves two purposes:
/// 1) Since the same side effect might be expected to be performed a specific
///    number of times from different contexts, treating each created effect
///    as unique allows discriminating between them based on equality comparison.
/// 2) Having a distinct id allows writing nice snapshot tests, where
///    effects can be identified in the output.
pub fn new_effect(effect: fn(a) -> Nil) -> Effect(a) {
  Effect(id.get(), effect)
}

/// Binds a value to an effect, to be performed by the impure context.
pub fn bind_effect(effect: Effect(a), arg: a) -> Action(a) {
  Action(effect, arg)
}

/// Performs a side effect that was prepared.
pub fn perform_effect(
  ctx: EffectContext(s),
  action: Action(_),
) -> EffectContext(s) {
  action.effect.function(action.argument)
  ctx
}

/// Get the id of an effect. This should only really be needed for tests.
pub fn effect_id(effect: Effect(a)) -> Int {
  effect.id
}

/// Resets the id counter used for effects and continuations,
/// to get deterministic ids.
/// Should only really be needed for tests.
pub fn reset_ids() -> Nil {
  id.reset()
}
