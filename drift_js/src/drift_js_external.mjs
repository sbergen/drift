
import { Ok, Error, } from './gleam.mjs'
import {
    Tick,
    HandleInput,
} from './drift/js/internal/event_loop.mjs';

export function now() {
    return Math.round(performance.now());
}

export function init() {
    return new EventLoop();
}

export function receive(loop, handler) {
    return loop.receive(handler);
}

export function send(loop, message) {
    return loop.send(new HandleInput(message));
}

export function set_timeout(loop, after) {
    return loop.setTimeout(after);
}

export class EventLoop {
    #queue = [];
    #handler;
    #timeout;

    receive(handler) {
        if (this.#handler) {
            return new Error(undefined);
        }

        let message;
        if (message = this.#queue.shift()) {
            this.#cancelTimeout();
            this.#dispatch(handler, message);
        } else {
            this.#handler = handler;
        }

        return new Ok(undefined);
    }

    send(message) {
        this.#cancelTimeout();

        if (this.#handler) {
            this.#dispatch(this.#handler, message);
        } else {
            this.#queue.push(message);
        }
    }

    setTimeout(after) {
        if (this.#timeout) {
            return new Error(undefined);
        }

        this.#timeout = setTimeout(() => this.send(new Tick()), after);
        return new Ok(undefined);
    }

    #dispatch(handler, message) {
        this.#handler = null;
        handler(message);
    }

    #cancelTimeout() {
        if (this.#timeout) {
            clearTimeout(this.#timeout);
            this.#timeout = null;
        }
    }
}