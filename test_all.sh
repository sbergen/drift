#!/usr/bin/env bash
cd "$(dirname "$0")"

set -e

for dirname in "drift" "drift_actor" "drift_js" "drift_record" "examples/catfacts" "examples/catfacts_erlang" "examples/catfacts_js"; do
    pushd "$dirname" > /dev/null
    echo "======================================="
    echo " Testing $dirname"
    echo "======================================="
    gleam test
    popd > /dev/null
done
