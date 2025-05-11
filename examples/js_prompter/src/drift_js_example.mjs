import fs from "node:fs";
import { Buffer } from "node:buffer"
import { Ok, Error as GError } from "./gleam.mjs";

/**
 * Adapted from https://github.com/bcpeinhardt/input/blob/main/src/input_ffi.mjs
 */
export function read_line(callback) {
    try {
        // 4096 bytes is the limit for cli input in bash.
        const buffer = Buffer.alloc(4096);
        fs.read(0, buffer, (err, bytesRead, buffer) => {
            if (err) {
                callback(new GError(undefined))
            } else {
                let input = buffer.toString('utf-8', 0, bytesRead);

                // Trim trailing newlines
                input = input.replace(/[\r\n]+$/, '');
                callback(new Ok(input));
            }
        });
    } catch {
        callback(new GError(undefined));
    }
}