# NOTE!

This is work heavily in progress!

# drift

`drift` is a Gleam library for creating highly asynchronous "functional cores",
which can be wrapped with different I/O and timer implementations,
depending on the environment they are running in.
The idea is that a stepper, which holds state and timers, can be updated
in steps, producing a new stepper, the next timer due time, and a list of
outputs. 
`drift` provides a bunch of data types and functions to make handling
this easier.

The core type is `Stepper(state, timer)`. It holds the current state and
active timers. The state within the stepper can be updated by using the
`Step(state, timer, output)` type in the following ways:
1. `begin_step` can be used to create a `Step`, and `end_step` to complete
   it, yielding the final result.
2. `tick` takes the current timestamp and a function to apply timer data to
   a `Step`, and runs all expired timers.
3. `step` is provided for convenience, and takes a function to apply an
   input to a stepper.

# drift_actor

`drift_actor` includes an wrappers to run a `drift` stepper inside an OTP actor.
