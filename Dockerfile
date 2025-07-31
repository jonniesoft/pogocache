# syntax=docker/dockerfile:1
# Enable BuildKit for advanced caching and optimization features

###########################################
# Build Dependencies Stage
###########################################
FROM alpine:3.19 AS deps-builder
RUN apk add --no-cache \
    build-base \
    git \
    bash \
    linux-headers \
    perl \
    && rm -rf /var/cache/apk/*

WORKDIR /build

# Copy dependency build scripts first for better caching
COPY deps/download.sh deps/build-*.sh ./deps/
RUN chmod +x deps/*.sh

# Build liburing with caching - this layer will be cached if deps don't change
RUN --mount=type=cache,target=/build/deps,id=pogocache-deps \
    cd deps && \
    ./build-uring.sh && \
    ls -la

# Build OpenSSL with caching - separate layer for better cache utilization
RUN --mount=type=cache,target=/build/deps,id=pogocache-deps \
    cd deps && \
    ./build-openssl.sh && \
    ls -la

###########################################
# Source Build Stage
###########################################
FROM alpine:3.19 AS source-builder
RUN apk add --no-cache \
    build-base \
    git \
    bash \
    linux-headers \
    make \
    && rm -rf /var/cache/apk/*

WORKDIR /build

# Copy built dependencies from previous stage
COPY --from=deps-builder /build/deps /build/deps

# Copy source files (use .dockerignore to exclude unnecessary files)
COPY src/ ./src/
COPY Makefile ./

# Generate git info for version information
RUN cd src && \
    echo 'char GITHASH[] = "docker-build";' > gitinfo.h && \
    echo 'char GITVERS[] = "docker";' >> gitinfo.h

# Build the application with production optimizations
RUN --mount=type=cache,target=/root/.cache,id=pogocache-build-cache \
    cd src && \
    make clean && \
    CFLAGS="-O3 -flto=auto -march=native -DNDEBUG -s" make -j$(nproc) ../pogocache

# Verify the binary was built and get its info
RUN file /build/pogocache && \
    ldd /build/pogocache || true && \
    ls -la /build/pogocache

###########################################
# Runtime Stage (Minimal)
###########################################
FROM alpine:3.19 AS runtime

# Create non-root user for security
RUN addgroup -g 1000 pogocache && \
    adduser -D -u 1000 -G pogocache pogocache

# Install only runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Copy the binary from build stage
COPY --from=source-builder /build/pogocache /usr/local/bin/pogocache
RUN chmod +x /usr/local/bin/pogocache

# Create directories for data and logs
RUN mkdir -p /var/lib/pogocache /var/log/pogocache && \
    chown -R pogocache:pogocache /var/lib/pogocache /var/log/pogocache

# Switch to non-root user
USER pogocache

# Set working directory
WORKDIR /var/lib/pogocache

# Expose the default port
EXPOSE 9401

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pogocache --help > /dev/null || exit 1

# Use exec form for proper signal handling
ENTRYPOINT ["pogocache"]
CMD ["--help"]

###########################################
# Development Stage (Optional)
###########################################
FROM source-builder AS development
RUN apk add --no-cache \
    gdb \
    valgrind \
    strace \
    && rm -rf /var/cache/apk/*

# Build with debug symbols for development
RUN cd src && \
    make clean && \
    CFLAGS="-O0 -g3 -DDEBUG" make -j$(nproc) ../pogocache

ENTRYPOINT ["gdb", "--args", "/build/pogocache"]