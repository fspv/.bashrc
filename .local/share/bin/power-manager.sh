#!/bin/bash

# Power-Aware Service Manager
# This script monitors power status and manages multiple user services accordingly

# Default configuration
CONFIG_FILE="${HOME}/.config/power-manager"
CHECK_INTERVAL=60 # Time in seconds between power status checks
LOG_FILE="${HOME}/.local/share/power-manager.log"
SERVICES=()
USE_USER_SERVICES=true # Set to true for systemctl --user, false for system services

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to read services from config file
read_config_file() {
    local config="$1"
    
    if [ ! -f "$config" ]; then
        log_message "Config file $config not found."
        return 1
    fi
    
    # Read services from config file (one service per line, ignoring comments and empty lines)
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace and ignore comments and empty lines
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/#.*$//')
        if [ -n "$line" ]; then
            SERVICES+=("$line")
        fi
    done < "$config"
    
    if [ ${#SERVICES[@]} -eq 0 ]; then
        log_message "No services found in config file."
        return 1
    else
        log_message "Loaded ${#SERVICES[@]} services from config file."
        return 0
    fi
}

# Function to check if a service is running
is_service_running() {
    local service_name="$1"
    if [ "$USE_USER_SERVICES" = true ]; then
        systemctl --user is-active --quiet "$service_name"
    else
        systemctl is-active --quiet "$service_name"
    fi
    return $?
}

# Function to start a service
start_service() {
    local service_name="$1"
    log_message "Starting $service_name..."
    if [ "$USE_USER_SERVICES" = true ]; then
        systemctl --user start "$service_name"
    else
        sudo systemctl start "$service_name"
    fi
    
    if is_service_running "$service_name"; then
        log_message "$service_name started successfully."
    else
        log_message "Failed to start $service_name!"
    fi
}

# Function to stop a service
stop_service() {
    local service_name="$1"
    log_message "Stopping $service_name..."
    if [ "$USE_USER_SERVICES" = true ]; then
        systemctl --user stop "$service_name"
    else
        sudo systemctl stop "$service_name"
    fi
    
    if ! is_service_running "$service_name"; then
        log_message "$service_name stopped successfully."
    else
        log_message "Failed to stop $service_name!"
    fi
}

# Function to start all services
start_all_services() {
    log_message "Starting all services..."
    for service in "${SERVICES[@]}"; do
        start_service "$service"
    done
    log_message "All services processed."
}

# Function to stop all services
stop_all_services() {
    log_message "Stopping all services..."
    for service in "${SERVICES[@]}"; do
        stop_service "$service"
    done
    log_message "All services processed."
}

# Function to check power status
is_on_ac_power() {
    # Check if system is running on AC power
    # On Ubuntu, this information is available in the /sys filesystem
    power_source=$(cat /sys/class/power_supply/*/online 2>/dev/null | grep "1")
    if [ -n "$power_source" ]; then
        return 0  # On AC power
    else
        return 1  # On battery power
    fi
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --config FILE                       Specify config file (default: ~/.config/power-manager)"
    echo "  -s, --services \"service1 service2 ...\"  Specify services to manage (space-separated list in quotes)"
    echo "  -i, --interval SECONDS                  Set check interval in seconds (default: 10)"
    echo "  -l, --log FILE                          Set log file path"
    echo "  -u, --user                              Manage user services with systemctl --user (default)"
    echo "  -S, --system                            Manage system services with sudo systemctl"
    echo "  -h, --help                              Show this help message"
    echo ""
    echo "Config file format:"
    echo "  - One service name per line"
    echo "  - Lines starting with # are treated as comments"
    echo "  - Empty lines are ignored"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--services)
            # Convert space-separated string to array
            IFS=' ' read -r -a SERVICES <<< "$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -u|--user)
            USE_USER_SERVICES=true
            shift
            ;;
        -S|--system)
            USE_USER_SERVICES=false
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# If services aren't specified via command line, try to read from config file
if [ ${#SERVICES[@]} -eq 0 ]; then
    log_message "Attempting to read services from config file: $CONFIG_FILE"
    if ! read_config_file "$CONFIG_FILE"; then
        echo "Error: No services specified. Either create a config file or use --services option."
        show_usage
    fi
fi

# Main loop
log_message "Power-Aware Service Manager started"
if [ "$USE_USER_SERVICES" = true ]; then
    log_message "Managing user services with systemctl --user"
else
    log_message "Managing system services with sudo systemctl"
fi
log_message "Managing services: ${SERVICES[*]}"

# Track previous power state to detect changes
previous_ac_state=-1  # Initialize with an invalid state to force first check

while true; do
    # Check current power state
    if is_on_ac_power; then
        current_ac_state=1  # AC power
    else
        current_ac_state=0  # Battery power
    fi
    
    # Check if power state has changed
    if [ "$current_ac_state" != "$previous_ac_state" ]; then
        if [ "$current_ac_state" -eq 1 ]; then
            log_message "AC power connected"
            start_all_services
        else
            log_message "Running on battery power"
            stop_all_services
        fi
        previous_ac_state=$current_ac_state
    fi
    
    # Wait before checking again
    sleep $CHECK_INTERVAL
done
