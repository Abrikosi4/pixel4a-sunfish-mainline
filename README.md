# Pixel 4a (sunfish) — mainline / postmarketOS bring-up

Kernel patches and userspace bits from bringing up the **Google Pixel 4a**
("sunfish", Qualcomm SM7150) on **postmarketOS** with a mainline kernel
(`linux-postmarketos-qcom-sm7150`, based on the
[sm7150-mainline](https://github.com/sm7150-mainline/linux) fork, tag `v7.1_rc3`).

The patches apply on top of that kernel's aport, in `source=` order.

## Status

| Peripheral | State | Patch(es) |
|---|---|---|
| Touchscreen (STMicro FTM5) | works locally, but **superseded upstream** by `stmfts5` (see below) | `0001`, `0002` |
| Speaker amps (Cirrus cs35l41 ×2) | ⚠️ probe OK, but **audio blocked** upstream (see below) | `0004`, `0005` |
| sxmo (Sway) gestures / profile | ✅ working | `sxmo/` |

## Touchscreen — `ftm5` driver (0001, 0002) — superseded

This unit uses an **STMicroelectronics FTM5** controller on `i2c7 @ 0x49`
(chip id `0x4836`). `0002` is a **from-scratch `ftm5.c`** driver
(`compatible = "st,fts"`) that reports multitouch, does DRM panel-follower PM
(sensing tied to panel power) and ESD/watchdog fault recovery; `0001` is its
`touchscreen@49` DT node. It works on this device, but it is **not the way
this controller is going upstream.**

The upstream direction is **David Heidelberg's `stmfts5` series** (extending
the *existing* mainline `stmfts` driver to the FTS5/FTM5, on
[LKML](https://lore.kernel.org/lkml/20260409-stmfts5-v4-0-64fe62027db5@ixit.cz/)),
with sunfish DT + a `CONTROLLER_READY` poll fix already prepared by **miromraz**
([miromraz/pixel4a-stmfts5-mainline](https://github.com/miromraz/pixel4a-stmfts5-mainline)).
That poll fix resolves the very `stmfts` "bootloop" this separate driver worked
around, so a standalone `ftm5` driver on the same `st,fts` compatible would
collide with `stmfts5` once it lands. **Use `stmfts5`, not these patches** —
`0001`/`0002` are kept here only as a personal reference implementation.

Battery (PM6150 QGauge + SMB2 charger) is handled upstream in the
sm7150-mainline fork by [PR #53](https://github.com/sm7150-mainline/linux/pull/53),
so it is not carried here.

## Audio (0004, 0005) — ⚠️ blocked upstream, not by these patches

Two **Cirrus cs35l41** smart amps on `i2c9 @ 0x40/0x41` drive the stereo
speaker over **Tertiary TDM**. `0004` extends the mainline `sdm845` ASoC
machine driver to handle Tertiary TDM (it hardcoded Quaternary) and registers
`qcom,sm7150-sndcard`; `0005` adds the amps + a `sound` card exposing them via
the ADSP (`q6afe TERTIARY_TDM_RX_0`).

Both amps probe cleanly over I2C (chip id `35a40`, rev B2). **However**, audio
via the ADSP is currently unusable because the **ADSP crash-loops** on its
SAR-sensor process (`sensor_process … sar.cc … chre_utils fatal`, every ~10 s) —
a pre-existing SM7150-mainline platform issue in the ADSP sensor bring-up
(needs a `hexagonrpcd` that supports guest file writes), unrelated to these
audio patches. The audio drivers are therefore built but kept out of autoload
via `/etc/modprobe.d/blacklist-audio.conf` so a probe against the broken ADSP
can't bootloop. They are ready to enable once the ADSP is stable.

## Applying

Drop `kernel-patches/*.patch` into the `linux-postmarketos-qcom-sm7150` aport,
add them to `source=` (order 0001, 0002, 0004, 0005) and their `sha512sums`
(`pmbootstrap checksum ...`), bump `pkgrel`, then
`pmbootstrap build linux-postmarketos-qcom-sm7150`. `aport/APKBUILD` is the
reference version wiring them in (pkgrel 13). No kernel config changes are
needed — the required drivers (`SND_SOC_SDM845`, `SND_SOC_CS35L41_I2C`, QDSP6,
cs35l41, ftm5's `CONFIG_TOUCHSCREEN_FTM5`) build fine.

## sxmo

`sxmo/sxmo_deviceprofile_google,sunfish.sh` → install to
`/usr/bin/sxmo_deviceprofile_google,sunfish.sh` (`chmod +x`). Also add the user
to the `input` group so `lisgd` (edge-swipe gestures) can open `/dev/input/*`.
