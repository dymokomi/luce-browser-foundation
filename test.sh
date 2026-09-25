#!/bin/sh
# Type-check every module of luce-browser-foundation (and run its tests once there are any).
# Stops at the first failing step.
set -e
cd "$(dirname "$0")"

for module in ak gc web_unicode text_codec web_url web_infra; do
    echo "== luce-base check src/luce_browser_foundation/$module"
    luce-base check "src/luce_browser_foundation/$module"
done
