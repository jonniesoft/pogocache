#!/usr/bin/env bash

# Docker build script with optimization and caching
# Supports multi-stage builds with different profiles

set -e

# Configuration
REGISTRY=${REGISTRY:-""}
IMAGE_NAME=${IMAGE_NAME:-"pogocache"}
BUILD_TYPE=${BUILD_TYPE:-"production"}
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}
CACHE_FROM=${CACHE_FROM:-""}
PUSH=${PUSH:-"false"}

# Build metadata
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
VERSION=$(git describe --tags 2>/dev/null || echo "dev")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Logging
log_info() { echo -e "\033[36m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }

# Parse command line arguments
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
        --push)
            PUSH="true"
            shift
            ;;
        --registry=*)
            REGISTRY="${1#*=}"
            shift
            ;;
        --image=*)
            IMAGE_NAME="${1#*=}"
            shift
            ;;
        --cache-from=*)
            CACHE_FROM="${1#*=}"
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

# Build configuration
if [[ -n "$REGISTRY" ]]; then
    FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME"
else
    FULL_IMAGE_NAME="$IMAGE_NAME"
fi

# Tag generation
TAGS=(
    "$FULL_IMAGE_NAME:$BUILD_TYPE"
    "$FULL_IMAGE_NAME:$BUILD_TYPE-$VERSION"
    "$FULL_IMAGE_NAME:$BUILD_TYPE-$(echo $GIT_COMMIT | cut -c1-8)"
)

# Add latest tag for production builds
if [[ "$BUILD_TYPE" == "production" ]]; then
    TAGS+=("$FULL_IMAGE_NAME:latest")
fi

# Add branch tag for development builds
if [[ "$BUILD_TYPE" == "development" && "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    TAGS+=("$FULL_IMAGE_NAME:dev-$BRANCH")
fi

log_info "Building Docker image with the following configuration:"
log_info "  Image Name: $FULL_IMAGE_NAME"
log_info "  Build Type: $BUILD_TYPE"
log_info "  Version: $VERSION"
log_info "  Git Commit: $GIT_COMMIT"
log_info "  Parallel Jobs: $PARALLEL_JOBS"
log_info "  Tags: ${TAGS[*]}"

# Build arguments
BUILD_ARGS=(
    --build-arg "BUILD_TYPE=$BUILD_TYPE"
    --build-arg "PARALLEL_JOBS=$PARALLEL_JOBS"
    --build-arg "BUILD_DATE=$BUILD_DATE"
    --build-arg "GIT_COMMIT=$GIT_COMMIT"
    --build-arg "VERSION=$VERSION"
)

# Cache configuration
if [[ -n "$CACHE_FROM" ]]; then
    BUILD_ARGS+=(--cache-from "$CACHE_FROM")
fi

# Add tags to build command
for tag in "${TAGS[@]}"; do
    BUILD_ARGS+=(-t "$tag")
done

# Build the image
log_info "Starting Docker build..."
docker build \
    -f Dockerfile.optimized \
    --target final \
    "${BUILD_ARGS[@]}" \
    .

# Build summary
log_info "Build completed successfully!"
log_info "Created tags:"
for tag in "${TAGS[@]}"; do
    log_info "  - $tag"
done

# Push images if requested
if [[ "$PUSH" == "true" ]]; then
    log_info "Pushing images to registry..."
    for tag in "${TAGS[@]}"; do
        log_info "Pushing $tag..."
        docker push "$tag"
    done
    log_info "All images pushed successfully!"
fi

# Size analysis
log_info "Image size analysis:"
docker images "$FULL_IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

log_info "Docker build script completed successfully!"