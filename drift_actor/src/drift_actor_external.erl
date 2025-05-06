-module(drift_actor_external).

-export([now/0]).

now() ->
    Time = erlang:monotonic_time(),
    erlang:convert_time_unit(Time, native, millisecond).
