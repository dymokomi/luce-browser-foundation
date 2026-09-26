#!/bin/sh
# Type-check every module of luce-browser-foundation with warnings as errors, then run the unit
# tests of every module and of the tests package. Stops at the first failing step.
set -e
cd "$(dirname "$0")"

check() {
    echo "== luce-base check $1 -W"
    # -W reports warnings without failing, so any output at all fails the run.
    output=$(luce-base check "$1" -W 2>&1) || { echo "$output"; exit 1; }
    if [ -n "$output" ]; then
        echo "$output"
        exit 1
    fi
}

for module in ak gc web_unicode text_codec web_url web_infra; do
    check "src/luce_browser_foundation/$module"
done
check tests/text_codec_tests

# Unit tests (ported from Tests/AK, Tests/LibWeb and focused cases), module by module.
for module in ak web_infra; do
    echo "== luce-base test src/luce_browser_foundation/$module"
    luce-base test "src/luce_browser_foundation/$module"
done

# workaround: compiler-issues/interpreter_global_array_quadratic (the interpreter takes 35 s to
# initialise text_codec's encoding indexes), so text_codec's tests run natively.
echo "== luce-base test src/luce_browser_foundation/text_codec --native"
luce-base test src/luce_browser_foundation/text_codec --native
echo "== luce-base test tests/text_codec_tests --native"
luce-base test tests/text_codec_tests --native
