from __future__ import annotations

import asyncio
import json
import os
import socket
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable

import paho.mqtt.client as mqtt
import serial.tools.list_ports
import serial_asyncio


def _env(name: str, default: str = "") -> str:
    val = os.getenv(name)
    return default if val is None else val


def _split_csv(value: str) -> list[str]:
    return [p.strip() for p in value.split(",") if p.strip()]


@dataclass
class Settings:
    mqtt_broker: str
    mqtt_username: str
    mqtt_password: str
    scan_interval: float
    include_patterns: list[str]
    exclude_patterns: list[str]
    enable_discovery: bool
    discovery_prefix: str
    probe_command: str


def load_settings() -> Settings:
    return Settings(
        mqtt_broker=_env("MQTT_BROKER", "mqtt://homeassistant:1883"),
        mqtt_username=_env("MQTT_USERNAME", ""),
        mqtt_password=_env("MQTT_PASSWORD", ""),
        scan_interval=float(_env("SCAN_INTERVAL", "1.0")),
        include_patterns=_split_csv(_env("INCLUDE_PATTERNS", "/dev/ttyUSB*,/dev/ttyACM*")),
        exclude_patterns=_split_csv(_env("EXCLUDE_PATTERNS", "/dev/ttyS*,/dev/input*,/dev/hidraw*")),
        enable_discovery=_env("ENABLE_DISCOVERY", "true").lower() == "true",
        discovery_prefix=_env("DISCOVERY_PREFIX", "homeassistant"),
        probe_command=_env("PROBE_COMMAND", ""),
    )


def matches(path: str, patterns: Iterable[str]) -> bool:
    import fnmatch

    return any(fnmatch.fnmatch(path, pat) for pat in patterns)


def list_candidate_ports(cfg: Settings) -> list[str]:
    ports = [p.device for p in serial.tools.list_ports.comports()]
    allowed = [p for p in ports if matches(p, cfg.include_patterns) and not matches(p, cfg.exclude_patterns)]
    return sorted(set(allowed))


class SerialReader:
    def __init__(self, device: str, mqttc: mqtt.Client, topic_prefix: str, cfg: Settings) -> None:
        self.device = device
        self.mqtt = mqttc
        self.topic_prefix = topic_prefix
        self.cfg = cfg
        self.reader: asyncio.StreamReader | None = None
        self.writer: asyncio.StreamWriter | None = None
        self.task: asyncio.Task | None = None

    async def start(self) -> None:
        try:
            self.reader, self.writer = await serial_asyncio.open_serial_connection(url=self.device, baudrate=9600)
        except Exception as err:
            self._publish_status("error", str(err))
            return

        self._publish_status("connected", None)

        # Optional probe: send an identification command
        if self.cfg.probe_command and self.writer is not None:
            try:
                self.writer.write((self.cfg.probe_command + "\r\n").encode("utf-8"))
                await self.writer.drain()
            except Exception:
                pass
        self.task = asyncio.create_task(self._read_loop())

    async def stop(self) -> None:
        if self.task and not self.task.done():
            self.task.cancel()
            with contextlib.suppress(Exception):
                await self.task
        if self.writer and not self.writer.is_closing():
            self.writer.close()
            with contextlib.suppress(Exception):
                await self.writer.wait_closed()

    async def _read_loop(self) -> None:
        assert self.reader is not None
        while True:
            line = await self.reader.readline()
            if not line:
                self._publish_status("disconnected", "eof")
                break
            try:
                payload = line.decode("utf-8", errors="ignore").strip()
            except Exception:
                payload = line.hex()
            self._publish(payload)

    def _publish_status(self, state: str, error: str | None) -> None:
        msg = {"device": self.device, "state": state, "error": error, "ts": datetime.utcnow().isoformat()}
        self.mqtt.publish(f"multi_serial/{self._slug()}/status", json.dumps(msg), qos=1, retain=True)

    def _publish(self, data: str) -> None:
        msg = {"device": self.device, "data": data, "ts": datetime.utcnow().isoformat()}
        self.mqtt.publish(f"multi_serial/{self._slug()}/data", json.dumps(msg), qos=0, retain=False)
        if self.cfg.enable_discovery:
            self._ensure_discovery()

    def _slug(self) -> str:
        return self.device.replace("/", "_").replace("\\", "_")

    def _ensure_discovery(self) -> None:
        # Publish simple MQTT Discovery for a sensor showing last payload
        node_id = self._slug()
        unique_id = f"multi_serial_{node_id}"
        base = f"{self.cfg.discovery_prefix}/sensor/{node_id}/last"
        config = {
            "name": f"Serial {self.device} Last",
            "unique_id": unique_id,
            "state_topic": f"multi_serial/{node_id}/data",
            "value_template": "{{ value_json.data }}",
            "json_attributes_topic": f"multi_serial/{node_id}/status",
            "availability": [{
                "topic": f"multi_serial/{node_id}/status",
                "value_template": "{{ value_json.state }}"
            }],
        }
        self.mqtt.publish(f"{base}/config", json.dumps(config), qos=1, retain=True)


async def main_async() -> None:
    cfg = load_settings()

    # MQTT client
    client = mqtt.Client()
    if cfg.mqtt_username:
        client.username_pw_set(cfg.mqtt_username, cfg.mqtt_password or None)

    # Parse broker
    import urllib.parse as urlparse

    url = urlparse.urlparse(cfg.mqtt_broker)
    host = url.hostname or "homeassistant"
    port = url.port or 1883
    client.connect(host, port, 60)
    client.loop_start()

    readers: dict[str, SerialReader] = {}

    try:
        while True:
            wanted = set(list_candidate_ports(cfg))
            # stop removed
            for dev in list(readers.keys() - wanted):
                await readers.pop(dev).stop()
            # start new
            for dev in wanted - set(readers.keys()):
                reader = SerialReader(dev, client, "multi_serial", cfg)
                readers[dev] = reader
                await reader.start()
            await asyncio.sleep(cfg.scan_interval)
    finally:
        for r in readers.values():
            await r.stop()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    import contextlib

    try:
        asyncio.run(main_async())
    except KeyboardInterrupt:
        pass

