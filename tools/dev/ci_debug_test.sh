#!/bin/bash
##
# Example CI/CD integration script for Metasploit Framework debug testing
# This script demonstrates how to integrate the debug test script into
# continuous integration pipelines or development workflows.
##

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSF_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Metasploit Framework Debug Tests ==="
echo "MSF Root: $MSF_ROOT"
echo "Timestamp: $(date)"
echo

# Change to MSF root directory
cd "$MSF_ROOT"

# Define output directory for test results
OUTPUT_DIR="${MSF_ROOT}/test_results"
mkdir -p "$OUTPUT_DIR"

# Run different types of tests based on environment or parameters
case "${1:-all}" in
    "quick")
        echo "Running quick debug tests..."
        ./tools/dev/debug_test -q -v -f json -s "${OUTPUT_DIR}/debug_quick_$(date +%Y%m%d_%H%M%S).json"
        ;;
    "modules")
        echo "Running module tests..."
        ./tools/dev/debug_test -m -v -f json -s "${OUTPUT_DIR}/debug_modules_$(date +%Y%m%d_%H%M%S).json"
        ;;
    "payloads")
        echo "Running payload tests..."
        ./tools/dev/debug_test -p -v -f json -s "${OUTPUT_DIR}/debug_payloads_$(date +%Y%m%d_%H%M%S).json"
        ;;
    "comprehensive"|"all")
        echo "Running comprehensive debug tests..."
        ./tools/dev/debug_test -A -v -f json -s "${OUTPUT_DIR}/debug_comprehensive_$(date +%Y%m%d_%H%M%S).json"
        ;;
    *)
        echo "Usage: $0 [quick|modules|payloads|comprehensive|all]"
        echo "Default: comprehensive"
        exit 1
        ;;
esac

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo
    echo "✅ Debug tests completed successfully!"
    echo "Results saved to: ${OUTPUT_DIR}/"
    ls -la "${OUTPUT_DIR}/"debug_*$(date +%Y%m%d)*.json 2>/dev/null || echo "No results files found"
else
    echo
    echo "❌ Debug tests failed with exit code: $exit_code"
    echo "Check the output above for error details"
fi

exit $exit_code