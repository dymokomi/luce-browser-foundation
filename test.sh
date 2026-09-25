#!/bin/sh
# Type-check every module of luce-browser-foundation and run the tests of the ported ones.
# Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module"
    luce-base check "src/luce_browser_foundation/$module"
done

# workaround: compiler-issues/interpreter_global_array_quadratic (the interpreter takes 35 s to
# initialise text_codec's encoding indexes), so text_codec's tests run natively.
echo "== luce-base test src/luce_browser_foundation/text_codec --native"
luce-base test src/luce_browser_foundation/text_codec --native

# LibTextCodec's tests that go through ak's strings run once ak's regions (r01-r03) have replaced
# their stubs; until then they are only checked.
echo "== luce-base check tests/text_codec_tests -W"
luce-base check tests/text_codec_tests -W
ak=src/luce_browser_foundation/ak
if [ -e $ak/stub_r01_ak_core.lucb ] || [ -e $ak/stub_r02_ak_text.lucb ] || [ -e $ak/stub_r03_ak_format.lucb ]; then
    echo "== tests/text_codec_tests: not run, ak still has stubs (r01-r03)"
else
    echo "== luce-base test tests/text_codec_tests --native"
    luce-base test tests/text_codec_tests --native
fi
