
import envoy
import gleam/io
import gleam/option.{Some}
import gleam/regexp
import gleam/string
import simplifile

pub fn update_or_check_example_test() {
  let readme_filename = "./README.md"
  let assert Ok(readme) = simplifile.read(readme_filename)
  let assert Ok(example) = simplifile.read("./test/example.gleam")
  let assert Ok(regex) =
    regexp.compile(
      "^```gleam\\n([\\s\\S]*)^```\\n",
      regexp.Options(case_insensitive: False, multi_line: True),
    )
  let assert [match] = regexp.scan(regex, readme)
  let assert [Some(snippet)] = match.submatches

  case snippet == example {
    True -> Nil
    False -> {
      case envoy.get("GITHUB_WORKFLOW") {
        Error(Nil) -> {
          io.println_error("\nUpdating example in README!")
          assert simplifile.write(
              to: readme_filename,
              contents: string.replace(readme, snippet, example),
            )
            == Ok(Nil)
          Nil
        }
        Ok(_) -> panic as "Example in README was out of date!"
      }
    }
  }
}