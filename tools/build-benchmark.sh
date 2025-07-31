#!/usr/bin/env bash

# Build Performance Benchmark for PogoCacheDB
# Measures and compares build performance improvements

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/benchmark-results"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}PogoCacheDB Build Performance Benchmark${NC}"
echo "========================================"
echo ""

# Function to time a build
time_build() {
    local build_type="$1"
    local description="$2"
    local extra_flags="$3"
    
    echo -e "${YELLOW}Testing: $description${NC}"
    
    # Clean first
    cd "$PROJECT_DIR"
    make distclean > /dev/null 2>&1 || true
    
    # Time the build
    local start_time=$(date +%s.%N)
    
    if [[ -n "$extra_flags" ]]; then
        make "$build_type" $extra_flags > /dev/null 2>&1
    else
        make "$build_type" > /dev/null 2>&1
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    printf "  Time: %.2f seconds\n" "$duration"
    echo "$description,$duration" >> "$RESULTS_DIR/build_times.csv"
    
    return 0
}

# Function to test incremental build performance
test_incremental() {
    echo -e "${YELLOW}Testing: Incremental Build Performance${NC}"
    
    cd "$PROJECT_DIR"
    make distclean > /dev/null 2>&1 || true
    
    # Full build first
    local start_time=$(date +%s.%N)
    make release > /dev/null 2>&1
    local end_time=$(date +%s.%N)
    local full_duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Touch a source file
    touch src/main.c
    
    # Incremental build
    start_time=$(date +%s.%N)
    make release > /dev/null 2>&1
    end_time=$(date +%s.%N)
    local incremental_duration=$(echo "$end_time - $start_time" | bc -l)
    
    printf "  Full build: %.2f seconds\n" "$full_duration"
    printf "  Incremental: %.2f seconds\n" "$incremental_duration"
    
    local speedup=$(echo "scale=2; $full_duration / $incremental_duration" | bc -l)
    printf "  Speedup: %.1fx\n" "$speedup"
    
    echo "Full Build,$full_duration" >> "$RESULTS_DIR/build_times.csv"
    echo "Incremental Build,$incremental_duration" >> "$RESULTS_DIR/build_times.csv"
}

# Function to test parallel build scaling
test_parallel_scaling() {
    echo -e "${YELLOW}Testing: Parallel Build Scaling${NC}"
    
    local max_jobs=$(nproc)
    
    for jobs in 1 2 4 $max_jobs; do
        cd "$PROJECT_DIR"
        make distclean > /dev/null 2>&1 || true
        
        echo "  Testing with $jobs parallel jobs..."
        
        local start_time=$(date +%s.%N)
        make -j$jobs release > /dev/null 2>&1
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        printf "    Time: %.2f seconds\n" "$duration"
        echo "Parallel Build (-j$jobs),$duration" >> "$RESULTS_DIR/build_times.csv"
    done
}

# Function to test dependency caching
test_dependency_caching() {
    echo -e "${YELLOW}Testing: Dependency Caching Performance${NC}"
    
    cd "$PROJECT_DIR"
    make distclean > /dev/null 2>&1 || true
    
    # First build (no cache)
    local start_time=$(date +%s.%N)
    make release > /dev/null 2>&1
    local end_time=$(date +%s.%N)
    local no_cache_duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Clean only build artifacts, keep deps
    make clean > /dev/null 2>&1
    
    # Second build (with cached deps)
    start_time=$(date +%s.%N)
    make release > /dev/null 2>&1
    end_time=$(date +%s.%N)
    local cached_duration=$(echo "$end_time - $start_time" | bc -l)
    
    printf "  Without cache: %.2f seconds\n" "$no_cache_duration"
    printf "  With cache: %.2f seconds\n" "$cached_duration"
    
    local speedup=$(echo "scale=2; $no_cache_duration / $cached_duration" | bc -l)
    printf "  Speedup: %.1fx\n" "$speedup"
    
    echo "Build without cache,$no_cache_duration" >> "$RESULTS_DIR/build_times.csv"
    echo "Build with cache,$cached_duration" >> "$RESULTS_DIR/build_times.csv"
}

# Initialize results file
echo "Test,Duration (seconds)" > "$RESULTS_DIR/build_times.csv"

# Run benchmarks
echo "Starting build performance tests..."
echo ""

# Basic build types
time_build "debug" "Debug Build"
time_build "release" "Release Build"
time_build "profile" "Profile Build"

echo ""

# Test incremental builds
test_incremental

echo ""

# Test parallel scaling
test_parallel_scaling

echo ""

# Test dependency caching
test_dependency_caching

echo ""

# Generate summary report
echo -e "${GREEN}Benchmark Results Summary${NC}"
echo "========================="

if command -v bc >/dev/null 2>&1; then
    # Calculate statistics
    local avg_time=$(tail -n +2 "$RESULTS_DIR/build_times.csv" | cut -d',' -f2 | awk '{sum+=$1} END {print sum/NR}')
    local min_time=$(tail -n +2 "$RESULTS_DIR/build_times.csv" | cut -d',' -f2 | sort -n | head -1)
    local max_time=$(tail -n +2 "$RESULTS_DIR/build_times.csv" | cut -d',' -f2 | sort -n | tail -1)
    
    printf "Average build time: %.2f seconds\n" "$avg_time"
    printf "Fastest build: %.2f seconds\n" "$min_time"
    printf "Slowest build: %.2f seconds\n" "$max_time"
else
    echo "Install 'bc' for detailed statistics"
fi

echo ""
echo "Detailed results saved to: $RESULTS_DIR/build_times.csv"

# Generate performance recommendations
echo ""
echo -e "${BLUE}Performance Recommendations:${NC}"
echo "• Use 'make release' for production builds"
echo "• Use 'make debug' for development"
echo "• Incremental builds are significantly faster"
echo "• Dependency caching provides major speedups"
echo "• Parallel builds scale well with available cores"
echo "• Use 'make quick' for fast development iterations"

exit 0