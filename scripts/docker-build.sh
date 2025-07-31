#!/usr/bin/env bash

# Docker Build Script with BuildKit Optimization
# Implements efficient caching strategies and parallel builds

set -euo pipefail

# Configuration
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
REGISTRY_URL="${REGISTRY_URL:-}"
IMAGE_NAME="${IMAGE_NAME:-pogocache}"
BUILD_TARGET="${BUILD_TARGET:-runtime}"
CACHE_FROM="${CACHE_FROM:-true}"
PUSH_CACHE="${PUSH_CACHE:-false}"
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to build with cache optimization
build_with_cache() {
    local target=$1
    local tag_suffix=$2
    
    print_status "Building ${IMAGE_NAME}:${tag_suffix} with target=${target}"
    
    # Prepare cache arguments
    local cache_args=""
    if [[ "$CACHE_FROM" == "true" ]]; then
        cache_args="--cache-from=${IMAGE_NAME}:latest"
        cache_args="$cache_args --cache-from=${IMAGE_NAME}:cache-deps"
        cache_args="$cache_args --cache-from=${IMAGE_NAME}:cache-source"
        
        if [[ -n "$REGISTRY_URL" ]]; then
            cache_args="$cache_args --cache-from=${REGISTRY_URL}/${IMAGE_NAME}:latest"
            cache_args="$cache_args --cache-from=${REGISTRY_URL}/${IMAGE_NAME}:cache-deps"
            cache_args="$cache_args --cache-from=${REGISTRY_URL}/${IMAGE_NAME}:cache-source"
        fi
    fi
    
    # Build command with BuildKit optimizations
    docker build \
        --progress=plain \
        --target="$target" \
        --tag="${IMAGE_NAME}:${tag_suffix}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --build-arg PARALLEL_JOBS="$PARALLEL_JOBS" \
        $cache_args \
        .
    
    print_success "Built ${IMAGE_NAME}:${tag_suffix}"
}

# Function to create and push cache layers
create_cache_layers() {
    print_status "Creating cache layers for better rebuild performance"
    
    # Build and tag intermediate stages as cache layers
    docker build \
        --progress=plain \
        --target=deps-builder \
        --tag="${IMAGE_NAME}:cache-deps" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        .
    
    docker build \
        --progress=plain \
        --target=source-builder \
        --tag="${IMAGE_NAME}:cache-source" \
        --cache-from="${IMAGE_NAME}:cache-deps" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        .
    
    if [[ "$PUSH_CACHE" == "true" && -n "$REGISTRY_URL" ]]; then
        print_status "Pushing cache layers to registry"
        docker tag "${IMAGE_NAME}:cache-deps" "${REGISTRY_URL}/${IMAGE_NAME}:cache-deps"
        docker tag "${IMAGE_NAME}:cache-source" "${REGISTRY_URL}/${IMAGE_NAME}:cache-source"
        docker push "${REGISTRY_URL}/${IMAGE_NAME}:cache-deps"
        docker push "${REGISTRY_URL}/${IMAGE_NAME}:cache-source"
    fi
    
    print_success "Cache layers created"
}

# Main build function
main() {
    print_status "Starting optimized Docker build for PogOCache"
    
    # Verify BuildKit is available
    if ! docker buildx version >/dev/null 2>&1; then
        print_warning "Docker BuildKit not available, using legacy builder"
        unset DOCKER_BUILDKIT
    fi
    
    # Export environment variables
    export DOCKER_BUILDKIT
    export COMPOSE_DOCKER_CLI_BUILD
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                BUILD_TARGET="$2"
                shift 2
                ;;
            --registry)
                REGISTRY_URL="$2"
                shift 2
                ;;
            --no-cache)
                CACHE_FROM="false"
                shift
                ;;
            --push-cache)
                PUSH_CACHE="true"
                shift
                ;;
            --parallel-jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --target TARGET      Build target (runtime, development, etc.)"
                echo "  --registry URL       Registry URL for cache layers"
                echo "  --no-cache          Disable cache usage"
                echo "  --push-cache        Push cache layers to registry"
                echo "  --parallel-jobs N   Number of parallel jobs"
                echo "  --help              Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Create cache layers first
    if [[ "$CACHE_FROM" == "true" ]]; then
        create_cache_layers
    fi
    
    # Build the requested target
    case $BUILD_TARGET in
        runtime|production)
            build_with_cache "runtime" "latest"
            ;;
        development|dev)
            build_with_cache "development" "dev"
            ;;
        all)
            build_with_cache "runtime" "latest"
            build_with_cache "development" "dev"
            ;;
        *)
            build_with_cache "$BUILD_TARGET" "$BUILD_TARGET"
            ;;
    esac
    
    # Show build results
    print_status "Build completed. Images:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    # Show size comparison
    if docker images -q "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
        local size=$(docker images "${IMAGE_NAME}:latest" --format "{{.Size}}")
        print_success "Final runtime image size: $size"
    fi
    
    print_success "Docker build optimization complete!"
}

# Run main function with all arguments
main "$@"