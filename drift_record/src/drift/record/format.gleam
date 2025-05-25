//// Stateful formatting utilities for recorded inputs/outputs

import gleam/list

/// A stateful formatter for a given type of value.
pub opaque type Formatter(s, a) {
  Formatter(state: s, format: fn(s, a) -> #(s, String))
}

/// Constructs a stateful formatter
pub fn stateful(state: s, format: fn(s, a) -> #(s, String)) -> Formatter(s, a) {
  Formatter(state, format)
}

/// Constructs a stateless formatter
pub fn stateless(format: fn(a) -> String) -> Formatter(Nil, a) {
  use _, val <- Formatter(Nil)
  #(Nil, format(val))
}

/// Formats the given value, and returns the new state of the formatter
/// and the input formatted as a string.
pub fn value(formatter: Formatter(s, a), value: a) -> #(Formatter(s, a), String) {
  let #(state, str) = formatter.format(formatter.state, value)
  #(Formatter(..formatter, state:), str)
}

/// Formats a list of values, and returns the new state of the formatter
/// and each input value formatted as a string.
pub fn list(
  formatter: Formatter(s, a),
  values: List(a),
) -> #(Formatter(s, a), List(String)) {
  list.map_fold(values, formatter, value)
}

/// Utility function for nicer syntax when running a single formatting function.
/// Works nice together with `use`:
/// ```gleam
/// use effect <- format.map(effect.inspect(formatter, effect))
/// "My effect: " <> effect
/// ```
/// is equivalent to
/// ```gleam
/// let #(formatter, effect) = effect.inspect(formatter, effect)
/// #(formatter, "My effect: " <> effect)
/// 
/// ```
pub fn map(result: #(s, String), mapper: fn(String) -> String) -> #(s, String) {
  let #(state, str) = result
  #(state, mapper(str))
}
