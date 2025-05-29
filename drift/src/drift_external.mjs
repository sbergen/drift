let id = 0;

export function get_id() {
    return ++id;
}

export function reset_id() {
    id = 0;
}