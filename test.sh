#!/bin/sh
# Type-check every module of luce-browser-foundation with warnings as errors, run the unit tests
# of every module and of the tests package, and regenerate web_unicode's tables into a temporary
# directory to compare them with the committed ones. Stops at the first failing step.
set -e
cd "$(dirname "$0")"

# Every hand-written fragment is laid out as the pinned compiler's formatter lays it out
# (generated fragments are compared with their generator's output instead).
echo "== luce-base fmt --check"
for file in $(git ls-files '*.lucb' | grep -v -e '/generated_' -e '_tables\.lucb$'); do
    luce-base fmt "$file" --check > /dev/null || { echo "$file is not formatted (luce-base fmt $file --write)"; exit 1; }
done

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
check tests/web_url_tests

# Unit tests (ported from Tests/AK, Tests/LibWeb and focused cases), module by module.
for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base test src/luce_browser_foundation/$module"
    luce-base test "src/luce_browser_foundation/$module"
done
for package in text_codec_tests web_url_tests; do
    echo "== luce-base test tests/$package"
    luce-base test "tests/$package"
done

echo "== tools/gen_ucd: regenerate web_unicode's tables and compare"
mkdir -p build
luce-base build tools/gen_ucd -o build/gen_ucd
generated=$(mktemp -d)
trap 'rm -rf "$generated"' EXIT
build/gen_ucd data "$generated"
for file in "$generated"/*.lucb; do
    cmp "$file" "src/luce_browser_foundation/web_unicode/$(basename "$file")"
done
