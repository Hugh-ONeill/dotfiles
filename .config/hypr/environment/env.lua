-----------------------------
--- ENVIRONMENT VARIABLES ---
-----------------------------
-- hl.env(name, value) sets the variable in the compositor's environment, so it
-- reaches everything Hyprland itself spawns. Values are plain strings: no $VAR
-- expansion, use os.getenv().

local host = require("lib.host")

-- Aquamarine (multi-GPU), and the GPU split further down, differ per machine.
-- The desktop path is the original; the laptop branch is in the else block.
if host.desktop then

-- Display/compositor runs on the AMD iGPU so the desktop survives discrete-GPU
-- faults. Addressed by a stable alias because /dev/dri/cardN numbering is
-- assigned at probe time and is not stable across boots or driver reloads.
--
-- NOT /dev/dri/by-path/pci-0000:15:00.0-card: aquamarine splits AQ_DRM_DEVICES
-- on ':', so a by-path name shreds on its own PCI colons and no device is
-- found -- the backend then fails to build and Hyprland aborts during
-- initServer. gpu-igpu / gpu-r9700 are colon-free aliases for the same nodes,
-- created by /etc/udev/rules.d/61-drm-stable-names.rules.
-- History: the 3090's RMA (2026-08-30) took the old gpu-amd/gpu-nvidia aliases
-- with it (the udev rule keyed on a PCI address that renumbered), Hyprland had
-- two unopenable paths and aborted to TTY. Key udev rules on DRIVERS, not on
-- the PCI address (see ~/fix-gpu.sh).
hl.env("AQ_DRM_DEVICES", "/dev/dri/gpu-igpu")

-- SSH
hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/ssh-agent.socket")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- GPU split: AMD iGPU drives the display, the discrete card stays free for
-- compute. CUDA/ROCm workloads reach it through /dev/dri + the runtime
-- directly and do not consult any variable below, so pointing the display
-- stack at the iGPU costs nothing on the compute side.
--
-- Removed when the monitor moved to the iGPU port:
--   GBM_BACKEND=nvidia-drm           buffers are allocated on amdgpu now
--   __GLX_VENDOR_LIBRARY_NAME=nvidia forced every GL app onto the wrong GPU
--   __GL_GSYNC_ALLOWED / __GL_VRR_ALLOWED   NVIDIA-display-only, inert here
--   LIBVA_DRIVER                     not a real libva variable
--   NVD_BACKEND                      nvidia-vaapi-driver only
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")

else

-- Laptop: Intel UHD 630 (00:02.0) drives eDP-1 and goes first, the Quadro
-- P2000 (01:00.0) second for the HDMI port. Resolved from by-path each start
-- because cardN swaps between boots; falls back to the old fixed order.
local igpu = host.drm_card("0000:00:02.0")
local dgpu = host.drm_card("0000:01:00.0")
if igpu and dgpu then
    hl.env("AQ_DRM_DEVICES", igpu .. ":" .. dgpu)
elseif igpu then
    hl.env("AQ_DRM_DEVICES", igpu)
else
    hl.env("AQ_DRM_DEVICES", "/dev/dri/card2:/dev/dri/card1")
end

-- NVIDIA, carried over unchanged from the hyprlang env.conf
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "1")
hl.env("LIBVA_DRIVER_NAME", "vdpau")
hl.env("LIBVA_DRIVER", "nvidia")
hl.env("VDPAU_DRIVER", "nvidia")
hl.env("NVD_BACKEND", "direct")

end

-- Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")

-- Toolkit backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Toolkit scale
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_SCALE", "1")
