#!/bin/bash

# =============================================================================
# Test Script for drills_network scene
# =============================================================================
# This script simulates BLE commands from the mobile app to test different
# target configuration scenarios in the drills_network scene.
#
# Prerequisites:
#   1. combined_server.js must be running: node combined_server.js
#   2. Godot game must be running and connected to WebSocket
#   3. Navigate to drills_network scene in the game
#
# Usage:
#   ./test_drills_network.sh [scenario]
#
# Scenarios:
#   first_only    - First target only (isFirst=true, isLast=false)
#   middle        - Middle target (isFirst=false, isLast=false)
#   last_only     - Last target, not first (isFirst=false, isLast=true)
#   single        - Single target (isFirst=true, isLast=true)
#   full_sequence - Run ready -> start -> 2 shots -> end sequence
# =============================================================================

BASE_URL="http://localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==============================================================================${NC}\n"
}

print_step() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

send_ready() {
    local is_first=$1
    local is_last=$2
    local target_type=${3:-"ipsc"}
    local timeout=${4:-30}
    local delay=${5:-5}
    
    print_step "Sending BLE READY command (isFirst=$is_first, isLast=$is_last, targetType=$target_type)"
    
    curl -s -X POST "$BASE_URL/test/ble/ready" \
        -H "Content-Type: application/json" \
        -d "{
            \"action\": \"netlink_forward\",
            \"content\": {
                \"command\": \"ready\",
                \"isFirst\": $is_first,
                \"isLast\": $is_last,
                \"targetType\": \"$target_type\",
                \"timeout\": $timeout,
                \"delay\": $delay
            },
            \"dest\": \"A\"
        }" | jq .
    
    echo ""
}

send_start() {
    local repeat=${1:-1}
    
    print_step "Sending BLE START command (repeat=$repeat)"
    
    curl -s -X POST "$BASE_URL/test/ble/start" \
        -H "Content-Type: application/json" \
        -d "{
            \"action\": \"netlink_forward\",
            \"content\": {
                \"command\": \"start\",
                \"repeat\": $repeat
            },
            \"dest\": \"A\"
        }" | jq .
    
    echo ""
}

send_end() {
    print_step "Sending BLE END command"
    
    curl -s -X POST "$BASE_URL/test/ble/end" \
        -H "Content-Type: application/json" \
        -d "{
            \"action\": \"netlink_forward\",
            \"content\": {
                \"command\": \"end\"
            },
            \"dest\": \"A\"
        }" | jq .
    
    echo ""
}

send_shot() {
    local x=${1:-960}
    local y=${2:-540}
    
    print_step "Sending SHOT at ($x, $y)"
    
    curl -s -X POST "$BASE_URL/test/ble/shot" \
        -H "Content-Type: application/json" \
        -d "{\"x\": $x, \"y\": $y}" | jq .
    
    echo ""
}

# =============================================================================
# Test Scenarios
# =============================================================================

test_first_only() {
    print_header "SCENARIO: First Target Only (isFirst=true, isLast=false)"
    echo "Expected behavior:"
    echo "  - Shot timer SHOULD be visible"
    echo "  - Final target should NOT spawn after 2 shots"
    echo "  - Drill completes on timeout or end command"
    echo ""
    
    send_ready true false "ipsc" 30 5
    sleep 1
    send_start 1
}

test_middle() {
    print_header "SCENARIO: Middle Target (isFirst=false, isLast=false)"
    echo "Expected behavior:"
    echo "  - Shot timer should NOT be visible"
    echo "  - Final target should NOT spawn after 2 shots"
    echo "  - Timer starts immediately (no shot timer delay)"
    echo ""
    
    send_ready false false "ipsc" 30 5
    sleep 1
    send_start 1
}

test_last_only() {
    print_header "SCENARIO: Last Target Only (isFirst=false, isLast=true)"
    echo "Expected behavior:"
    echo "  - Shot timer should NOT be visible"
    echo "  - Final target SHOULD spawn after 2 shots on the target"
    echo "  - Timer starts immediately (no shot timer delay)"
    echo "  - timeout_seconds = delay + timeout = 5 + 30 = 35"
    echo ""
    
    send_ready false true "ipsc" 30 5
    sleep 1
    send_start 1
}

test_single() {
    print_header "SCENARIO: Single Target (isFirst=true, isLast=true)"
    echo "Expected behavior:"
    echo "  - Shot timer SHOULD be visible"
    echo "  - Final target SHOULD spawn after 2 shots"
    echo "  - Timer waits for shot timer ready"
    echo ""
    
    send_ready true true "ipsc" 30 5
    sleep 1
    send_start 1
}

test_full_sequence() {
    print_header "SCENARIO: Full Sequence Test (2nd/Last Target)"
    echo "This test simulates the complete flow for a 2nd/last target:"
    echo "  1. Send ready command"
    echo "  2. Send start command"
    echo "  3. Wait for target to appear"
    echo "  4. Send 2 shots to trigger final target"
    echo "  5. Wait for final target"
    echo "  6. Send shot on final target (or end command)"
    echo ""
    
    # Step 1: Ready
    send_ready false true "ipsc" 30 5
    sleep 1
    
    # Step 2: Start
    send_start 1
    echo "Waiting 2 seconds for drill to start..."
    sleep 2
    
    # Step 3: First shot on last target
    print_step "Firing first shot on last target..."
    send_shot 960 540
    sleep 0.5
    
    # Step 4: Second shot on last target (should trigger final target)
    print_step "Firing second shot on last target (should spawn final target)..."
    send_shot 960 540
    echo "Waiting 1 second for final target to spawn..."
    sleep 1
    
    # Step 5: Shot on final target
    print_step "Firing shot on final target..."
    send_shot 960 540
    
    print_success "Full sequence completed!"
}

test_different_target_types() {
    print_header "SCENARIO: Test Different Target Types"
    
    local types=("ipsc" "hostage" "rotation" "paddle" "popper" "special_1" "special_2")
    
    for target_type in "${types[@]}"; do
        echo -e "${YELLOW}Testing target type: $target_type${NC}"
        send_ready false true "$target_type" 30 5
        sleep 0.5
    done
}

show_help() {
    echo "Usage: $0 [scenario]"
    echo ""
    echo "Available scenarios:"
    echo "  first_only      - Test first target only (shot timer visible)"
    echo "  middle          - Test middle target (no shot timer, no final)"
    echo "  last_only       - Test last target (no shot timer, spawns final after 2 shots)"
    echo "  single          - Test single target (shot timer + final target)"
    echo "  full_sequence   - Run complete sequence with shots"
    echo "  target_types    - Test different target types"
    echo ""
    echo "Individual commands:"
    echo "  ready           - Send ready command (prompts for parameters)"
    echo "  start           - Send start command"
    echo "  end             - Send end command"
    echo "  shot            - Send shot at center"
    echo ""
    echo "Examples:"
    echo "  $0 last_only              # Test 2nd/last target scenario"
    echo "  $0 full_sequence          # Run full test with shots"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

case "${1:-help}" in
    first_only)
        test_first_only
        ;;
    middle)
        test_middle
        ;;
    last_only)
        test_last_only
        ;;
    single)
        test_single
        ;;
    full_sequence)
        test_full_sequence
        ;;
    target_types)
        test_different_target_types
        ;;
    ready)
        echo "Enter isFirst (true/false):"
        read is_first
        echo "Enter isLast (true/false):"
        read is_last
        send_ready "$is_first" "$is_last"
        ;;
    start)
        send_start 1
        ;;
    end)
        send_end
        ;;
    shot)
        send_shot 960 540
        ;;
    help|*)
        show_help
        ;;
esac
