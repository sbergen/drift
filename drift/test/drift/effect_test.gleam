import drift/effect
import drift/internal/id
import gleeunit/should

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
