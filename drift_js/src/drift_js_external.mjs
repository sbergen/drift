
import { Ok, Error, } from './gleam.mjs'
import {
    Tick,
    HandleInput,
    Stopped,
    AlreadyReceiving,
    AlreadyTicking,
} from './drift/js/internal/event_loop.mjs';

export function now() {
    return Math.round(performance.now());
}

export function start() {
    return new EventLoop();
}

export function stop(loop) {
    loop.stop();
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
    #stopped = false;

    stop() {
        this.#stopped = true;
        this.#queue = null;
    }

    receive(handler) {
        if (this.#stopped) {
            return new Error(new Stopped());
        }

        if (this.#handler) {
            return new Error(new AlreadyReceiving());
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
        if (this.#stopped) {
            return new Error(new Stopped());
        }

        this.#cancelTimeout();

        if (this.#handler) {
            this.#dispatch(this.#handler, message);
        } else {
            this.#queue.push(message);
        }

        return new Ok(undefined);
    }

    setTimeout(after) {
        if (this.#stopped) {
            return new Error(new Stopped());
        }

        if (this.#timeout) {
            return new Error(new AlreadyTicking());
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