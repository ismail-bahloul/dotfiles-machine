# Windows 11: dual boot helpers

Files meant to be run **on the Windows side** (they are not deployed by chezmoi into `~/`).

## 1. RTC clock in UTC (recommended)

`enable-utc-clock.reg` tells Windows that the RTC is in **UTC** (like Linux).

- **Why**: otherwise, every time you switch from Linux to Windows, the clock is offset (Windows assumes the RTC is in local time).
- **How**: double-click + "Yes" (administrator), then reboot once under Windows.
- **Undo**: remove the `RealTimeIsUniversal` value then reboot.

## 2. Disable "Fast Startup" (recommended if you mount your NTFS drives under Linux)

Windows 11 has a **fast startup** (hybrid shutdown) that leaves NTFS volumes in a state that was not cleanly unmounted. If you mount `C:` or the `SHARED` partition in **read-write** mode under Linux, this can corrupt the filesystem.

In an **Administrator** prompt under Windows:

```powershell
# Disables hibernation + Fast Startup
powercfg /h off
```

`powercfg /h on` to re-enable.

## 3. Partitions (reminder)

| Part. | Content | UUID | Role |
|---|---|---|---|
| `nvme1n1p2` | Windows `C:` | `01DD20323D16A210` | Windows OS: do **not** mount in rw under Linux (Fast Startup) |
| `nvme1n1p3` | `SHARED` (402 GB) | `5CAC12755C11BA05` | Data shared between OSes: mountable in rw (ntfs-3g) |

The Linux clock (`/etc/adjtime` = `UTC`) is already correct; change nothing on the Linux side.
