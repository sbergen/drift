import gleam/io
import gleam/javascript/promise.{type Promise}

pub fn main() {
  use input <- promise.await(read_line())
  let assert Ok(input) = input
  io.println(input)
  promise.resolve(Nil)
}

fn read_line() -> Promise(Result(String, Nil)) {
  promise.new(read_line_async)
}

@external(javascript, "./drift_js_example.mjs", "read_line")
fn read_line_async(callback: fn(Result(String, Nil)) -> Nil) -> Nil
