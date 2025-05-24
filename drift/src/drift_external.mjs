let refcount = 0;

class Reference {
    constructor() {
        this.id = refcount++;
    }
}

export function make_ref() {
    return new Reference();
}