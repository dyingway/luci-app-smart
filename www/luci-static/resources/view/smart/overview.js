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
        const device = match[1].trim();
        const text = match[2];

        let model = '';
        let health = '';

        const modelMatch =
            text.match(/^Device Model:\s*(.+)$/m) ||
            text.match(/^Model Number:\s*(.+)$/m) ||
            text.match(/^Model Family:\s*(.+)$/m);

        if (modelMatch)
            model = modelMatch[1].trim();

        const healthMatch =
            text.match(/^SMART overall-health self-assessment test result:\s*(.+)$/m) ||
            text.match(/^SMART Health Status:\s*(.+)$/m);

        if (healthMatch)
            health = healthMatch[1].trim();

        devices.push({
            device: device,
            model: model,
            health: health,
            output: text
        });
    }

    return devices;
}

function healthClass(health) {
    const h = (health || '').toUpperCase();

    if (h.includes('FAIL'))
        return 'danger';

    if (h.includes('PASS') || h === 'OK')
        return 'success';

    return 'warning';
}

return view.extend({
    load: function() {
        return callSmart();
    },

    render: function(data) {
        const output = data && data.output ? data.output : '';
        const devices = parseDevices(output);

        const container = E('div', {}, [
            E('div', { 'class': 'cbi-map' }, [
                E('h2', {}, _('SMART')),
                E('div', { 'class': 'cbi-map-descr' },
                    _('SMART information provided by smartmontools.'))
            ])
        ]);

        const refresh = E('button', {
            'class': 'btn cbi-button cbi-button-action',
            'click': ui.createHandlerFn(this, function() {
                location.reload();
            })
        }, _('Refresh'));

        container.appendChild(
            E('div', {
                'style': 'text-align:right; margin-bottom:1em'
            }, refresh)
        );

        if (!devices.length) {
            container.appendChild(
                E('div', {
                    'class': 'alert-message warning'
                }, _('No supported storage devices were detected.'))
            );

            return container;
        }

        devices.forEach(function(item) {
            let title = item.device;

            if (item.model)
                title += ' — ' + item.model;

            const heading = [
                E('h3', {}, title)
            ];

            if (item.health) {
                heading.push(
                    E('span', {
                        'class': 'label ' + healthClass(item.health),
                        'style': 'margin-left:0.75em'
                    }, item.health)
                );
            }

            container.appendChild(
                E('div', {
                    'class': 'cbi-section'
                }, [
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
                ])
            );
        });

        return container;
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
