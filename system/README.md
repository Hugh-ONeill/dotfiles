# system/

Root-owned config that the rest of this repo can't carry. The dotfiles work-tree
is `$HOME`, so anything under `/etc` has to live here and be copied into place.

`etc/` mirrors the real destination paths, so installing is a straight prefix
swap and `--diff` can compare against what's live.

```sh
system/install.sh --diff    # what differs from /etc (no root needed)
sudo system/install.sh      # install, reload sysctls, re-exec systemd
```

The sysctl and watchdog files apply without a reboot. The boot files below are
baked into the UKIs: `install.sh` rebuilds both images when they change, and
they take effect on the next boot.

## What's in it

### `etc/kernel/cmdline`, `etc/kernel/cmdline_fallback`, `etc/mkinitcpio.d/linux.preset`

Boot setup, modeled on the laptop's (2026-11-03). The default UKI boots quietly
into the catppuccin-mocha Plymouth splash (`splash` plus the laptop's quiet-boot
flags; the systemd-boot Arch splash bitmap is dropped so it doesn't flash first).
The fallback UKI is rebuilt on every kernel update (`PRESETS` used to list only
`default`, so it had not been rebuilt since 2026-06-26). It skips `plymouth` and
`autodetect` and boots with its own cmdline, so it carries every module and
prints messages. Both cmdlines keep this box's workarounds (`amdgpu.runpm=0`,
`pcie_aspm=off`, the DP-5 EDID override). The loader timeout lives in
`/boot/loader/loader.conf` (not `/etc`), so it is set by hand: `timeout 0`, hold
Space at boot for the menu.

### `etc/systemd/system.conf.d/watchdog.conf`

Arms the SP5100 TCO hardware watchdog via systemd (`RuntimeWatchdogSec=60`).

### `etc/sysctl.d/99-lockup-panic.conf`

`hardlockup_panic=1`, `panic_on_oops=1`, `panic=20`. Deliberately does **not**
set `softlockup_panic`: a soft lockup is often just a saturated CPU, and this
box runs long ollama and bench jobs, so that would reboot under load.

## Why

On 2026-09-01 at 21:47 the machine hard-locked and had to be power-cycled. It
wrote nothing at all: no panic, no OOM, no MCE/EDAC, no hung-task, and
`/sys/fs/pstore` was empty. The journal simply stops mid-poll.

Together these two files turn that into something diagnosable:

- **Freezes and auto-reboots** → the kernel caught a hard lockup, so it's
  software or a driver and there's a backtrace to chase.
- **Freezes and stays dead anyway, watchdog and all** → the fault is below the
  OS. That points at the PSU or the board.

That distinction is the whole point; neither file is a fix.

## Not included: pstore

Capturing the panic text itself is harder on this box and was skipped
deliberately:

- No ACPI ERST table, so the clean firmware-backed path doesn't exist.
- `CONFIG_EFI_VARS_PSTORE_DEFAULT_DISABLE=y`, so efi-pstore is built in but off
  and would need `efi_pstore.pstore_disable=0` on the kernel cmdline.
- The cmdline is baked into a UKI (`/etc/kernel/cmdline` + `mkinitcpio -P`), so
  that means a rebuild and a reboot.
- It writes panic logs into UEFI NVRAM, on an MSI board.

The watchdog gives the reboot-or-not signal without any of that.
