//// Manage side effects.

import drift/reference.{type Reference}
import gleam/dict.{type Dict}
import gleam/result
import gleam/string

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
  Effect(ref: Reference, fun: fn(a) -> Nil)
}

/// Represents a side effect to be performed once with a specific value.
/// Can only be run outside of the pure context.
pub opaque type Action(a) {
  Action(effect: Effect(a), arg: a)
}

/// Constructs an effect from a function to be called with a value produced later.
/// Each `Effect` created is unique, even if they use the same function.
pub fn from(effect: fn(a) -> Nil) -> Effect(a) {
  Effect(reference.new(), effect)
}

/// Binds a value to an effect, to be performed by the impure context.
pub fn bind(effect: Effect(a), arg: a) -> Action(a) {
  Action(effect, arg)
}

/// Performs a side effect that was prepared.
pub fn perform(ctx: Context(a), action: Action(_)) -> Context(a) {
  action.effect.fun(action.arg)
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

/// A formatter for pretty-printing effects and actions (e.g. in tests),
/// by assigning them an auto-incrementing number. 
pub opaque type Formatter {
  Formatter(id: Int, ids: Dict(Reference, Int))
}

/// Constructs a new formatter for keeping track of effects and actions.
pub fn new_formatter() -> Formatter {
  Formatter(0, dict.new())
}

/// Produces a string identifying the given effect by a number.
/// The same number will always be associated with the same instance of the effect.
/// Returns the new formatter state and a string representation of the effect.
pub fn inspect(formatter: Formatter, effect: Effect(a)) -> #(Formatter, String) {
  case dict.get(formatter.ids, effect.ref) {
    Error(_) -> {
      let new_ids = dict.insert(formatter.ids, effect.ref, formatter.id)
      inspect(Formatter(formatter.id + 1, new_ids), effect)
    }
    Ok(id) -> #(formatter, "Effect#" <> string.inspect(id))
  }
}

/// Given that the matching effect has been previously inspected with
/// the formatter, provides a matching string representation of an action.
pub fn inspect_action(
  formatter: Formatter,
  action: Action(a),
  inspect: fn(a) -> String,
) -> Result(String, Nil) {
  use id <- result.map(dict.get(formatter.ids, action.effect.ref))
  "Effect#" <> string.inspect(id) <> "(" <> inspect(action.arg) <> ")"
}

/// Not usually necessary, mostly for testing:
/// Extracts the argument from an action.
pub fn extract_arg(action: Action(a)) -> a {
  action.arg
}
