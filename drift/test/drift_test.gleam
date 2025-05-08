// import birdie
// import drift
// import gleam/list
// import gleam/option.{type Option, None, Some}
// import gleam/string
// import gleeunit

// pub fn main() -> Nil {
//   gleeunit.main()
// }

// type Event {
//   PrintTime
// }

// type Input {
//   Append(String)
//   Yank
//   PrintMe
//   Stop
// }

// type Output {
//   Print(String)
// }

// type Step =
//   drift.Step(List(String), Event, Output, Nil)

// type Next =
//   drift.Next(List(String), Event, Output, Nil)

// pub fn example_use_test() {
//   let assert #(state, Some(10)) =
//     drift.start_with_timers(["Hello, World!"], [drift.Timer(10, PrintTime)])

//   let assert #(state, Some(10), []) =
//     step(state, 0, Append("Wibble!"), apply_input)

//   let assert drift.Continue(#(state, Some(20), [])) =
//     drift.tick(state, 10, apply_event)

//   let assert #(state, Some(20), []) =
//     step(state, 15, Append("Wobble"), apply_input)

//   let assert #(state, Some(20), []) =
//     step(state, 16, Append("Wobble"), apply_input)

//   let assert #(state, Some(20), []) = step(state, 17, Yank, apply_input)

//   let assert drift.Continue(#(state, Some(30), [])) =
//     drift.tick(state, 20, apply_event)

//   let assert #(state, Some(30), [drift.Output(Print(log))]) =
//     step(state, 25, PrintMe, apply_input)

//   let assert #(_state, None, []) = step(state, 25, Stop, apply_input)

//   birdie.snap(log, "Demonstrate some basic usage")
// }

// // Using non-Next version for now
// fn step(
//   state: drift.Stepper(s, i),
//   now: drift.Timestamp,
//   input: i,
//   apply: fn(Step, drift.Timestamp, i) -> Step,
// ) -> #(drift.Stepper(s, i), Option(drift.Timestamp), List(drift.Effect(o))) {
//   state
//   |> drift.begin_step()
//   |> apply(now, input)
//   |> drift.end_step()
// }

// fn apply_input(step: Step, now: drift.Timestamp, input: Input) -> Step {
//   case input {
//     Append(message) -> {
//       use lines <- drift.map_state(step)
//       [string.inspect(now) <> ": " <> message, ..lines]
//     }

//     PrintMe -> {
//       let lines = drift.read_state(step)
//       drift.output(
//         step,
//         Print(
//           lines
//           |> list.reverse
//           |> string.join("\n"),
//         ),
//       )
//     }

//     Yank -> drift.map_state(step, list.drop(_, 1))
//     Stop -> drift.cancel_all_timers(step)
//   }
// }

// fn apply_event(step: Step, now: drift.Timestamp, event: Event) -> Next {
//   case event {
//     PrintTime -> {
//       let new_line = "It's now: " <> string.inspect(now)
//       step
//       |> drift.map_state(list.prepend(_, new_line))
//       |> drift.start_timer(drift.Timer(now + 10, PrintTime))
//       |> drift.Continue
//     }
//   }
// }
