-module(drift_external).

-on_load init/0.

-export([get_id/0, reset_id/0]).

init() ->
    Id = atomics:new(1, [{signed, false}]),
    persistent_term:put(?MODULE, Id),
    ok.

get_id() ->
    Id = persistent_term:get(?MODULE),
    atomics:add_get(Id, 1, 1).

reset_id() ->
    Id = persistent_term:get(?MODULE),
    atomics:put(Id, 1, 0).
