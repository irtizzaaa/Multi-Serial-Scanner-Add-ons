#!/usr/bin/with-contenv bashio

echo "[multi_serial_scanner] Starting..."

# Export options to env for the app
export MQTT_BROKER=$(bashio::config 'mqtt_broker')
export MQTT_USERNAME=$(bashio::config 'mqtt_username')
export MQTT_PASSWORD=$(bashio::config 'mqtt_password')
export SCAN_INTERVAL=$(bashio::config 'scan_interval')
export ENABLE_DISCOVERY=$(bashio::config 'enable_discovery')
export DISCOVERY_PREFIX=$(bashio::config 'discovery_prefix')
export PROBE_COMMAND=$(bashio::config 'probe_command')

# Convert json arrays to csv envs (robust if unset)
INCLUDE_JSON=$(bashio::config 'include_patterns')
EXCLUDE_JSON=$(bashio::config 'exclude_patterns')

# Defaults if not provided
if [ -z "$INCLUDE_JSON" ] || [ "$INCLUDE_JSON" = "null" ]; then
  INCLUDE_JSON='["/dev/ttyUSB*","/dev/ttyACM*"]'
fi
if [ -z "$EXCLUDE_JSON" ] || [ "$EXCLUDE_JSON" = "null" ]; then
  EXCLUDE_JSON='["/dev/ttyS*","/dev/input*","/dev/hidraw*"]'
fi

export INCLUDE_PATTERNS=$(echo "$INCLUDE_JSON" | jq -r 'try (join(",")) catch ""')
export EXCLUDE_PATTERNS=$(echo "$EXCLUDE_JSON" | jq -r 'try (join(",")) catch ""')

echo "[multi_serial_scanner] include_patterns=$INCLUDE_PATTERNS"
echo "[multi_serial_scanner] exclude_patterns=$EXCLUDE_PATTERNS"

python3 -u /app/main.py

