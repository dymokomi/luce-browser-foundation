#!/bin/sh
# Lint, not a test (`luc test` runs the tests): every hand-written fragment is laid out as
# luce-base fmt lays it out (generated fragments are compared with their generator's output by
# tests/generated instead), and every module checks with -W without a word.
set -e
cd "$(dirname "$0")/.."
for file in $(git ls-files '*.lucb' | grep -v -e '/generated_' -e '_tables\.lucb$'); do
    luce-base fmt "$file" --check > /dev/null || { echo "$file is not formatted (luce-base fmt $file --write)"; exit 1; }
done
for module in src/ak src/gc src/web_unicode src/text_codec src/web_url src/web_infra tests/text_codec_tests tests/web_url_tests; do
    # -W reports warnings without failing, so any output at all fails the run.
    output=$(luce-base check "$module" -W 2>&1) || { echo "$output"; exit 1; }
    [ -z "$output" ] || { echo "$output"; exit 1; }
done
echo "clean"
