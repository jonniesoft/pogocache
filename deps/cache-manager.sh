#!/usr/bin/env bash

# Dependency Cache Manager for PogoCacheDB
# Optimizes dependency builds with intelligent caching

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$SCRIPT_DIR/.cache"
LOG_FILE="$CACHE_DIR/build.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
    touch "$LOG_FILE"
    log "Initialized dependency cache at $CACHE_DIR"
    
    # Create parallel build detection
    if command -v nproc >/dev/null 2>&1; then
        export MAKEFLAGS="-j$(nproc)"
        log "Enabled parallel builds with $(nproc) cores"
    else
        export MAKEFLAGS="-j4"
        log "Enabled parallel builds with 4 cores (default)"
    fi
}

# Check if dependency needs rebuilding
needs_rebuild() {
    local dep_name="$1"
    local stamp_file="$CACHE_DIR/${dep_name}.stamp"
    local build_script="$SCRIPT_DIR/build-${dep_name}.sh"
    
    # Check if stamp file exists and is newer than build script
    if [[ -f "$stamp_file" && "$stamp_file" -nt "$build_script" ]]; then
        # Check if actual library files exist
        case "$dep_name" in
            "openssl")
                [[ -f "$SCRIPT_DIR/openssl/libssl.a" && -f "$SCRIPT_DIR/openssl/libcrypto.a" ]] && return 1
                ;;
            "liburing")
                [[ -f "$SCRIPT_DIR/liburing/src/liburing.a" ]] && return 1
                ;;
        esac
    fi
    
    return 0
}

# Build dependency with progress tracking
build_dependency() {
    local dep_name="$1"
    local stamp_file="$CACHE_DIR/${dep_name}.stamp"
    local build_script="$SCRIPT_DIR/build-${dep_name}.sh"
    
    if ! needs_rebuild "$dep_name"; then
        log_success "$dep_name is up to date"
        return 0
    fi
    
    log "Building $dep_name..."
    
    # Run build script with progress monitoring
    if timeout 600 "$build_script" 2>&1 | tee -a "$LOG_FILE"; then
        touch "$stamp_file"
        log_success "$dep_name built successfully"
        return 0
    else
        log_error "$dep_name build failed"
        return 1
    fi
}

# Clean specific dependency
clean_dependency() {
    local dep_name="$1"
    local stamp_file="$CACHE_DIR/${dep_name}.stamp"
    
    log "Cleaning $dep_name..."
    
    case "$dep_name" in
        "openssl")
            rm -rf "$SCRIPT_DIR/openssl/"
            ;;
        "liburing")
            rm -rf "$SCRIPT_DIR/liburing/"
            ;;
    esac
    
    rm -f "$stamp_file"
    log_success "$dep_name cleaned"
}

# Show cache status
show_status() {
    log "Dependency Cache Status:"
    echo "========================"
    
    for dep in openssl liburing; do
        local stamp_file="$CACHE_DIR/${dep}.stamp"
        if [[ -f "$stamp_file" ]]; then
            local timestamp=$(date -r "$stamp_file" '+%Y-%m-%d %H:%M:%S')
            echo -e "${GREEN}✓${NC} $dep (cached: $timestamp)"
        else
            echo -e "${RED}✗${NC} $dep (not cached)"
        fi
    done
    
    if [[ -f "$LOG_FILE" ]]; then
        echo ""
        echo "Recent build activity:"
        tail -5 "$LOG_FILE"
    fi
}

# Parallel dependency builds
build_all() {
    log "Building all dependencies in parallel..."
    
    local pids=()
    local results=()
    
    # Start builds in background
    for dep in openssl liburing; do
        if needs_rebuild "$dep"; then
            log "Starting $dep build..."
            build_dependency "$dep" &
            pids+=($!)
        else
            log_success "$dep already cached"
        fi
    done
    
    # Wait for all builds and collect results
    local success=0
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            ((success++))
        fi
    done
    
    if [[ $success -eq ${#pids[@]} ]]; then
        log_success "All dependencies built successfully"
        return 0
    else
        log_error "Some dependencies failed to build"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-build}" in
        "init")
            init_cache
            ;;
        "build")
            init_cache
            if [[ -n "$2" ]]; then
                build_dependency "$2"
            else
                build_all
            fi
            ;;
        "clean")
            if [[ -n "$2" ]]; then
                clean_dependency "$2"
            else
                log "Cleaning all cached dependencies..."
                rm -rf "$CACHE_DIR"
                rm -rf "$SCRIPT_DIR"/openssl/ "$SCRIPT_DIR"/liburing/
                log_success "All dependencies cleaned"
            fi
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h")
            echo "Dependency Cache Manager for PogoCacheDB"
            echo ""
            echo "Usage: $0 [command] [dependency]"
            echo ""
            echo "Commands:"
            echo "  build [dep]  - Build all dependencies or specific one"
            echo "  clean [dep]  - Clean all dependencies or specific one"
            echo "  status       - Show cache status"
            echo "  init         - Initialize cache system"
            echo "  help         - Show this help"
            echo ""
            echo "Dependencies: openssl, liburing"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"