# RME Babyface Pro FS: operating modes

This folder holds the config for the external **RME Babyface Pro FS** interface
and the laptop's internal audio. Two mutually exclusive modes for the RME:

## Switching CC ⇄ Proprietary (TuxMix)

Switching is done by **renaming the file** `50-tuxmix.conf`:

| Mode           | File state                                 | RME control                       |
|----------------|--------------------------------------------|-----------------------------------|
| **CC** (default)| `50-tuxmix.conf.disabled` (disabled)       | Kernel driver (`snd-usb-audio`) via `51-rme.conf` |
| **Proprietary** | `50-tuxmix.conf` (active, rename)          | In-house **TuxMix** driver (TotalMix, proprietary mode) |

Switch to proprietary mode:

```bash
mv ~/.config/pipewire/pipewire.conf.d/50-tuxmix.conf.disabled \
   ~/.config/pipewire/pipewire.conf.d/50-tuxmix.conf
systemctl --user restart pipewire pipewire-pulse
# the "RME Babyface Pro FS (TuxMix)" sink appears
pactl set-default-sink tuxmix
```

Switch back to CC (Class Compliant) mode:

```bash
mv ~/.config/pipewire/pipewire.conf.d/50-tuxmix.conf \
   ~/.config/pipewire/pipewire.conf.d/50-tuxmix.conf.disabled
systemctl --user restart pipewire wireplumber pipewire-pulse
```

> **Important**: proprietary and CC modes cannot run at the same time over
> USB; only one streaming session per device. The TuxMix driver and the
> `snd-usb-audio` kernel driver target the same interface.

## Internal Ryzen interface: specific quantum

- `custom-settings.conf`: default global quantum = `64` (suited for RME CC).
  The `min-quantum`/`max-quantum` are **deliberately removed** so that not all
  interfaces are locked onto a rigid floor.
- `52-ryzen-quantum.conf` (WirePlumber): forces `256` on the internal Ryzen
  sound card (`alsa_{output,input}.pci-0000_07_00.6.*`) only; 64 causes
  underruns there. Adjust `node.quantum.min/max` to test other values.
