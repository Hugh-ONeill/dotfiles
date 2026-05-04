# Bootstrap TODO

## Done

- `00-pacman.sh` — pacman.conf, makepkg.conf, checkupdates hook
- `01-disks.sh` — partition + format + mount (EFI + root with ~18 btrfs subvols + home, no encryption, no swap partition)
- `02-pacstrap.sh` — pacstrap base, fstab, locale/timezone/hostname, network services, user creation
- `03-post-chroot.sh` — mkinitcpio HOOKS w/ microcode, kernel cmdline, zram, UKI presets, sbctl, direct UEFI entries, btrfs-balance, snapper configs, service enablement
- `04-first-login.sh` — repo pkgs, paru, AUR pkgs, user timers
- `etc/pacman.conf`, `etc/makepkg.conf`, `etc/pacman.d/hooks/`
- `etc/systemd/system/btrfs-balance.{service,timer}` — captured outside `/etc/`
- `etc/snapper/configs/{root,home}` — tuned snapper configs
- `pkglist-{official,aur}{,-clean}.txt` — moved in from `$HOME`

## Pending scripts

### `01-disks.sh` — DONE (v1)

Pure-custom disk prep, ~184 lines. Stops at `/mnt` fully mounted; 02 picks up from there.

Departures from old script:
- No LUKS root (user opted out — desktop, no strict security need)
- No encrypted swap, no swap partition (zram only, configured in `03`)
- Dropped `@swap` subvol (no swapfile)
- Kept granular btrfs layout (~18 root subvols + `@home`) and hardened mount opts on `/var/*`, `/srv`, `/data`, `/root`, `/usr/local`
- `space_cache=v2` dropped from mount opts (default since kernel 5.15)

Tested: syntax-clean. Needs VM run-through before trusting.

**Future iterations:** add HyDe-style menu front-end (whiptail or bash select) for hostname/user/disk-layout choices.

### `02-pacstrap.sh` — DONE (v1)

Pure-custom (no archinstall). ~122 lines. Pacstrap, fstab, time/locale/hostname, network services, user.

Defaults:
- `KERNEL_PKGS="linux linux-headers"`, `UCODE_PKG="amd-ucode"` (target machine)
- Network: `networkmanager + wpa_supplicant`, no `iwd` (desktop, ethernet primary)
- Locale: `en_US.UTF-8` always enabled (some software hardcodes), plus `$LANG_VAL` if different
- User: in `wheel` group, sudoers uncommented for `%wheel ALL=(ALL:ALL) ALL`
- Root: locked by default; prompt offers to set password

Tested: syntax-clean. Needs VM run-through.

### `03-post-chroot.sh` — DONE (v1)

~179 lines. Departures from old script:

- **No firewalld** (deferred — desktop on home network, no strict security need; user can install later)
- **No `sd-encrypt` hook, no crypttab** (no LUKS)
- **No nvidia in `MODULES=()`** — defer to 04 where `nvidia-open-dkms` is in pkglist; pacman hook rebuilds UKIs after install. First boot is tty-only on framebuffer.
- **`microcode` hook** added to HOOKS line (v39+; replaces legacy ucode-in-cmdline)
- **`amd_iommu=on iommu=pt`** in cmdline (instead of `intel_iommu=on`)
- Snapper: skip `create-config` since `/.snapshots` is already a subvol from 01; just drop in tuned configs + register via `/etc/conf.d/snapper`
- Auto-detects `ROOT_UUID`, `EFI_DEV`, `EFI_PART_NUM` from current `/mnt` mounts — no env-var or arg required
- sbctl gracefully skips if firmware not in Setup Mode (warns + tells user to enroll later)

Tested: syntax-clean. Needs VM run-through.

## Open decisions

- ~~Target machine arch:~~ DECIDED — AMD CPU + `nvidia-open-dkms`; reflected throughout 02/03 + clean pkglists.
- ~~Encrypted swap:~~ DECIDED — dropped, zram only.
- ~~Encryption layer:~~ DECIDED — no LUKS at all, no per-partition encryption.
- **`BUILDDIR=/tmp/makepkg`:** keep for AUR build speed, or drop to avoid OOM on chromium/llvm/rust builds (tmpfs is RAM-backed; need to know new machine's RAM size + tmpfs size before deciding).
- ~~archinstall vs pure-custom:~~ DECIDED — pure-custom, all four scripts.
- **Mirrorlist:** the in-repo `mirrorlist.pacnew` from April never got merged. Decide whether to ship a static mirrorlist in `etc/`, run `reflector` fresh on the live ISO, or replicate archinstall's approach (fetch `archlinux.org/mirrors/status/json/` + sort by region/score/speed in ~50 lines of `curl | jq`).
- **Firewalld:** dropped from 03 default; revisit if you want it on the new machine. Add 5 lines in 03 if so (install + enable + accept SSH).

## Other gaps

- ~~`flatpaks.txt`:~~ DONE — moved in from `$HOME`, wired into `04` (adds flathub remote if missing, then `xargs flatpak install`).
- **dotbare clone in bootstrap flow:** the user runs `git clone --bare git@github.com:GrumpyRumpus/dotfiles.git ~/.dotfiles && dotbare checkout` *before* `04` runs (since the scripts live inside dotbare). Document this prerequisite somewhere — possibly a thin `bootstrap.sh` at the root that handles dotbare clone, then dispatches to the numbered scripts.
- **Machine-specific overrides:** old script handled this via env-var blocks at the top. Consider an `env/` dir with `desktop.env`, `laptop.env`, `vm.env` files that get sourced.
- **Drift between `etc/*` and live `/etc/*`:** copying snapshots into the bootstrap repo means they can fall out of sync. Consider a `sync-etc.sh` helper or a pacman hook that warns when `/etc/pacman.conf` changes vs the tracked copy.
