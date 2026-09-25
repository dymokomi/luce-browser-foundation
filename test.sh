#!/bin/sh
# Type-check every module of luce-browser-foundation with warnings as errors, then run the unit
# tests of the modules that have them. Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module -W"
    # -W reports warnings without failing, so any output at all fails the run.
    output=$(luce-base check "src/luce_browser_foundation/$module" -W 2>&1) || { echo "$output"; exit 1; }
    if [ -n "$output" ]; then
        echo "$output"
        exit 1
    fi
done

for module in ak; do
    echo "== luce-base test src/luce_browser_foundation/$module"
    luce-base test "src/luce_browser_foundation/$module"
done
