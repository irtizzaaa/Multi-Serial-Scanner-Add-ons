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

# Enhanced settings
export DEVICE_TIMEOUT=$(bashio::config 'device_timeout')
export RETRY_ATTEMPTS=$(bashio::config 'retry_attempts')
export RETRY_DELAY=$(bashio::config 'retry_delay')
export MESSAGE_QUEUE_SIZE=$(bashio::config 'message_queue_size')
export ENABLE_DEVICE_DETECTION=$(bashio::config 'enable_device_detection')
export IDENTIFICATION_TIMEOUT=$(bashio::config 'identification_timeout')

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

# Handle array conversion more robustly
if [ "$INCLUDE_JSON" = "[]" ] || [ -z "$INCLUDE_JSON" ]; then
  export INCLUDE_PATTERNS="/dev/ttyUSB*,/dev/ttyACM*"
else
  export INCLUDE_PATTERNS=$(echo "$INCLUDE_JSON" | jq -r 'if type == "array" then join(",") else . end' 2>/dev/null || echo "/dev/ttyUSB*,/dev/ttyACM*")
fi

if [ "$EXCLUDE_JSON" = "[]" ] || [ -z "$EXCLUDE_JSON" ]; then
  export EXCLUDE_PATTERNS="/dev/ttyS*,/dev/input*,/dev/hidraw*"
else
  export EXCLUDE_PATTERNS=$(echo "$EXCLUDE_JSON" | jq -r 'if type == "array" then join(",") else . end' 2>/dev/null || echo "/dev/ttyS*,/dev/input*,/dev/hidraw*")
fi

echo "[multi_serial_scanner] include_patterns=$INCLUDE_PATTERNS"
echo "[multi_serial_scanner] exclude_patterns=$EXCLUDE_PATTERNS"
echo "[multi_serial_scanner] mqtt_broker=$MQTT_BROKER"
echo "[multi_serial_scanner] enable_device_detection=$ENABLE_DEVICE_DETECTION"

python3 -u /app/main.py

