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

# drift_actor

`drift_actor` includes an wrappers to run a `drift` stepper inside an OTP actor.
