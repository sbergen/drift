# drift

`drift` is a Gleam library for creating highly asynchronous pure functional cores,
which can be wrapped with different I/O and timer implementations.
These cores can be used on both the Erlang and JavaScript targets.
Side effects are tracked by producing outputs on every step,
and executing the side effects is left to be done by a wrapping runtime.

This repository contains the following packages:
* [`drift`](drift) contains the core utilities for writing pure functional logic.
* [`drift_actor`](drift_actor) can wrap a core written with drift in an OTP actor.
* [`drift_js`](drift_js) can wrap a core written with drift in an event loop on the JS target.
* [`drift_record`](drift_record) contains utilities to record the inputs and 
  outputs of a drift core in a snapshot-testing friendly manner.

The [examples](examples) directory contains a simple drift core that can fetch
cat facts, and wrappers for both the Erlang and JavaScript targets.
