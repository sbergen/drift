import drift
import drift/internal/id
import gleeunit/should

pub fn map_context_test() {
  let #(_, ctx) = drift.new(Nil, 2)

  let updated =
    ctx
    |> drift.use_effect_context(fn(ctx) { 2 * ctx })
    |> drift.read_effect_context

  assert updated == 4
}

pub fn new_bind_apply_test() {
  // Create a dummy context
  let #(_, ctx) = drift.new(Nil, Nil)

  // Abuse id as mutable state,
  // increment it a few times to be clearer
  id.get()
  id.get()

  let e =
    drift.new_effect(fn(x) {
      id.reset()
      let _ = case x {
        42 -> 0
        _ -> id.get()
      }
      Nil
    })

  let action = drift.bind_effect(e, 42)
  drift.perform_effect(ctx, action)

  // We should have a cleanly reset id, which is not incremented by the effect
  id.get() |> should.equal(1)
}

pub fn effect_uniqueness_test() {
  let effect_a = drift.new_effect(test_fn)
  let effect_b = drift.new_effect(test_fn)
  let effect_c = drift.new_effect(test_fn)

  let also_effect_a = effect_a

  assert effect_a == also_effect_a
  assert effect_a != effect_b
  assert effect_a != effect_c
  assert effect_b != effect_c
}

pub fn effect_id_test() {
  id.reset()
  let effect_a = drift.new_effect(test_fn)
  let effect_b = drift.new_effect(test_fn)

  drift.effect_id(effect_a) |> should.equal(1)
  drift.effect_id(effect_b) |> should.equal(2)

  id.reset()
  let effect_c = drift.new_effect(test_fn)
  drift.effect_id(effect_c) |> should.equal(1)
}

fn test_fn(_: Nil) -> Nil {
  Nil
}
