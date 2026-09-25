#!/bin/sh
# Type-check every module of luce-browser-foundation, run the tests of the modules that have
# them, and regenerate the generated tables into a temporary directory to compare them with
# the committed ones. Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module"
    luce-base check "src/luce_browser_foundation/$module"
done

for module in web_unicode; do
    echo "== luce-base test src/luce_browser_foundation/$module"
    luce-base test "src/luce_browser_foundation/$module"
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
