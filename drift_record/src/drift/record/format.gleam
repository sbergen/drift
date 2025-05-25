//// Stateful formatting

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

pub fn map(
  state: s,
  format: fn(s, a) -> #(s, String),
  value: a,
  mapper: fn(String) -> String,
) -> #(s, String) {
  let #(state, str) = format(state, value)
  #(state, mapper(str))
}
