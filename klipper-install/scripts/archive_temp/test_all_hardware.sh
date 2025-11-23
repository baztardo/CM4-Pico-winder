#!/bin/bash
# Comprehensive Hardware Test Suite
# Tests all winder hardware components systematically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
SKIPPED=0

# Test log file
TEST_LOG="$HOME/hardware_test_log_$(date +%Y%m%d_%H%M%S).txt"

log_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    echo "[$status] $test_name: $message" | tee -a "$TEST_LOG"
    
    case "$status" in
        "PASS")
            ((PASSED++))
            echo -e "${GREEN}✓${NC} $test_name"
            ;;
        "FAIL")
            ((FAILED++))
            echo -e "${RED}✗${NC} $test_name: $message"
            ;;
        "SKIP")
            ((SKIPPED++))
            echo -e "${YELLOW}⊘${NC} $test_name: $message"
            ;;
    esac
}

check_klipper_connection() {
    echo -e "${BLUE}=== Checking Klipper Connection ===${NC}"
    
    if [ ! -S "/tmp/klippy_uds" ]; then
        log_test "Klipper Socket" "FAIL" "Socket /tmp/klippy_uds not found"
        return 1
    fi
    
    if ! python3 "$KLIPPER_INTERFACE" --info > /dev/null 2>&1; then
        log_test "Klipper Connection" "FAIL" "Cannot connect to Klipper"
        return 1
    fi
    
    log_test "Klipper Connection" "PASS" "Connected successfully"
    return 0
}

test_traverse_tmc2209() {
    echo -e "${BLUE}=== Testing Traverse TMC2209 ===${NC}"
    
    if [ -f "$SCRIPT_DIR/diagnose_tmc2209.py" ]; then
        if python3 "$SCRIPT_DIR/diagnose_tmc2209.py" > /dev/null 2>&1; then
            log_test "TMC2209 Communication" "PASS" "Driver responding"
        else
            log_test "TMC2209 Communication" "FAIL" "Driver not responding"
        fi
    else
        log_test "TMC2209 Communication" "SKIP" "Test script not found"
    fi
}

test_traverse_endstop() {
    echo -e "${BLUE}=== Testing Traverse Endstop ===${NC}"
    
    # Query toolhead to get endstop state
    STATUS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_test "Endstop Query" "PASS" "Endstop state readable"
        echo "  Endstop state: $STATUS" | tee -a "$TEST_LOG"
    else
        log_test "Endstop Query" "FAIL" "Cannot query endstop"
    fi
}

test_traverse_homing() {
    echo -e "${BLUE}=== Testing Traverse Homing ===${NC}"
    echo "  This will move the traverse motor - WATCH IT!"
    read -p "  Continue? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_test "Traverse Homing" "SKIP" "User skipped"
        return
    fi
    
    if python3 "$KLIPPER_INTERFACE" -g "G28 Y" > /dev/null 2>&1; then
        sleep 3
        log_test "Traverse Homing" "PASS" "Homing completed"
    else
        log_test "Traverse Homing" "FAIL" "Homing failed - check logs"
    fi
}

test_traverse_movement() {
    echo -e "${BLUE}=== Testing Traverse Movement ===${NC}"
    echo "  This will move the traverse - WATCH IT!"
    read -p "  Continue? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_test "Traverse Movement" "SKIP" "User skipped"
        return
    fi
    
    python3 "$KLIPPER_INTERFACE" -g "G91" > /dev/null 2>&1
    if python3 "$KLIPPER_INTERFACE" -g "G1 Y5 F100" > /dev/null 2>&1; then
        sleep 2
        log_test "Traverse Movement" "PASS" "Movement command executed"
    else
        log_test "Traverse Movement" "FAIL" "Movement failed"
    fi
}

test_bldc_pins() {
    echo -e "${BLUE}=== Testing BLDC Motor Pins ===${NC}"
    
    # Test power pin (if configured)
    if python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_power VALUE=1" > /dev/null 2>&1; then
        sleep 0.5
        python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_power VALUE=0" > /dev/null 2>&1
        log_test "BLDC Power Pin" "PASS" "Power pin control works"
    else
        log_test "BLDC Power Pin" "SKIP" "Power pin not configured"
    fi
    
    # Test direction pin
    if python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_dir VALUE=0" > /dev/null 2>&1; then
        sleep 0.2
        python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_dir VALUE=1" > /dev/null 2>&1
        log_test "BLDC Direction Pin" "PASS" "Direction pin control works"
    else
        log_test "BLDC Direction Pin" "FAIL" "Direction pin not working"
    fi
    
    # Test brake pin
    if python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_brake VALUE=1" > /dev/null 2>&1; then
        sleep 0.2
        python3 "$KLIPPER_INTERFACE" -g "SET_PIN PIN=bldc_motor_brake VALUE=0" > /dev/null 2>&1
        log_test "BLDC Brake Pin" "PASS" "Brake pin control works"
    else
        log_test "BLDC Brake Pin" "SKIP" "Brake pin not configured"
    fi
}

test_bldc_module() {
    echo -e "${BLUE}=== Testing BLDC Motor Module ===${NC}"
    
    # Query BLDC status
    if python3 "$KLIPPER_INTERFACE" -g "QUERY_BLDC" > /dev/null 2>&1; then
        log_test "BLDC Module Query" "PASS" "Module responding"
    else
        log_test "BLDC Module Query" "FAIL" "Module not responding"
    fi
}

test_angle_sensor() {
    echo -e "${BLUE}=== Testing Angle Sensor ===${NC}"
    
    # Query angle sensor
    if python3 "$KLIPPER_INTERFACE" -g "QUERY_ANGLE_SENSOR" > /dev/null 2>&1; then
        log_test "Angle Sensor Query" "PASS" "Sensor responding"
        
        # Get status via API
        STATUS=$(python3 "$KLIPPER_INTERFACE" --query angle_sensor 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "  Sensor status: $STATUS" | tee -a "$TEST_LOG"
        fi
    else
        log_test "Angle Sensor Query" "FAIL" "Sensor not responding"
    fi
}

test_hall_sensor() {
    echo -e "${BLUE}=== Testing Hall Sensor ===${NC}"
    
    # Query Hall sensor
    if python3 "$KLIPPER_INTERFACE" -g "QUERY_SPINDLE_HALL" > /dev/null 2>&1; then
        log_test "Hall Sensor Query" "PASS" "Sensor responding"
        
        # Get status via API
        STATUS=$(python3 "$KLIPPER_INTERFACE" --query spindle_hall 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "  Sensor status: $STATUS" | tee -a "$TEST_LOG"
        fi
    else
        log_test "Hall Sensor Query" "FAIL" "Sensor not responding"
    fi
}

test_winder_control() {
    echo -e "${BLUE}=== Testing Winder Control Module ===${NC}"
    
    # Query winder control
    if python3 "$KLIPPER_INTERFACE" -g "QUERY_WINDER" > /dev/null 2>&1; then
        log_test "Winder Control Query" "PASS" "Module responding"
    else
        log_test "Winder Control Query" "FAIL" "Module not responding"
    fi
}

test_all_objects() {
    echo -e "${BLUE}=== Testing All Objects Together ===${NC}"
    
    OBJECTS="winder_control,bldc_motor,angle_sensor,spindle_hall,traverse"
    STATUS=$(python3 "$KLIPPER_INTERFACE" --query "$OBJECTS" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log_test "All Objects Query" "PASS" "All objects responding"
        echo "  Status summary saved to log" | tee -a "$TEST_LOG"
    else
        log_test "All Objects Query" "FAIL" "Some objects not responding"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Hardware Testing Suite${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Test log: $TEST_LOG"
    echo ""
    
    # Initialize log
    {
        echo "Hardware Testing Log"
        echo "Date: $(date)"
        echo "Board: Manta M4P"
        echo "MCU: STM32G0B1RE"
        echo ""
    } > "$TEST_LOG"
    
    # Check prerequisites
    if ! check_klipper_connection; then
        echo -e "${RED}Cannot proceed without Klipper connection${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}=== Component Tests ===${NC}"
    echo ""
    
    # Traverse tests
    test_traverse_tmc2209
    test_traverse_endstop
    test_traverse_homing
    test_traverse_movement
    
    echo ""
    
    # BLDC tests
    test_bldc_pins
    test_bldc_module
    
    echo ""
    
    # Sensor tests
    test_angle_sensor
    test_hall_sensor
    
    echo ""
    
    # Integration tests
    test_winder_control
    test_all_objects
    
    # Summary
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Passed:  $PASSED${NC}"
    echo -e "${RED}Failed:  $FAILED${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
    echo ""
    echo "Full log: $TEST_LOG"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check log for details.${NC}"
        exit 1
    fi
}

main "$@"

