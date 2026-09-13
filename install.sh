#!/bin/sh
set -eu

# Self-contained installer for luci-app-smart.
# When hosted on GitHub, users only need to download and run this script.

printf '%s\n' '==> Checking dependencies...'

if ! command -v smartctl >/dev/null 2>&1; then
    printf '%s\n' 'smartmontools is not installed; installing it...'
    apk update
    apk add smartmontools
fi

if ! command -v ucode >/dev/null 2>&1; then
    printf '%s\n' 'rpcd-mod-ucode is not installed; installing it...'
    apk update
    apk add rpcd-mod-ucode
fi

printf '%s\n' '==> Installing luci-app-smart...'

mkdir -p \
    /usr/bin \
    /usr/share/rpcd/acl.d \
    /usr/share/rpcd/ucode \
    /usr/share/luci/menu.d \
    /www/luci-static/resources/view/smart

cat > /usr/bin/smart-luci-scan <<'SMART_SCAN_EOF'
#!/bin/sh

for d in /dev/nvme[0-9] /dev/sd[a-z]; do
    [ -e "$d" ] || continue
    echo "===SMART_DEVICE_START===$d"
    /usr/sbin/smartctl -a "$d" 2>&1 || true
    echo "===SMART_DEVICE_END==="
done
SMART_SCAN_EOF

cat > /usr/share/rpcd/acl.d/luci-app-smart.json <<'ACL_EOF'
{
    "luci-app-smart": {
        "description": "Grant access to luci.smart",
        "read": {
            "ubus": {
                "luci.smart": ["get"]
            }
        }
    }
}
ACL_EOF

cat > /usr/share/rpcd/ucode/luci.smart <<'UCODE_EOF'
#!/usr/bin/ucode
'use strict';
const fs = require('fs');

function get_smart() {
    let proc = fs.popen('/usr/bin/smart-luci-scan', 'r');
    if (!proc)
        return { output: '' };

    let output = proc.read('all');
    proc.close();
    return { output: output };
}

return {
    'luci.smart': {
        get: {
            call: get_smart
        }
    }
};
UCODE_EOF

cat > /usr/share/luci/menu.d/luci-app-smart.json <<'MENU_EOF'
{
    "admin/status/smart": {
        "title": "SMART",
        "order": 90,
        "action": {
            "type": "view",
            "path": "smart/overview"
        },
        "depends": {
            "acl": ["luci-app-smart"]
        }
    }
}
MENU_EOF

cat > /www/luci-static/resources/view/smart/overview.js <<'JS_EOF'
'use strict';
'require view';
'require rpc';
'require ui';

const callSmart = rpc.declare({
    object: 'luci.smart',
    method: 'get',
    expect: {}
});

function parseDevices(output) {
    const devices = [];
    const re = /===SMART_DEVICE_START===([^\n]+)\n([\s\S]*?)===SMART_DEVICE_END===/g;
    let match;

    while ((match = re.exec(output || '')) !== null) {
        const text = match[2];
        let model = '';
        let health = '';
        const modelMatch = text.match(/^Device Model:\s*(.+)$/m) ||
            text.match(/^Model Number:\s*(.+)$/m) ||
            text.match(/^Model Family:\s*(.+)$/m);
        const healthMatch = text.match(/^SMART overall-health self-assessment test result:\s*(.+)$/m) ||
            text.match(/^SMART Health Status:\s*(.+)$/m);

        if (modelMatch) model = modelMatch[1].trim();
        if (healthMatch) health = healthMatch[1].trim();

        devices.push({
            device: match[1].trim(),
            model: model,
            health: health,
            output: text
        });
    }

    return devices;
}

function healthClass(health) {
    const h = (health || '').toUpperCase();
    if (h.includes('FAIL')) return 'danger';
    if (h.includes('PASS') || h === 'OK') return 'success';
    return 'warning';
}

return view.extend({
    load: function() {
        return callSmart();
    },

    render: function(data) {
        const devices = parseDevices(data && data.output ? data.output : '');
        const container = E('div', {}, [
            E('div', { 'class': 'cbi-map' }, [
                E('h2', {}, _('SMART')),
                E('div', { 'class': 'cbi-map-descr' },
                    _('SMART information provided by smartmontools.'))
            ]),
            E('div', { 'style': 'text-align:right; margin-bottom:1em' }, [
                E('button', {
                    'class': 'btn cbi-button cbi-button-action',
                    'click': ui.createHandlerFn(this, function() {
                        location.reload();
                    })
                }, _('Refresh'))
            ])
        ]);

        if (!devices.length) {
            container.appendChild(E('div', {
                'class': 'alert-message warning'
            }, _('No supported storage devices were detected.')));
            return container;
        }

        devices.forEach(function(item) {
            let title = item.device;
            if (item.model) title += ' — ' + item.model;

            const heading = [E('h3', {}, title)];
            if (item.health) {
                heading.push(E('span', {
                    'class': 'label ' + healthClass(item.health),
                    'style': 'margin-left:0.75em'
                }, item.health));
            }

            container.appendChild(E('div', { 'class': 'cbi-section' }, [
                E('div', {
                    'style': 'display:flex; align-items:center; gap:0.5em; flex-wrap:wrap'
                }, heading),
                E('pre', {
                    'style': [
                        'white-space: pre-wrap',
                        'overflow-x: auto',
                        'font-family: monospace',
                        'font-size: 12px',
                        'line-height: 1.45',
                        'max-height: 70vh',
                        'overflow-y: auto',
                        'padding: 1em',
                        'margin-top: 0.75em',
                        'background: var(--background-color-high, #f5f5f5)',
                        'border: 1px solid var(--border-color-medium, #ccc)'
                    ].join(';')
                }, item.output)
            ]));
        });

        return container;
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
JS_EOF

chmod 0755 /usr/bin/smart-luci-scan /usr/share/rpcd/ucode/luci.smart
chmod 0644 /usr/share/rpcd/acl.d/luci-app-smart.json /usr/share/luci/menu.d/luci-app-smart.json /www/luci-static/resources/view/smart/overview.js

/etc/init.d/rpcd restart
rm -rf /tmp/luci-modulecache /tmp/luci-indexcache

printf '%s\n' ''
printf '%s\n' 'Installation complete.'
printf '%s\n' 'Open LuCI -> Status -> SMART'
printf '%s\n' ''
printf '%s\n' 'smartmontools and rpcd-mod-ucode are installed automatically when needed.'
