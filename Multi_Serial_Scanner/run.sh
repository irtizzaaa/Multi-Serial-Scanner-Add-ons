#!/usr/bin/with-contenv bashio
# ==============================================================================
# Start the Multi Serial Scanner add-on
# ==============================================================================

bashio::log.info "Starting Multi Serial Scanner add-on..."

# Check if we have the required files
if [ ! -f /app/main.py ]; then
    bashio::log.error "main.py not found in /app directory"
    exit 1
fi

# Set up environment variables from config
export MQTT_BROKER=$(bashio::config 'mqtt_broker')
export MQTT_USERNAME=$(bashio::config 'mqtt_username')
export MQTT_PASSWORD=$(bashio::config 'mqtt_password')
export SCAN_INTERVAL=$(bashio::config 'scan_interval')
export ENABLE_DISCOVERY=$(bashio::config 'enable_discovery')
export DISCOVERY_PREFIX=$(bashio::config 'discovery_prefix')
export PROBE_COMMAND=$(bashio::config 'probe_command')
export DEVICE_TIMEOUT=$(bashio::config 'device_timeout')
export RETRY_ATTEMPTS=$(bashio::config 'retry_attempts')
export RETRY_DELAY=$(bashio::config 'retry_delay')
export MESSAGE_QUEUE_SIZE=$(bashio::config 'message_queue_size')
export ENABLE_DEVICE_DETECTION=$(bashio::config 'enable_device_detection')
export IDENTIFICATION_TIMEOUT=$(bashio::config 'identification_timeout')

# Convert include/exclude patterns to comma-separated strings
INCLUDE_PATTERNS=$(bashio::config 'include_patterns' | jq -r 'join(",")')
EXCLUDE_PATTERNS=$(bashio::config 'exclude_patterns' | jq -r 'join(",")')
export INCLUDE_PATTERNS
export EXCLUDE_PATTERNS

bashio::log.info "Configuration loaded:"
bashio::log.info "  MQTT Broker: ${MQTT_BROKER}"
bashio::log.info "  Scan Interval: ${SCAN_INTERVAL}s"
bashio::log.info "  Include Patterns: ${INCLUDE_PATTERNS}"
bashio::log.info "  Exclude Patterns: ${EXCLUDE_PATTERNS}"
bashio::log.info "  Device Detection: ${ENABLE_DEVICE_DETECTION}"
bashio::log.info "  Device Timeout: ${DEVICE_TIMEOUT}s"

# Check if we have serial devices available
if [ -d /dev ]; then
    bashio::log.info "Available serial devices:"
    ls -la /dev/tty* 2>/dev/null || bashio::log.warning "No serial devices found"
else
    bashio::log.warning "No /dev directory found - serial device access may be limited"
fi

# Start the Python application
cd /app
exec python3 main.py

