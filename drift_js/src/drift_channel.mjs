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

        let message;
        if (message = this.#queue.shift()) {
            this.#dispatch(handler, message);
            return true;
        } else {
            this.#handler = handler;
            return false;
        }
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