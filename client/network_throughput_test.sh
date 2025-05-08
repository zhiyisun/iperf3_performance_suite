#!/bin/bash
#
# ===============================================================================
# Network Throughput Test Script (Client-Side)
# ===============================================================================
#
# Description:
#   This script runs a series of network throughput tests using iperf3 with
#   varying numbers of parallel threads. It's designed to measure the maximum
#   achievable bandwidth between this client and a remote iperf3 server.
#
# Features:
#   - Tests multiple parallel thread configurations (1-64 threads)
#   - Performs multiple iterations of each test for statistical reliability
#   - Uses CPU affinity (taskset) to control which cores run the tests
#   - Implements cool-down periods between test runs
#   - Uses zero-copy mode (-Z) for maximum performance
#
# Usage:
#   ./network_throughput_test.sh
#
# Requirements:
#   - iperf3 client installed
#   - Running iperf3 server on the target machine (192.168.2.1)
#   - Properly configured network interface (see nic_config.sh)
#
# Configuration:
#   - Edit the parallel_threads array to change thread count configurations
#   - Modify server_ip variable to point to your iperf3 server
#   - Adjust test_duration and repeat_count as needed
#
# Author: Zhiyi Sun (with the help of GitHub Copilot)
# Last Modified: May 8, 2025
#
# ===============================================================================

# Array of parallel thread counts to test
parallel_threads=(1 2 4 8 16 32 64)

# Server IP address
server_ip="192.168.2.1"

# Test duration in seconds
test_duration=60

# Number of times to repeat each command
repeat_count=3

# Sleep duration between command executions in seconds
sleep_duration=10

echo "Starting iperf3 test iterations..."

# Get the index of the last element in the parallel_threads array
last_p_threads_index=$((${#parallel_threads[@]} - 1))

# Loop through each parallel thread count
for p_index in "${!parallel_threads[@]}"; do
    p_threads="${parallel_threads[$p_index]}"
    echo "--- Testing with -P ${p_threads} parallel threads ---"

    # Loop to repeat each command
    for i in $(seq 1 $repeat_count); do
        echo "--- Running iteration ${i}/${repeat_count} for -P ${p_threads} ---"

        # Construct the command, including -Z for all cases
        command="taskset -c 64-127 iperf3 -c ${server_ip} -P ${p_threads} -t ${test_duration} -Z -i 0 -O 10"

        # Print the command being executed
        echo "Executing: ${command}"

        # Execute the command
        ${command}

        # Check if this is the very last run of the entire script
        # This is true if we are on the last parallel thread count AND the last repeat iteration
        is_last_run=false
        if [ "$p_index" -eq "$last_p_threads_index" ] && [ "$i" -eq "$repeat_count" ]; then
            is_last_run=true
        fi

        # Sleep only if it's not the very last run
        if [ "$is_last_run" = false ]; then
            echo "Sleeping for ${sleep_duration} seconds before next run..."
            sleep ${sleep_duration}
        fi

    done

    echo "--- Finished iterations for -P ${p_threads} ---"
done

echo "All iperf3 test iterations complete."
