//// Manage side effects.

import drift/internal/id

// TODO try merging this back into the main module

/// Represents a context in which effects may be applied.
/// May hold state (or Nil, if no state is needed).
/// An effect context can only be constructed when starting a stepper,
/// and transformed using `map_effect_context`.
pub opaque type Context(s) {
  Context(state: s)
}

/// Constructs a new effect context.
/// This should only be done when starting a stepper,
/// which is why it is internal!
@internal
pub fn new_context(state: a) -> Context(a) {
  Context(state)
}

/// Extracts the state from the context.
/// Library consumers should only use `map_context` instead.
@internal
pub fn get_state(ctx: Context(a)) -> a {
  ctx.state
}

/// Applies a function to the state of an effect context, returning a new
/// effect context.
pub fn map_context(ctx: Context(a), fun: fn(a) -> a) -> Context(a) {
  Context(fun(ctx.state))
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
  Effect(id.get(), effect)
}

/// Binds a value to an effect, to be performed by the impure context.
pub fn bind(effect: Effect(a), arg: a) -> Action(a) {
  Action(effect, arg)
}

/// Performs a side effect that was prepared.
pub fn perform(ctx: Context(s), action: Action(_)) -> Context(s) {
  action.effect.function(action.argument)
  ctx
}

/// Get the id of an effect. This should only really be needed for tests.
pub fn id(effect: Effect(a)) -> Int {
  effect.id
}
