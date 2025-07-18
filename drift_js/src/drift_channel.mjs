import { Ok, Error, } from './gleam.mjs'

const Nil = undefined;

export function new_channel() {
    return new Channel();
}

export function send(channel, value) {
    channel.send(value)
}

export function receive(channel, callback) {
    let result = channel.receive(callback);
    if (result === undefined) {
        return new Error(Nil);
    } else {
        return new Ok(result);
    }
}

export function cancel_receive(channel) {
    channel.cancel_receive()
}

export function try_receive(channel) {
    let result = channel.try_receive();
    if (result.hasValue) {
        return new Ok(result.value);
    } else {
        return new Error(Nil);
    }
}

export class Channel {
    #queue = [];
    #handler;

    /// Returns an undefined if already receiving,
    /// true if a value was already available,
    /// and false if no value was available.
    receive(handler) {
        if (this.#handler) {
            return undefined;
        }

        if (this.#queue.length > 0) {
            let message = this.#queue.shift();
            this.#dispatch(handler, message);
            return true;
        } else {
            this.#handler = handler;
            return false;
        }
    }

    try_receive() {
        if (this.#queue.length > 0) {
            return { hasValue: true, value: this.#queue.shift() };
        } else {
            return { hasValue: false };
        }
    }

    cancel_receive() {
        this.#handler = null;
    }

    send(message) {
        if (this.#handler) {
            this.#dispatch(this.#handler, message);
        } else {
            this.#queue.push(message);
        }
    }

    #dispatch(handler, message) {
        this.#handler = null;
        handler(message);
    }
}