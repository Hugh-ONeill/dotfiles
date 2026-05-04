# Bootstrap TODO

## Done

- `00-pacman.sh` — pacman.conf, makepkg.conf, checkupdates hook
- `04-first-login.sh` — repo pkgs, paru, AUR pkgs, user timers
- `etc/pacman.conf`, `etc/makepkg.conf`, `etc/pacman.d/hooks/`
- `etc/systemd/system/btrfs-balance.{service,timer}` — captured outside `/etc/`
- `pkglist-{official,aur}{,-clean}.txt` — moved in from `$HOME`

## Pending scripts

### `01-disks.sh`

Port disk prep from `~/Documents/Backup/data/wiz/arch_install.sh` lines 79–222. The valuable parts:

- EFI boot entry cleanup pass (`efibootmgr --delete-bootnum`)
- Granular btrfs subvolume layout (`@`, `@data`, `@home`, `@root`, `@snapshots`, `@srv`, `@swap`, `@usr_local`, `@var_*` × 12)
- Hardened per-subvol mount opts (`nodev,nosuid,noexec` on `/var/*`, `/srv`, `/swap`, `/data`)
- LUKS2 root with sector-size=4096
- Encrypted swap with random `/dev/urandom` key + 1MiB ext2 label trick

**Open:** pure-custom (do all disks myself) vs archinstall pre-mount mode (mount everything in `01`, let archinstall just pacstrap + configure). Pure-custom is more code to maintain but archinstall-independent.

### `02-archinstall.sh` *or* `02-pacstrap.sh`

Depends on `01` decision:

- If pre-mount mode: `02-archinstall.sh` runs `archinstall --config archinstall-config.json --silent` against the already-mounted `/mnt`. Need to author `archinstall-config.json` (locale, timezone, mirrors, hostname, user, base pkg set).
- If pure-custom: `02-pacstrap.sh` runs `pacstrap -K /mnt $BASE_PKGS $KERNEL_PKGS $FS_PKGS $UCODE_PKG $OTHER_PKGS` and `genfstab -U /mnt >> /mnt/etc/fstab`.

### `03-post-chroot.sh`

Runs inside `arch-chroot /mnt`. Port from old script lines ~244–476:

- Locale / timezone / hostname / vconsole
- `crypttab.initramfs` for root, `crypttab` for random-key swap
- mkinitcpio: systemd hooks including the `microcode` hook (mkinitcpio v39+, replaces manual ucode-in-cmdline) — example HOOKS: `base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck`
- mkinitcpio MODULES: GPU + VFIO (`vfio_pci vfio vfio_iommu_type1`, plus `nvidia*` for new machine)
- Kernel cmdline: root, btrfs subvol, `zswap.enabled=0`, `intel_iommu=on iommu=pt` (or `amd_iommu=on` on new machine), `nvidia_drm.modeset=1 …`, `quiet loglevel=3 …`
- ZRAM: install `zram-generator`, write `/etc/systemd/zram-generator.conf`
- UKI presets: rewrite `/etc/mkinitcpio.d/$KERNEL.preset` to emit `/efi/EFI/Linux/ArchLinux-*.efi`
- Secure Boot: `sbctl create-keys && enroll-keys --microsoft && sign --save` each UKI
- `efibootmgr --create` direct UEFI boot entries for each UKI
- firewalld: default-zone=drop, ICMP echo blocked
- Snapper: `snapper -c root create-config /` and `snapper -c home create-config /home` (creates the subvol-aware skeletons and `.snapshots/`), then drop in the tracked `etc/snapper/configs/{root,home}` over the auto-generated ones, then enable `snapper-timeline.timer` / `snapper-cleanup.timer`. Configs already tuned: `ALLOW_USERS=wiz`, `SYNC_ACL=yes`, root `TIMELINE_CREATE=no` (snap-pac handles it), `NUMBER_LIMIT_IMPORTANT=15` on root, `TIMELINE_LIMIT_WEEKLY=4` on home.
- `systemctl enable` btrfs-balance.timer, sshd, NetworkManager, systemd-resolved, firewalld

## Open decisions

- **Target machine arch:** AMD CPU + `nvidia-open-dkms` (already reflected in `pkglist-*-clean.txt`). Old script hardcoded `intel-ucode` + intel/nvidia GPU paths — `03` needs `amd-ucode` + AMD IOMMU + nvidia-open module names.
- **Encrypted swap:** keep (random-key, no hibernate) or drop in favor of zram-only.
- **`BUILDDIR=/tmp/makepkg`:** keep for AUR build speed, or drop to avoid OOM on chromium/llvm/rust builds (tmpfs is RAM-backed; need to know new machine's RAM size + tmpfs size before deciding).
- **archinstall vs pure-custom:** see `01` above.
- **Mirrorlist:** the in-repo `mirrorlist.pacnew` from April never got merged. Decide whether to ship a static mirrorlist in `etc/`, run `reflector` fresh on the live ISO, or replicate archinstall's approach (fetch `archlinux.org/mirrors/status/json/` + sort by region/score/speed in ~50 lines of `curl | jq`).

## Other gaps

- **`flatpaks.txt`:** missing — regenerate with `flatpak list --app --columns=application > flatpaks.txt` and add a flatpak install step to `04`.
- **dotbare clone in bootstrap flow:** the user runs `git clone --bare git@github.com:GrumpyRumpus/dotfiles.git ~/.dotfiles && dotbare checkout` *before* `04` runs (since the scripts live inside dotbare). Document this prerequisite somewhere — possibly a thin `bootstrap.sh` at the root that handles dotbare clone, then dispatches to the numbered scripts.
- **Machine-specific overrides:** old script handled this via env-var blocks at the top. Consider an `env/` dir with `desktop.env`, `laptop.env`, `vm.env` files that get sourced.
- **Drift between `etc/*` and live `/etc/*`:** copying snapshots into the bootstrap repo means they can fall out of sync. Consider a `sync-etc.sh` helper or a pacman hook that warns when `/etc/pacman.conf` changes vs the tracked copy.
