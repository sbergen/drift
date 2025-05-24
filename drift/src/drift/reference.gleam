/// A target-independent unique reference value,
/// which can be used e.g. as dictionary keys.
/// Useful in the context of drift, as uniqueness of e.g.
/// deferred functions can't be guaranteed.
pub type Reference

/// Create a new reference, which is guaranteed to be unique.
@external(erlang, "erlang", "make_ref")
@external(javascript, "../drift_external.mjs", "make_ref")
pub fn new() -> Reference
