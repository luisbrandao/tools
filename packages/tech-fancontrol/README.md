# tech-fancontrol

Custom (aggressive) NVIDIA GPU fan controller, Python + NVML.

Born as `/root/bin/fan-control.py` on gw.brandao: stock NVIDIA fan curves
let the boards burn before raising the fans — this one runs a steeper
temp→speed curve.

## What it does

- Polls GPU temperature every `FANCONTROL_REFRESH` seconds (default 5s).
- Sets fan speed from a custom curve; writes only when speed changes.
- Handles every fan zone per GPU (`nvmlDeviceGetNumFans`), so it works
  for one or many fans and for any number of GPUs.
- Hysteresis: ramps up immediately, slows down only after the temp drops
  below the threshold — no fan flapping at boundaries.
- Failsafe: if a temperature read fails, blasts the fans to 100% and
  keeps running (systemd also restarts it).
- Restores automatic (driver) fan control on `systemctl stop`.

## Install

```sh
dnf install ./tech-fancontrol-1.0.0-1.el10.noarch.rpm
pip install nvidia-ml-py        # provides the pynvml module
systemctl enable --now tech-fancontrol.service
```

Requires: an installed NVIDIA driver and the `pynvml` python module
(`nvidia-ml-py` from pip, or `python3-nvidia-ml-py` from EPEL).

## Configuration

`/etc/sysconfig/tech-fancontrol` (see the shipped file for all options):

```sh
FANCONTROL_CURVE="0:30 40:50 50:60 55:70 60:80 65:85 70:90 74:95 79:100"
FANCONTROL_REFRESH=5
FANCONTROL_MIN_SPEED=30
FANCONTROL_HYSTERESIS=2
FANCONTROL_POWER_LIMIT_W=280   # optional, applied at start (citrine 3090s)
FANCONTROL_PERSISTENCE=0       # 1 = nvidia persistence mode
```

Then `systemctl restart tech-fancontrol` and watch with:

```sh
journalctl -fu tech-fancontrol
```

## Building the RPM

```sh
make rpm        # noarch rpm via rpmbuild
make srpm
```

## Machines

- **gw.brandao** — 2× Quadro P6000, default curve is tuned for these.
- **citrine.brandao** — 2× RTX 3090, use a gentler curve +
  `FANCONTROL_POWER_LIMIT_W` (the 3090s are unstable at full power).
