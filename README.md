# Debloat Ubuntu 26.04

A lightweight script to disable unnecessary Ubuntu/GNOME background services for better performance, privacy, and lower resource usage.

The script does **not remove packages**. It only disables or masks services and can be restored at any time.

## Features

Manage:

* ModemManager
* Avahi (network discovery)
* Bluetooth
* Whoopsie (crash reporting)
* Automatic updates
* Logging (`rsyslog`)
* Printer services (CUPS)
* Color management
* GNOME file indexing (`tracker`)

It can also hide unused GNOME Settings panels:

* Bluetooth
* Printers
* Color

---

## Installation

Make the script executable:

```bash
chmod +x debloat-ubuntu-26-04.sh
```

Run it as a **normal user** (not root):

```bash
./debloat-ubuntu-26-04.sh help
```

---

## Usage

### Show help

```bash
./debloat-ubuntu-26-04.sh help
```

### Check current status

Shows enabled/disabled services and GNOME menu overrides.

```bash
./debloat-ubuntu-26-04.sh status
```

---

## Modes

### Full debloat

Disable most managed services.

```bash
./debloat-ubuntu-26-04.sh all
```

Disables:

* ModemManager
* Avahi
* Bluetooth
* Whoopsie
* Automatic updates
* Logging
* Printers
* Color management
* GNOME indexing

---

### Privacy mode

Disable privacy/network-related services.

```bash
./debloat-ubuntu-26-04.sh privacy
```

Disables:

* ModemManager
* Avahi
* Bluetooth
* Whoopsie

---

### Desktop mode

Reduce desktop background services.

```bash
./debloat-ubuntu-26-04.sh desktop
```

Disables:

* Printers
* Color management
* Bluetooth
* GNOME indexing

---

## Toggle Individual Features

Enable or disable a specific feature:

```bash
./debloat-ubuntu-26-04.sh <feature> on
./debloat-ubuntu-26-04.sh <feature> off
```

Available features:

```text
modem
avahi
bluetooth
whoopsie
updates
logging
printers
color
indexing
```

Examples:

```bash
./debloat-ubuntu-26-04.sh bluetooth off
./debloat-ubuntu-26-04.sh updates off
./debloat-ubuntu-26-04.sh indexing on
```

You can also use:

```bash
./debloat-ubuntu-26-04.sh toggle bluetooth off
```

---

## Restore Everything

Restore all changes:

```bash
./debloat-ubuntu-26-04.sh restore
```

This will:

* Re-enable managed services
* Restore GNOME Settings panels
* Re-enable indexing and background services

---

## Notes

* Run as a **normal user**, not root
* The script uses `sudo` internally
* No packages are removed
* All changes are reversible

Recommended flow:

```bash
./debloat-ubuntu-26-04.sh status
./debloat-ubuntu-26-04.sh desktop
./debloat-ubuntu-26-04.sh restore
```
