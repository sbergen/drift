import gleam/erlang/process

pub fn wait_for_process(pid: process.Pid) -> Nil {
  case process.is_alive(pid) {
    False -> Nil
    True -> {
      process.sleep(10)
      wait_for_process(pid)
    }
  }
}
