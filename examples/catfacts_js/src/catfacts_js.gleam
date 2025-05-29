import catfacts_js/catfacts
import gleam/io
import gleam/javascript/promise.{type Promise}

pub fn main() -> Promise(Nil) {
  let client = catfacts.new()

  use fact1 <- promise.await(catfacts.fetch(client))
  io.println(fact1)

  use fact2 <- promise.await(catfacts.fetch(client))
  io.println(fact2)

  promise.resolve(Nil)
}
