#!/bin/bash
#
# ===============================================================================
# Client CPU Benchmark Script
# ===============================================================================
#
# Description:
#   This script benchmarks the CPU utilization on the client side while running
#   iperf3 network tests with various thread counts. It helps in understanding
#   the CPU resource requirements for different network workloads.
#
# Features:
#   - Tests with multiple thread counts (1-64 threads)
#   - Uses CPU affinity (taskset) to control which cores run the tests
#   - Implements cool-down periods between test runs
#   - Uses zero-copy mode (-Z) for maximum performance
#
# Usage:
#   ./client_cpu_benchmark.sh
#
# Requirements:
#   - iperf3 client installed
#   - Running iperf3 server on the target machine (192.168.2.1)
#   - Properly configured network interface (see nic_config.sh)
#
# Notes:
#   - Run this script alongside a CPU monitoring tool like mpstat or top
#   - For complete performance analysis, use with server_cpu_monitor.sh
#
# Author: Zhiyi Sun (with the help of GitHub Copilot)
# Last Modified: May 8, 2025
#
# ===============================================================================

# iperf3 server address
IPERF_SERVER="192.168.2.1"

# Array of thread counts to test
THREADS=(1 2 4 8 16 32 64)

# Test duration in seconds
TEST_TIME=60

# Sleep time between tests in seconds
SLEEP_TIME=10

echo "Starting iperf3 tests..."
echo "Test Duration: ${TEST_TIME}s, Sleep Time: ${SLEEP_TIME}s"

for t in "${THREADS[@]}"; do
  echo "Running test with $t threads, unlimited rate"
  taskset -c 64-127 iperf3 -c "$IPERF_SERVER" -P "$t" -t "$TEST_TIME" -Z -i 0
  echo "Sleeping for ${SLEEP_TIME} seconds..."
  sleep "$SLEEP_TIME"
done

echo "iperf3 tests finished."
