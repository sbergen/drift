-module(drift_external).

-on_load init/0.

-export([get_effect_id/0, reset_effect_id/0]).

init() ->
    EffectId = atomics:new(1, [{signed, false}]),
    persistent_term:put(?MODULE, EffectId),
    ok.

get_effect_id() ->
    EffectId = persistent_term:get(?MODULE),
    atomics:add_get(EffectId, 1, 1).

reset_effect_id() ->
    EffectId = persistent_term:get(?MODULE),
    atomics:put(EffectId, 1, 0).
