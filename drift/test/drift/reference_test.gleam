import drift/reference
import gleeunit/should

pub fn reference_equality_test() {
  let a = reference.new()
  let b = reference.new()
  let c = reference.new()

  { a == a } |> should.be_true()
  { b == b } |> should.be_true()
  { c == c } |> should.be_true()
  { a == b } |> should.be_false()
  { a == c } |> should.be_false()
  { b == c } |> should.be_false()
}
