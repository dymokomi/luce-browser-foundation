#!/bin/sh
# Type-check every module of luce-browser-foundation and run the modules' tests.
# Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module"
    luce-base check "src/luce_browser_foundation/$module"
done

for module in gc; do
    echo "== luce-base test src/luce_browser_foundation/$module"
    luce-base test "src/luce_browser_foundation/$module"
done
