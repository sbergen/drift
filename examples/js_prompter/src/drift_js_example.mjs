export function read_stdin(callback) {
    let handler = data => callback(data.toString());
    process.stdin.on("data", handler);
    return () => process.stdin.off("data", handler);
}

export function pause_io() {
    process.stdin.pause();
    process.stdout.pause();
}