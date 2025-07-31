#!/usr/bin/env bash

# Parallel dependency builder with caching support
# Builds liburing and OpenSSL dependencies concurrently with smart caching

set -e
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Configuration
CACHE_DIR="build/cache"
DEP_CACHE_DIR="$CACHE_DIR/deps"
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}
BUILD_TYPE=${BUILD_TYPE:-"production"}

# Create cache directories
mkdir -p "$CACHE_DIR" "$DEP_CACHE_DIR"

# Logging functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Cache management functions
compute_hash() {
    local target="$1"
    case "$target" in
        liburing)
            echo "$(cat deps/build-uring.sh deps/download.sh | sha256sum | cut -d' ' -f1)-$BUILD_TYPE"
            ;;
        openssl)
            echo "$(cat deps/build-openssl.sh deps/download.sh | sha256sum | cut -d' ' -f1)-$BUILD_TYPE"
            ;;
    esac
}

is_cached() {
    local target="$1"
    local hash="$2"
    local cache_file="$DEP_CACHE_DIR/$target.hash"
    
    if [[ -f "$cache_file" ]] && [[ "$(cat "$cache_file")" == "$hash" ]]; then
        case "$target" in
            liburing)
                [[ -f "deps/liburing/src/liburing.a" ]]
                ;;
            openssl) 
                [[ -f "deps/openssl/libssl.a" ]] && [[ -f "deps/openssl/libcrypto.a" ]]
                ;;
        esac
    else
        return 1
    fi
}

update_cache() {
    local target="$1"
    local hash="$2"
    echo "$hash" > "$DEP_CACHE_DIR/$target.hash"
}

# Build function for liburing
build_liburing() {
    local hash
    hash=$(compute_hash "liburing")
    
    if is_cached "liburing" "$hash"; then
        log_info "liburing cache hit (hash: ${hash:0:8})"
        return 0
    fi
    
    log_info "Building liburing (parallel jobs: $PARALLEL_JOBS)..."
    
    cd deps
    
    # Enhanced build script with build type support
    case "$BUILD_TYPE" in
        development)
            export LIBURING_CFLAGS="-O1 -g"
            ;;
        production)
            export LIBURING_CFLAGS="-O3 -flto=auto -DNDEBUG"
            ;;
        testing)  
            export LIBURING_CFLAGS="-O1 -g --coverage"
            ;;
    esac
    
    # Download and extract
    ./download.sh https://github.com/axboe/liburing liburing 2.10 liburing-2.10
    
    if [[ ! -d "liburing" ]]; then
        rm -rf liburing/
        tar -xzf liburing-2.10.tar.gz
        mv liburing-liburing-2.10 liburing
    fi
    
    cd liburing
    
    # Configure with build type
    if [[ ! -f "config.ready" ]] || [[ "$BUILD_TYPE" != "$(cat config.ready 2>/dev/null)" ]]; then
        log_info "Configuring liburing for $BUILD_TYPE build..."
        make clean 2>/dev/null || true
        ./configure
        echo "$BUILD_TYPE" > config.ready
    fi
    
    # Build with parallel jobs
    if [[ ! -f "build.ready" ]] || [[ "$BUILD_TYPE" != "$(cat build.ready 2>/dev/null)" ]]; then
        log_info "Compiling liburing with $PARALLEL_JOBS parallel jobs..."
        make -j"$PARALLEL_JOBS" CFLAGS="$LIBURING_CFLAGS"
        echo "$BUILD_TYPE" > build.ready
    fi
    
    cd ../..
    update_cache "liburing" "$hash"
    log_info "liburing build complete (cached: ${hash:0:8})"
}

# Build function for OpenSSL
build_openssl() {
    local hash
    hash=$(compute_hash "openssl")
    
    if is_cached "openssl" "$hash"; then
        log_info "OpenSSL cache hit (hash: ${hash:0:8})"
        return 0
    fi
    
    log_info "Building OpenSSL (parallel jobs: $PARALLEL_JOBS)..."
    
    cd deps
    
    # Enhanced build script with build type support
    case "$BUILD_TYPE" in
        development)
            export OPENSSL_CFLAGS="-O1 -g"
            export OPENSSL_CONFIG_FLAGS="--debug"
            ;;
        production)
            export OPENSSL_CFLAGS="-O3 -flto=auto -DNDEBUG"
            export OPENSSL_CONFIG_FLAGS=""
            ;;
        testing)
            export OPENSSL_CFLAGS="-O1 -g --coverage" 
            export OPENSSL_CONFIG_FLAGS="--debug"
            ;;
    esac
    
    # Download and extract
    ./download.sh https://github.com/openssl/openssl openssl 3.5.0 openssl-3.5.0
    
    if [[ ! -d "openssl" ]]; then
        rm -rf openssl/
        tar -xzf openssl-3.5.0.tar.gz
        mv openssl-openssl-3.5.0 openssl
    fi
    
    cd openssl
    
    # Configure with build type and minimal feature set
    if [[ ! -f "config.ready" ]] || [[ "$BUILD_TYPE" != "$(cat config.ready 2>/dev/null)" ]]; then
        log_info "Configuring OpenSSL for $BUILD_TYPE build..."
        make clean 2>/dev/null || true
        
        ./Configure $OPENSSL_CONFIG_FLAGS \
            no-uplink no-ssl3-method no-tls1-method no-tls1_1-method \
            no-dtls1-method no-dtls1_2-method no-argon2 no-bf no-blake2 no-cast \
            no-cmac no-dsa no-idea no-md4 no-mdc2 no-ocb no-rc2 no-rc4 no-rmd160 \
            no-scrypt no-siphash no-siv no-sm2 no-sm3 no-sm4 no-whirlpool \
            no-shared no-afalgeng no-async no-capieng no-cmp no-cms \
            no-comp no-ct no-docs no-dgram no-dso no-dynamic-engine no-engine \
            no-filenames no-gost no-http no-legacy no-module no-nextprotoneg \
            no-static-engine no-tests no-thread-pool no-ts no-ui-console \
            no-quic no-padlockeng no-ssl-trace no-ocsp no-srp no-srtp \
            CFLAGS="$OPENSSL_CFLAGS"
            
        echo "$BUILD_TYPE" > config.ready
    fi
    
    # Build with parallel jobs
    if [[ ! -f "build.ready" ]] || [[ "$BUILD_TYPE" != "$(cat build.ready 2>/dev/null)" ]]; then
        log_info "Compiling OpenSSL with $PARALLEL_JOBS parallel jobs..."
        make -j"$PARALLEL_JOBS"
        echo "$BUILD_TYPE" > build.ready
    fi
    
    cd ../..
    update_cache "openssl" "$hash"
    log_info "OpenSSL build complete (cached: ${hash:0:8})"
}

# Parse command line arguments
BUILD_TYPE="production"
FORCE_REBUILD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev|--development)
            BUILD_TYPE="development"
            shift
            ;;
        --prod|--production)
            BUILD_TYPE="production"
            shift
            ;;
        --test|--testing)
            BUILD_TYPE="testing"
            shift
            ;;
        --force)
            FORCE_REBUILD="true"
            shift
            ;;
        --jobs=*)
            PARALLEL_JOBS="${1#*=}"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Clear cache if force rebuild requested
if [[ "$FORCE_REBUILD" == "true" ]]; then
    log_info "Force rebuild requested, clearing dependency cache..."
    rm -rf "$DEP_CACHE_DIR"/*.hash
    rm -rf deps/liburing/ deps/openssl/
fi

# Build dependencies in parallel
log_info "Starting parallel dependency build (type: $BUILD_TYPE, jobs: $PARALLEL_JOBS)"

build_liburing &
LIBURING_PID=$!

build_openssl &
OPENSSL_PID=$!

# Wait for both builds to complete
log_info "Waiting for dependency builds to complete..."

if wait $LIBURING_PID; then
    log_info "liburing build successful"
else
    log_error "liburing build failed"
    exit 1
fi

if wait $OPENSSL_PID; then
    log_info "OpenSSL build successful"  
else
    log_error "OpenSSL build failed"
    exit 1
fi

log_info "All dependencies built successfully!"
log_info "Cache status saved in $DEP_CACHE_DIR/"