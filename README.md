# luci-app-smart

View drive S.M.A.R.T. data directly in LuCI on an OpenWrt system running version 25.12 or newer.

## Most of the code and implementation were developed with the assistance of ChatGPT.

Verified On
Netgear R7800 — OpenWrt 25.12.5
OpenWrt One — OpenWrt 25.12.1 & OpenWrt 25.12.5

<img width="1200" height="1124" alt="Capture2" src="https://github.com/user-attachments/assets/69aba552-1248-4ef9-824b-9951752ced28" />



## luci-app-smart

A lightweight LuCI frontend for [smartmontools](https://www.smartmontools.org/).

It adds **Status → SMART** to OpenWrt and displays the native `smartctl -a`
output for detected storage devices.

## Features

- Modern LuCI architecture for OpenWrt 25.12+
- Automatically scans common NVMe and SATA/SCSI device nodes
- Displays the complete native `smartctl -a` output
- Shows a simple PASSED / FAILED / OK status when it can be detected
- Refreshes the device list from LuCI without SSH
- No daemon or background process
- Uses the official OpenWrt `smartmontools` package

## Requirements

- OpenWrt 25.12 or newer
- LuCI
- `rpcd-mod-ucode`

The installer automatically installs `smartmontools` and `rpcd-mod-ucode`
if they are missing, using OpenWrt's `apk` package manager.

## Install

After the repository is published, the simplest installation method is:

```sh
wget -O /tmp/install-smart.sh https://raw.githubusercontent.com/dyingway/luci-app-smart/main/install.sh
sh /tmp/install-smart.sh
```

The installer:

1. Installs `smartmontools` if `smartctl` is not available.
2. Installs `rpcd-mod-ucode` if the ucode RPC module is not available.
3. Installs the LuCI SMART files.
4. Restarts `rpcd`.

Then open:

**LuCI → Status → SMART**

You do not need to run `smart-luci-scan` manually. Opening the page calls the
RPC backend, which runs the scanner automatically. Press **Refresh** to scan
again after connecting another drive.

## Uninstall

From a cloned repository:

```sh
sh uninstall.sh
```

Or run the repository's raw uninstall script.

The uninstall script does **not** remove `smartmontools`, because other
applications may use it.

## How it works

```text
LuCI
  │
  ▼
luci.smart/get
  │
  ▼
rpcd + ucode
  │
  ▼
/usr/bin/smart-luci-scan
  │
  ▼
smartctl -a /dev/nvme0
smartctl -a /dev/sda
smartctl -a /dev/sdb
  │
  ▼
Native smartctl text returned to LuCI
```

The backend intentionally returns the native `smartctl -a` text rather than
trying to normalize every SMART attribute. This keeps the frontend small and
lets smartmontools handle device-specific SMART formats.

## Currently scanned device nodes

The scanner checks:

```text
/dev/nvme0 ... /dev/nvme9
/dev/sda ... /dev/sdz
```

Only existing device nodes are queried.

### USB-to-SATA bridges

Some USB storage bridges require a device type such as:

```sh
smartctl -d sat -a /dev/sda
```

The first release uses the plain `smartctl -a` command. USB bridge-specific
handling can be added later without changing the LuCI interface.

## Security

The LuCI frontend does not execute shell commands directly. The only command
executed by the rpcd backend is the fixed scanner at:

```text
/usr/bin/smart-luci-scan
```

The rpcd ACL grants read access only to the `luci.smart/get` method.

## Project layout

```text
luci-app-smart/
├── README.md
├── LICENSE
├── install.sh
├── uninstall.sh
├── usr/
│   ├── bin/
│   │   └── smart-luci-scan
│   └── share/
│       ├── rpcd/
│       │   ├── acl.d/
│       │   │   └── luci-app-smart.json
│       │   └── ucode/
│       │       └── luci.smart
│       └── luci/
│           └── menu.d/
│               └── luci-app-smart.json
└── www/
    └── luci-static/
        └── resources/
            └── view/
                └── smart/
                    └── overview.js
```

## License

MIT License. See `LICENSE`.
