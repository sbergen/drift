import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

type TimedInput(i) {
  TimedInput(id: Int, due_time: Int, input: i)
}

pub opaque type Timer {
  Timer(id: Int)
}

pub opaque type Timers(i) {
  Timers(id: Int, timers: List(TimedInput(i)))
}

pub fn new() -> Timers(_) {
  Timers(0, [])
}

pub fn add(timers: Timers(i), due_time: Int, input: i) -> #(Timers(i), Timer) {
  let id = timers.id
  let timer = TimedInput(id, due_time, input)
  #(Timers(id + 1, [timer, ..timers.timers]), Timer(id))
}

pub fn cancel(
  timers: Timers(i),
  now: Int,
  to_cancel: Timer,
) -> #(Timers(i), Option(Int)) {
  let #(new_timers, canceled) = {
    use #(timers, canceled), timer <- list.fold(timers.timers, #([], None))
    case timer.id == to_cancel.id {
      True -> #(timers, Some(timer.due_time - now))
      False -> #([timer, ..timers], canceled)
    }
  }
  #(Timers(..timers, timers: new_timers), canceled)
}

pub fn cancel_all(timers: Timers(i)) -> Timers(i) {
  // Do not reset the id in case timer ids are still held onto!
  Timers(timers.id, [])
}

pub fn expired(timers: Timers(i), now: Int) -> #(Timers(i), List(i)) {
  let #(expired, remaining) =
    list.partition(timers.timers, fn(timer) { timer.due_time <= now })
  let expired =
    expired
    |> list.sort(fn(a, b) { int.compare(a.due_time, b.due_time) })
    |> list.map(fn(i) { i.input })

  #(Timers(timers.id, remaining), expired)
}

/// Gets the next timer due time or `None` if there are no active timers.
pub fn next_tick(timers: Timers(_)) -> Option(Int) {
  case timers.timers {
    [] -> None
    [timer, ..rest] ->
      Some(
        list.fold(rest, timer.due_time, fn(min, timer) {
          int.min(min, timer.due_time)
        }),
      )
  }
}
