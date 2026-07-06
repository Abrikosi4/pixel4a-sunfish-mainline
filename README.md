# Pixel 4a (sunfish) — mainline / postmarketOS bring-up

Kernel patches and userspace bits from bringing up the **Google Pixel 4a**
("sunfish", Qualcomm SM7150) on **postmarketOS** with a mainline kernel
(`linux-postmarketos-qcom-sm7150`, based on the
[sm7150-mainline](https://github.com/sm7150-mainline/linux) fork, tag `v7.1_rc3`).

The patches apply on top of that kernel's aport, in `source=` order.

## Status

| Peripheral | State | Patch(es) |
|---|---|---|
| Touchscreen (STMicro FTM5) | ✅ working — multitouch, PM, recovery | `0001`, `0002` |
| Battery gauge + charge status | ✅ working — capacity/voltage/current/temp + Charging/Discharging | `0003` |
| Speaker amps (Cirrus cs35l41 ×2) | ⚠️ probe OK, but **audio blocked** upstream (see below) | `0004`, `0005` |
| sxmo (Sway) gestures / profile | ✅ working | `sxmo/` |

## Touchscreen — `ftm5` driver (0001, 0002)

This unit uses an **STMicroelectronics FTM5** controller on `i2c7 @ 0x49`
(chip id `0x4836`), not the Synaptics/other variant some sunfish units carry.
Mainline `stmfts` bootloops on it, so `0002` adds a **from-scratch `ftm5.c`**
driver (`compatible = "st,fts"`), with the FTM5 I2C protocol ported from the
downstream STMicro FTS sources. Features:

- Type-B multitouch (10 points), coordinates confirmed 1:1 (0..1079 × 0..2339).
- **DRM panel-follower** power management — touch sensing is powered with the
  panel, off when the screen is off.
- Chip-fault recovery (ESD / hard-fault / watchdog → reset + reinit),
  controller-ready re-init.

`0001` adds the `touchscreen@49` DT node (reset gpio8, AP/SLPI mux gpio72,
IRQ tlmm gpio9, pm6150 gpio4 load-switch via pinctrl) and couples it to the
panel via `panel = <&panel>`.

## Battery (0003)

Enables the already-present-but-disabled **PM6150 QG fuel gauge**
(`qcom,pm6150-qg`) and **SMB2 charger** (`qcom,pm8150b-charger`) by adding a
`simple-battery` (Pixel 4a 3140 mAh cell) and `monitored-battery`. Gives
userspace capacity / voltage / current / temperature and charge status + online.

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
add them to `source=` (order 0001→0005) and their `sha512sums`
(`pmbootstrap checksum ...`), bump `pkgrel`, then
`pmbootstrap build linux-postmarketos-qcom-sm7150`. `aport/APKBUILD` is the
reference version wiring all five in (pkgrel 13). No kernel config changes are
needed — the required drivers (`SND_SOC_SDM845`, `SND_SOC_CS35L41_I2C`, QDSP6,
cs35l41, ftm5's `CONFIG_TOUCHSCREEN_FTM5`) build fine.

## sxmo

`sxmo/sxmo_deviceprofile_google,sunfish.sh` → install to
`/usr/bin/sxmo_deviceprofile_google,sunfish.sh` (`chmod +x`). Also add the user
to the `input` group so `lisgd` (edge-swipe gestures) can open `/dev/input/*`.
