import drift/effect
import drift/internal/id
import gleam/string
import gleeunit/should

pub fn map_context_test() {
  // The state is not inspectable on purpose,
  // so use string.inspect to hack around that.
  effect.new_context(2)
  |> effect.map_context(fn(ctx) { 2 * ctx })
  |> string.inspect
  |> string.contains("4")
  |> should.be_true
}

pub fn from_bind_apply_test() {
  // Abuse id as mutable state,
  // increment it a few times to be clearer
  id.get()
  id.get()

  let e =
    effect.from(fn(x) {
      id.reset()
      let _ = case x {
        42 -> 0
        _ -> id.get()
      }
      Nil
    })

  let action = effect.bind(e, 42)
  effect.perform(effect.new_context(Nil), action)

  // We should have a cleanly reset id, which is not incremented by the effect
  id.get() |> should.equal(1)
}

pub fn effect_uniqueness_test() {
  let effect_a = effect.from(test_fn)
  let effect_b = effect.from(test_fn)
  let effect_c = effect.from(test_fn)

  let also_effect_a = effect_a

  { effect_a == effect_a } |> should.be_true()
  { effect_b == effect_b } |> should.be_true()
  { effect_c == effect_c } |> should.be_true()
  { effect_a == also_effect_a } |> should.be_true()

  { effect_a == effect_b } |> should.be_false()
  { effect_a == effect_c } |> should.be_false()
  { effect_b == effect_c } |> should.be_false()
}

pub fn effect_id_test() {
  id.reset()
  let effect_a = effect.from(test_fn)
  let effect_b = effect.from(test_fn)

  effect.id(effect_a) |> should.equal(1)
  effect.id(effect_b) |> should.equal(2)

  id.reset()
  let effect_c = effect.from(test_fn)
  effect.id(effect_c) |> should.equal(1)
}

fn test_fn(_: Nil) -> Nil {
  Nil
}
