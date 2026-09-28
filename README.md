# cups-ipp-usb

CUPS and [ipp-usb](https://github.com/OpenPrinting/ipp-usb) in one container,
for a USB-only printer shared from a home server.

Most modern USB printers (anything that does AirPrint over USB) expose an
**IPP-over-USB** interface. ipp-usb turns it into a local HTTP endpoint, which
gets you:

- **Driverless printing** – CUPS talks IPP to the printer itself instead of
  running a vendor or reverse-engineered raster driver.
- **Real printer status** – "out of paper", "jam", "door open" reach CUPS and
  clients, instead of a generic "Unable to send data to printer".
- **The printer's own web admin pages over USB** – change settings such as
  sleep and auto power-off without ever joining the printer to Wi-Fi.

Built on [`anujdatar/cups`](https://github.com/anujdatar/cups-docker), which
already ships the `ipp-usb` package but never starts it.

```
ghcr.io/cdilga/cups-ipp-usb:latest     # linux/amd64, linux/arm64
```

## What it adds

| Piece | Purpose |
|---|---|
| `start.sh` | Starts the supervisor, then runs the base image's entrypoint (`cupsd -f`). |
| `ipp-usb-supervisor` | Polls sysfs for printer-class USB devices and (re)starts ipp-usb when they change. See below. |
| `ipp-usb.conf` | mDNS off (CUPS already advertises the queue), listen on all container interfaces. |
| `ppd-restrict-media` | Limit a queue to the paper size actually loaded (see below). |
| `quirks/brother.conf` | USB reset before claiming a Brother HL-L2400DW, which otherwise refuses the IPP-USB alternate setting. |

### Why a supervisor instead of ipp-usb's own hotplug

ipp-usb learns about plugged/unplugged printers from kernel uevents. A
container on a bridge network is in its own network namespace and never
receives those broadcasts, so after a printer power-cycles (new USB device
number) ipp-usb would keep holding a dead handle. The supervisor polls
`/sys/bus/usb/devices` every `IPP_USB_POLL` seconds, waits for the device set
to be stable for `IPP_USB_SETTLE` seconds (printers re-enumerate several times
while booting), and restarts ipp-usb on any change.

## Running

`/dev/bus/usb` must be **bind-mounted** from the host, not passed with
`--device`. A `--device` node is a snapshot taken when the container starts;
after the printer re-enumerates, the new node never appears and libusb fails
with `LIBUSB_ERROR_NO_DEVICE`.

```yaml
services:
  cups:
    image: ghcr.io/cdilga/cups-ipp-usb:latest
    restart: unless-stopped
    ports:
      - "631:631"
      - "60000:60000"   # optional: printer web UI; omit to keep it container-local
    volumes:
      - ./cups:/etc/cups
      - /dev/bus/usb:/dev/bus/usb
      - /var/run/dbus:/var/run/dbus
    device_cgroup_rules:
      - "c 189:* rmw"   # USB device nodes
    environment:
      TZ: Australia/Brisbane
      CUPSADMIN: admin
      CUPSPASSWORD: change-me
```

Then point the queue at ipp-usb instead of the raw USB backend:

```sh
lpadmin -p MyPrinter -E -v ipp://localhost:60000/ipp/print -m everywhere
```

### Restricting paper sizes

A driverless queue advertises every size the printer claims to support, so a
client can happily send US Letter to a tray full of A4. To offer only what is
actually loaded:

```sh
ppd-restrict-media MyPrinter A4
```

`media-supported` then reports only A4, macOS offers only A4, and documents
laid out for other sizes are scaled to fit. Re-running `lpadmin -m everywhere`
regenerates the PPD and undoes this.

The printer's web admin is at `http://<host>:60000/` if you published the
port, or through `ssh -L 60000:<container-ip>:60000 <host>` if you didn't.

Only one thing may own the printer at a time: once ipp-usb is running, don't
also keep a `usb://` queue for the same device.

### Environment

| Variable | Default | |
|---|---|---|
| `IPP_USB_ENABLE` | `1` | `0` runs plain CUPS. |
| `IPP_USB_POLL` | `5` | Seconds between sysfs scans. |
| `IPP_USB_SETTLE` | `10` | Seconds the device set must be unchanged before (re)starting ipp-usb. |

Plus the base image's `CUPSADMIN`, `CUPSPASSWORD`, `TZ`.

## Licence

GPL-3.0, matching the `anujdatar/cups-docker` base. ipp-usb is BSD-2-Clause;
CUPS is Apache-2.0.
