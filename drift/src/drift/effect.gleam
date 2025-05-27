//// Manage side effects.

/// Represents a context in which effects may be applied.
/// May hold state (or Nil, if no state is needed).
/// An effect context can only be constructed when starting a stepper,
/// and transformed using `map_effect_context`.
pub opaque type Context(s, i) {
  Context(state: s, inputs: i)
}

/// Constructs a new effect context.
/// This should only be done when starting a stepper,
/// which is why it is internal!
@internal
pub fn new_context(state: a, inputs: i) -> Context(a, i) {
  Context(state, inputs)
}

/// Applies a function to the state of an effect context, returning a new
/// effect context.
pub fn map_context(ctx: Context(a, i), fun: fn(a) -> a) -> Context(a, i) {
  Context(fun(ctx.state), ctx.inputs)
}

/// Returns the inputs of an effect context.
pub fn inputs(ctx: Context(_, i)) -> i {
  ctx.inputs
}

/// Returns true if the inputs of two effect contexts are different.
pub fn inputs_changed(x: Context(a, b), y: Context(a, b)) {
  x.inputs != y.inputs
}

/// Replaces the inputs of an effect context.
pub fn with_inputs(ctx: Context(a, i), new_inputs: i) -> Context(a, i) {
  Context(..ctx, inputs: new_inputs)
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
pub fn from(effect: fn(a) -> Nil) -> Effect(a) {
  Effect(get_id(), effect)
}

/// Binds a value to an effect, to be performed by the impure context.
pub fn bind(effect: Effect(a), arg: a) -> Action(a) {
  Action(effect, arg)
}

/// Performs a side effect that was prepared.
pub fn perform(ctx: Context(s, i), action: Action(_)) -> Context(s, i) {
  action.effect.function(action.argument)
  ctx
}

/// Resets the effect id counter, to get deterministic ids.
/// Should only really be needed for tests.
@external(erlang, "drift_external", "reset_effect_id")
@external(javascript, "../drift_external.mjs", "reset_effect_id")
pub fn reset_id() -> Nil

/// Get the id of an effect. This should only really be needed for tests.
pub fn id(effect: Effect(a)) -> Int {
  effect.id
}

@external(erlang, "drift_external", "get_effect_id")
@external(javascript, "../drift_external.mjs", "get_effect_id")
fn get_id() -> Int
