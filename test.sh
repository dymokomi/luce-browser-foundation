#!/bin/sh
# Type-check every module of luce-browser-foundation (and run its tests once there are any).
# Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module"
    luce-base check "src/luce_browser_foundation/$module"
done

# web_url's own tests. Native: the interpreter's start-up is quadratic in large global arrays
# (compiler-issues/interpreter_global_array_quadratic) and web_url holds the public suffix table.
echo "== luce-base test src/luce_browser_foundation/web_url --native"
luce-base test src/luce_browser_foundation/web_url --native

# LibURL's tests (Tests/LibURL and expectations printed by the reference build) go through ak's
# strings, text_codec's encoders and web_unicode's IDNA, so they are checked always and run once
# those regions have replaced their stubs.
echo "== luce-base check tests/web_url_tests -W"
luce-base check tests/web_url_tests -W
if ls src/luce_browser_foundation/ak/stub_r0*.lucb src/luce_browser_foundation/text_codec/stub_r06_*.lucb \
        src/luce_browser_foundation/web_unicode/stub_r07_*.lucb >/dev/null 2>&1; then
    echo "== tests/web_url_tests: not run, ak/text_codec/web_unicode still have stubs"
else
    echo "== luce-base test tests/web_url_tests --native"
    luce-base test tests/web_url_tests --native
fi
