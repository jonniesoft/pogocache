#!/bin/bash
# Pogocache Test Runner Script
# Comprehensive testing with different configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUN_UNIT_TESTS=1
RUN_INTEGRATION_TESTS=1
RUN_PERFORMANCE_TESTS=0
RUN_SANITIZER_TESTS=0
VERBOSE=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test options:
  -u, --unit-only      Run unit tests only
  -i, --integration    Run integration tests only
  -p, --performance    Run performance benchmarks
  -s, --sanitizer      Run tests with address sanitizer
  -v, --verbose        Verbose test output
  -a, --all           Run all tests including performance
  
Other options:
  -h, --help          Show this help message

Examples:
  $0                  # Run standard tests
  $0 -a               # Run all tests
  $0 -s -v            # Sanitizer tests with verbose output
  $0 -p               # Performance benchmarks only
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit-only)
            RUN_INTEGRATION_TESTS=0
            shift
            ;;
        -i|--integration)
            RUN_UNIT_TESTS=0
            shift
            ;;
        -p|--performance)
            RUN_UNIT_TESTS=0
            RUN_INTEGRATION_TESTS=0
            RUN_PERFORMANCE_TESTS=1
            shift
            ;;
        -s|--sanitizer)
            RUN_SANITIZER_TESTS=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -a|--all)
            RUN_UNIT_TESTS=1
            RUN_INTEGRATION_TESTS=1
            RUN_PERFORMANCE_TESTS=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

echo "=== Pogocache Test Runner ==="
echo "Unit tests: $RUN_UNIT_TESTS"
echo "Integration tests: $RUN_INTEGRATION_TESTS"
echo "Performance tests: $RUN_PERFORMANCE_TESTS"
echo "Sanitizer tests: $RUN_SANITIZER_TESTS"

cd "$PROJECT_ROOT"

# Ensure we have a built binary
if [[ ! -f "pogocache" ]]; then
    echo "Building pogocache for tests..."
    make clean || true
    make -j$(nproc) || {
        echo "Build failed!" >&2
        exit 1
    }
fi

TESTS_PASSED=0
TESTS_FAILED=0

run_test_suite() {
    local suite_name="$1"
    local test_command="$2"
    
    echo ""
    echo "--- Running $suite_name ---"
    
    if [[ $VERBOSE -eq 1 ]]; then
        echo "Command: $test_command"
    fi
    
    if eval "$test_command"; then
        echo "✓ $suite_name PASSED"
        ((TESTS_PASSED++))
    else
        echo "✗ $suite_name FAILED"
        ((TESTS_FAILED++))
    fi
}

# Build sanitizer version if needed
if [[ $RUN_SANITIZER_TESTS -eq 1 ]]; then
    echo "Building sanitizer version..."
    make clean
    CCSANI=1 make -j$(nproc) || {
        echo "Sanitizer build failed!" >&2
        exit 1
    }
    echo "✓ Sanitizer version built"
fi

# Run unit tests
if [[ $RUN_UNIT_TESTS -eq 1 ]]; then
    if [[ -d "tests" ]]; then
        cd tests
        
        # Basic functionality tests
        run_test_suite "RESP Protocol Tests" "go test -v -run TestResp"
        run_test_suite "Memcache Protocol Tests" "go test -v -run TestMemcache"
        run_test_suite "HTTP Protocol Tests" "go test -v -run TestHTTP"
        run_test_suite "PostgreSQL Protocol Tests" "go test -v -run TestPostgres"
        
        cd "$PROJECT_ROOT"
    else
        echo "⚠ No tests directory found, skipping unit tests"
    fi
fi

# Run integration tests
if [[ $RUN_INTEGRATION_TESTS -eq 1 ]]; then
    # Test with examples if available
    if [[ -d "examples" ]]; then
        echo ""
        echo "--- Running Integration Tests ---"
        
        # Build examples
        cd examples
        make clean || true
        make static || {
            echo "Example build failed!" >&2
            cd "$PROJECT_ROOT"
            ((TESTS_FAILED++))
        }
        
        # Test basic usage example
        if [[ -f "basic_usage.out" ]]; then
            run_test_suite "Basic Usage Example" "./basic_usage.out"
        fi
        
        # Test advanced features example
        if [[ -f "advanced_features.out" ]]; then
            run_test_suite "Advanced Features Example" "./advanced_features.out"
        fi
        
        cd "$PROJECT_ROOT"
    fi
    
    # Test pogocache binary directly
    run_test_suite "Binary Help Output" "./pogocache --help"
    run_test_suite "Binary Version Output" "./pogocache --version"
fi

# Run performance tests
if [[ $RUN_PERFORMANCE_TESTS -eq 1 ]]; then
    echo ""
    echo "--- Running Performance Tests ---"
    
    # Basic performance test with Go tests
    if [[ -d "tests" ]]; then
        cd tests
        run_test_suite "Performance Benchmarks" "go test -bench=. -benchtime=5s"
        cd "$PROJECT_ROOT"
    fi
    
    # Memory usage test
    if command -v valgrind >/dev/null 2>&1; then
        run_test_suite "Memory Leak Test" "valgrind --leak-check=full --error-exitcode=1 ./pogocache --help"
    else
        echo "⚠ Valgrind not available, skipping memory leak test"
    fi
fi

# Sanitizer-specific tests
if [[ $RUN_SANITIZER_TESTS -eq 1 ]]; then
    echo ""
    echo "--- Running Sanitizer Tests ---"
    
    # Run with address sanitizer
    export ASAN_OPTIONS="abort_on_error=1:detect_leaks=1"
    run_test_suite "Address Sanitizer Test" "./pogocache --help"
    
    if [[ -d "tests" ]]; then
        cd tests
        run_test_suite "Sanitizer Protocol Tests" "./run.sh"
        cd "$PROJECT_ROOT"
    fi
fi

# Test Summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Total tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed!"
    exit 1
fi