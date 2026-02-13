#!/usr/bin/env bash

# Main test runner - executes all test suites

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_SUITES=()

# Test suites to run
TEST_SUITES=(
    "test_colorscheme.sh"
    "test_border_scripts.sh"
    "test_configs.sh"
    "test_symlinks.sh"
    "test_integration.sh"
)

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Dotfiles Test Suite Runner          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

START_TIME=$(date +%s)

# Run each test suite
for suite in "${TEST_SUITES[@]}"; do
    SUITE_PATH="$TEST_DIR/$suite"

    if [ ! -f "$SUITE_PATH" ]; then
        echo -e "${RED}✗ Test suite not found: $suite${NC}"
        ((TOTAL_FAILED++))
        FAILED_SUITES+=("$suite (not found)")
        continue
    fi

    if [ ! -x "$SUITE_PATH" ]; then
        chmod +x "$SUITE_PATH"
    fi

    echo -e "${BLUE}Running: $suite${NC}"
    echo ""

    # Run the test suite and capture output
    SUITE_OUTPUT=$(bash "$SUITE_PATH" 2>&1)
    SUITE_EXIT_CODE=$?

    # Print the output
    echo "$SUITE_OUTPUT"
    echo ""

    # Extract pass/fail counts from output
    PASSED=$(echo "$SUITE_OUTPUT" | grep "Results:" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
    FAILED=$(echo "$SUITE_OUTPUT" | grep "Results:" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+")

    if [ -n "$PASSED" ]; then
        TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
    fi

    if [ -n "$FAILED" ]; then
        TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
    fi

    # Track failed suites
    if [ $SUITE_EXIT_CODE -ne 0 ]; then
        FAILED_SUITES+=("$suite")
    fi

    echo "---"
    echo ""
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Test Summary                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "  Total Failed: ${RED}$TOTAL_FAILED${NC}"
echo -e "  Duration: ${YELLOW}${DURATION}s${NC}"
echo ""

if [ ${#FAILED_SUITES[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Failed test suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo -e "  ${RED}- $suite${NC}"
    done
    echo ""
    exit 1
fi
