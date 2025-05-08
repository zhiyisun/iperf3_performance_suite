#!/bin/bash -
#
# ===============================================================================
# Server CPU Monitoring Script
# ===============================================================================
#
# Description:
#   This script monitors CPU utilization on the server side during network
#   benchmarking tests. It uses mpstat to track CPU usage for a specific range
#   of cores and calculates the total CPU utilization across those cores.
#
# Features:
#   - Real-time monitoring of CPU utilization with 1-second intervals
#   - Focused monitoring on a specific range of CPU cores (96-127)
#   - Calculates and displays total CPU utilization percentage
#   - Processes mpstat output in real-time for immediate feedback
#
# Usage:
#   ./server_cpu_monitor.sh
#   (Press Ctrl+C to stop monitoring)
#
# Requirements:
#   - mpstat utility (part of the sysstat package)
#   - Run this script on the server side while running benchmarks
#
# Output:
#   Timestamp - Total CPU utilization for cores 96-127: XX.XX%
#
# Notes:
#   - This script should be run on the server while client benchmarking
#     scripts are running to correlate network load with CPU utilization
#   - Modify START_CORE and END_CORE variables to adjust the monitored range
#
# Author: Zhiyi Sun (with the help of GitHub Copilot)
# Last Modified: May 8, 2025
#
# ===============================================================================

# Define the core range
START_CORE=96
END_CORE=127
NUM_CORES=$((END_CORE - START_CORE + 1))

echo "Starting mpstat monitoring for cores ${START_CORE}-${END_CORE}..."

# Initialize variables for the first interval
current_timestamp=""
idle_sum=0
core_count=0

# mpstat command to monitor cores 96-127 at 1-second intervals
# We pipe the output to a while loop for processing
mpstat -P ${START_CORE}-${END_CORE} 1 | while read -r line
do
    # Skip empty lines and the initial header line containing "CPU"
    if [[ -z "$line" ]] || [[ "$line" =~ CPU ]]; then
        continue
    fi

    # Extract the timestamp from the beginning of the line
    # Assuming timestamp is in the format HH:MM:SS AM/PM
    line_timestamp=$(echo "$line" | awk '{print $1}')

    # Check if the timestamp has changed, indicating a new interval
    if [[ "$current_timestamp" != "" ]] && [[ "$line_timestamp" != "$current_timestamp" ]]; then
        # Process the data from the previous interval
        if [ "$core_count" -gt 0 ]; then # Only process if we collected data
            total_utilization=$(awk "BEGIN {print ($NUM_CORES * 100) - $idle_sum}")
            printf "%s - Total CPU utilization for cores %d-%d: %.2f%%\n" "$current_timestamp" "$START_CORE" "$END_CORE" "$total_utilization"
        fi

        # Reset for the new interval
        idle_sum=0
        core_count=0
    fi

    # Update the current timestamp
    current_timestamp="$line_timestamp"

    # Extract the CPU number and idle percentage from the line
    # We use awk to handle variable spacing and extract the relevant columns.
    # Assuming the format is consistent after the timestamp
    cpu=$(echo "$line" | awk '{print $2}') # CPU is now the 3rd field after timestamp
    idle=$(echo "$line" | awk '{print $NF}') # %idle is still the last field

    # Check if the extracted CPU is within our desired range and the idle value is numeric
    if (( cpu >= START_CORE && cpu <= END_CORE )) && [[ "$idle" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        # Add the idle percentage to the sum
        idle_sum=$(awk "BEGIN {print $idle_sum + $idle}")
        core_count=$((core_count + 1))
    fi
done

# After the loop finishes (e.g., script is stopped), process any remaining data
if [ "$core_count" -gt 0 ]; then
    total_utilization=$(awk "BEGIN {print ($NUM_CORES * 100) - $idle_sum}")
    printf "%s - Total CPU utilization for cores %d-%d: %.2f%%\n" "$current_timestamp" "$START_CORE" "$END_CORE" "$total_utilization"
fi
