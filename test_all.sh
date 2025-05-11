#!/usr/bin/env bash
cd "$(dirname "$0")"

set -e

for dirname in "drift" "drift_actor" "drift_js" "examples/prompter" "examples/erlang_prompter"; do
    pushd "$dirname" > /dev/null
    echo "======================================="
    echo " Testing $dirname"
    echo "======================================="
    gleam test
    popd > /dev/null
done
