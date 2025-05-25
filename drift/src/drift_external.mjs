let effect_id = 0;

export function get_effect_id() {
    return ++effect_id;
}

export function reset_effect_id() {
    effect_id = 0;
}