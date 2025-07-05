import { Ok, Error, } from './gleam.mjs'
import {
    Tick,
    HandleInput,
    Stopped,
    AlreadyReceiving,
    AlreadyTicking,
} from './drift/js/internal/event_loop.mjs';
import { Channel } from './drift_channel.mjs';

const Nil = undefined;

export function now() {
    return Math.round(performance.now());
}

export function start() {
    return new EventLoop();
}

export function stop(loop) {
    loop.stop();
}

export function register_stop_callback(loop, callback) {
    loop.register_stop_callback(callback);
}

export function unregister_stop_callback(loop, callback) {
    loop.unregister_stop_callback(callback);
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

class EventLoop {
    #channel = new Channel();
    #timeout;
    #stopped = false;
    #stop_callbacks = new Set();

    stop() {
        if (this.#stopped) {
            return;
        }

        this.#stopped = true;
        this.#channel = null;

        this.#cancelTimeout();

        for (const callback of this.#stop_callbacks) {
            callback();
        }

        this.#stop_callbacks = null;
    }

    register_stop_callback(callback) {
        if (this.#stopped) {
            callback();
        } else {
            this.#stop_callbacks.add(callback);
        }
    }

    unregister_stop_callback(callback) {
        if (!this.#stopped) {
            this.#stop_callbacks.delete(callback);
        }
    }

    receive(handler) {
        if (this.#stopped) {
            return new Error(new Stopped());
        }

        let result = this.#channel.receive(handler);
        if (result === undefined) {
            return new Error(new AlreadyReceiving());
        } else if (result) {
            this.#cancelTimeout();
        }

        return new Ok(Nil);
    }

    send(message) {
        if (this.#stopped) {
            return;
        }

        this.#cancelTimeout();
        this.#channel.send(message);
    }

    setTimeout(after) {
        if (this.#stopped) {
            return new Error(new Stopped());
        }

        if (this.#timeout) {
            return new Error(new AlreadyTicking());
        }

        this.#timeout = setTimeout(() => this.send(new Tick()), after);
        return new Ok(Nil);
    }

    #cancelTimeout() {
        if (this.#timeout) {
            clearTimeout(this.#timeout);
            this.#timeout = null;
        }
    }
}