#!/bin/sh
set -eu

printf '%s\n' 'Removing luci-app-smart...'

rm -f \
    /usr/bin/smart-luci-scan \
    /usr/share/rpcd/acl.d/luci-app-smart.json \
    /usr/share/rpcd/ucode/luci.smart \
    /usr/share/luci/menu.d/luci-app-smart.json \
    /www/luci-static/resources/view/smart/overview.js

/etc/init.d/rpcd restart 2>/dev/null || true
rm -rf /tmp/luci-modulecache /tmp/luci-indexcache

printf '%s\n' 'luci-app-smart has been removed.'
printf '%s\n' 'smartmontools was left installed.'
