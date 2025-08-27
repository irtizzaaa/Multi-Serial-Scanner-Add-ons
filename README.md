# Multi Serial Scanner Add-ons

Always-on Home Assistant add-on that scans multiple serial ports concurrently, filters out non-target devices, publishes data to MQTT, optionally sends a “Who are you?” probe per port, and exposes simple MQTT Discovery entities.

## Features
- Multi-port scanning (50+ ports; async, non-blocking)
- Include/exclude device patterns (avoids keyboards/mice/HID, etc.)
- Optional probe command sent once after connect
- MQTT publish:
  - `multi_serial/<port_slug>/status` (connected/error)
  - `multi_serial/<port_slug>/data` (last line)
- MQTT Discovery (sensor per port showing last payload)
- Always-on (Supervisor add-on), Start on boot + Watchdog

## Installation (Home Assistant)
1. Add this repository to Add-on Store:
   - Settings → Add-ons → Add-on store → Repositories → Add:
     - `https://github.com/irtizzaaa/Multi-Serial-Scanner-Add-ons`
2. Install “Multi Serial Scanner”.
3. Open the add-on → Configuration → set options → Save.
4. Start the add-on and enable “Start on boot” and “Watchdog”.

## Options
- `mqtt_broker` (string): e.g. `mqtt://homeassistant:1883`
- `mqtt_username` (string, optional)
- `mqtt_password` (string, optional)
- `scan_interval` (float): seconds between rescans (default: `1.0`)
- `include_patterns` (list): device globs to include
  - default: `["/dev/ttyUSB*","/dev/ttyACM*"]`
- `exclude_patterns` (list): device globs to exclude
  - default: `["/dev/ttyS*","/dev/input*","/dev/hidraw*"]`
- `enable_discovery` (bool): MQTT Discovery on/off (default: `true`)
- `discovery_prefix` (string): Discovery prefix (default: `homeassistant`)
- `probe_command` (string): optional one-time command to send after connect (e.g., `WHO?`)

## MQTT Topics
- Status (retain, QoS 1):
  - `multi_serial/<port_slug>/status`
  - Payload (JSON): `{"device":"/dev/ttyUSB0","state":"connected|error|disconnected","error":null,"ts":"..."}`
- Data (QoS 0):
  - `multi_serial/<port_slug>/data`
  - Payload (JSON): `{"device":"/dev/ttyUSB0","data":"...","ts":"..."}`

## Home Assistant Entities (Discovery)
- Sensor per port (“Serial <device> Last”) showing the last line received.
- Discovery topic: `homeassistant/sensor/<port_slug>/last/config`

## Verifying
- Add-on Logs: shows include/exclude patterns and connect attempts.
- In Home Assistant → MQTT → “Listen to a topic”:
  - Subscribe to `multi_serial/+/status` and `multi_serial/+/data`.
- Entities: with discovery enabled, a sensor per port appears automatically.

## Notes
- Run on HA OS/Supervised. For Core/Container users, build/run the image manually with `--device=/dev:/dev` and `--net=host`.
- If your dongle uses a different path (e.g., `/dev/ttyXRUSB0`), add it to `include_patterns`.
- Performance depends on host USB bandwidth, serial driver stability, and MQTT throughput.
