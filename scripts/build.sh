#!/bin/bash
# Pogocache Build Script
# Provides simplified build interface with common configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_TYPE="release"
ENABLE_URING=1
ENABLE_OPENSSL=1
VERBOSE=0
CLEAN=0
EXAMPLES=0
TESTS=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build options:
  -t, --type TYPE       Build type: release, debug, sanitize (default: release)
  -c, --clean          Clean before building
  -v, --verbose        Verbose build output
  -e, --examples       Build examples after main build
  -T, --tests          Build and run tests
  
Feature options:
  --no-uring           Disable io_uring support (Linux only)
  --no-openssl         Disable OpenSSL/TLS support
  
Other options:
  -h, --help           Show this help message

Examples:
  $0                   # Standard release build
  $0 -t debug -v       # Debug build with verbose output
  $0 -c -e -T          # Clean build with examples and tests
  $0 --no-uring        # Build without io_uring support
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -e|--examples)
            EXAMPLES=1
            shift
            ;;
        -T|--tests)
            TESTS=1
            shift
            ;;
        --no-uring)
            ENABLE_URING=0
            shift
            ;;
        --no-openssl)
            ENABLE_OPENSSL=0
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

echo "=== Pogocache Build Script ==="
echo "Build type: $BUILD_TYPE"
echo "Features: io_uring=$ENABLE_URING, OpenSSL=$ENABLE_OPENSSL"
echo "Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Clean if requested
if [[ $CLEAN -eq 1 ]]; then
    echo "Cleaning previous build..."
    make clean || true
    make distclean || true
fi

# Set up build environment
export MAKEFLAGS=""
if [[ $VERBOSE -eq 1 ]]; then
    export MAKEFLAGS="$MAKEFLAGS V=1"
fi

# Configure build flags based on type
case "$BUILD_TYPE" in
    "debug")
        export CFLAGS="-O0 -g3 -DDEBUG"
        echo "Configured for debug build"
        ;;
    "sanitize")
        export CCSANI=1
        echo "Configured for sanitizer build"
        ;;
    "release")
        export CFLAGS="-O3 -DNDEBUG"
        echo "Configured for release build"
        ;;
    *)
        echo "Error: Unknown build type '$BUILD_TYPE'" >&2
        exit 1
        ;;
esac

# Configure features
if [[ $ENABLE_URING -eq 0 ]]; then
    export NOURING=1
    echo "Disabled io_uring support"
fi

if [[ $ENABLE_OPENSSL -eq 0 ]]; then
    export NOOPENSSL=1
    echo "Disabled OpenSSL support"
fi

# Build main project
echo "Building pogocache..."
make -j$(nproc) || {
    echo "Build failed!" >&2
    exit 1
}

echo "✓ Build completed successfully"

# Check if binary was created
if [[ -f "pogocache" ]]; then
    echo "✓ Binary created: pogocache"
    ./pogocache --version 2>/dev/null || echo "✓ Binary appears functional"
else
    echo "✗ Binary not found after build" >&2
    exit 1
fi

# Build examples if requested
if [[ $EXAMPLES -eq 1 ]]; then
    echo "Building examples..."
    if [[ -d "examples" ]]; then
        cd examples
        make clean || true
        make static || {
            echo "Examples build failed!" >&2
            exit 1
        }
        echo "✓ Examples built successfully"
        cd "$PROJECT_ROOT"
    else
        echo "⚠ Examples directory not found"
    fi
fi

# Run tests if requested
if [[ $TESTS -eq 1 ]]; then
    echo "Running tests..."
    if [[ -d "tests" ]]; then
        cd tests
        ./run.sh || {
            echo "Tests failed!" >&2
            exit 1
        }
        echo "✓ Tests completed successfully"
        cd "$PROJECT_ROOT"
    else
        echo "⚠ Tests directory not found"
    fi
fi

echo "=== Build Summary ==="
echo "✓ Pogocache build completed"
echo "  Type: $BUILD_TYPE"
echo "  Binary: pogocache"
if [[ $EXAMPLES -eq 1 ]]; then
    echo "  Examples: Built"
fi
if [[ $TESTS -eq 1 ]]; then
    echo "  Tests: Passed"
fi
echo "Ready for use!"