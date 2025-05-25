//// Manage side effects.

/// Represents a context in which effects may be applied.
/// May hold state (or Nil, if no state is needed).
/// An effect context can only be constructed when starting a stepper,
/// and transformed using `map_effect_context`.
pub opaque type Context(a) {
  Context(state: a)
}

/// Represents a side effect to be applied with a yet unknown value.
/// Side effects may be applied multiple times.
pub opaque type Effect(a) {
  Effect(effect: fn(a) -> Nil)
}

/// Represents a side effect to be performed once with a specific value.
/// Can only be run outside of the pure context.
pub opaque type Action(a) {
  Action(Effect(a), a)
}

/// Constructs an effect from a function to be called with a value produced later.
pub fn from(effect: fn(a) -> Nil) -> Effect(a) {
  Effect(effect)
}

/// Binds a value to an effect, to be performed by the impure context.
pub fn bind(effect: Effect(a), arg: a) -> Action(a) {
  Action(effect, arg)
}

/// Performs a side effect that was prepared.
pub fn perform(ctx: Context(a), action: Action(_)) -> Context(a) {
  let Action(Effect(effect), arg) = action
  effect(arg)
  ctx
}

/// Applies a function to the state of an effect context, returning a new
/// effect context.
pub fn map_context(ctx: Context(a), fun: fn(a) -> b) -> Context(b) {
  Context(fun(ctx.state))
}

/// Constructs a new effect context.
/// This should only be done when starting a stepper,
/// which is why it is internal!
@internal
pub fn new_context(state: a) -> Context(a) {
  Context(state)
}
