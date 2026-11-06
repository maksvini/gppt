#!/usr/bin/env python3
"""Print the next key or mouse button pressed on any input device, as JSON.

Reads evdev directly, like the daemon, so the code captured is exactly the one
the daemon will match. Prints {"code": N, "name": "KEY_..."} on a press,
{"cancel": true} on Escape or timeout, or {"error": "..."} when no device can
be read.
"""
import argparse
import json
import select
import sys
import time

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print(json.dumps({'error': 'python-evdev is not installed'}))
    sys.exit(1)

# The clicks that operate the settings popup itself, and touchpad contact
# reports, which arrive as EV_KEY but are not buttons anyone holds to talk.
IGNORED = {ecodes.BTN_LEFT, ecodes.BTN_RIGHT} | set(range(0x140, 0x150))


def key_name(code: int) -> str:
    name = ecodes.KEY.get(code) or ecodes.BTN.get(code) or f'KEY_{code}'
    if isinstance(name, (list, tuple)):
        name = name[0]
    return name


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--timeout', type=float, default=10.0)
    args = parser.parse_args()

    devices = {}
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        devices[dev.fd] = dev

    if not devices:
        print(json.dumps({'error': 'no readable input devices (input group?)'}))
        sys.exit(1)

    deadline = time.monotonic() + args.timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            print(json.dumps({'cancel': True}))
            return
        ready, _, _ = select.select(devices, [], [], remaining)
        for fd in ready:
            try:
                events = list(devices[fd].read())
            except OSError:
                del devices[fd]
                continue
            for event in events:
                if event.type != ecodes.EV_KEY or event.value != 1:
                    continue
                if event.code in IGNORED:
                    continue
                if event.code == ecodes.KEY_ESC:
                    print(json.dumps({'cancel': True}))
                    return
                print(json.dumps({'code': event.code, 'name': key_name(event.code)}))
                return


if __name__ == '__main__':
    main()
