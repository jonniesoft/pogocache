# Common build configuration
# This file contains shared build settings across all profiles

# Git information
GITHASH_S := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GITVERS_S := $(shell git describe --tags 2>/dev/null | sed 's/^v//' | xargs || echo "dev")

# Generate git info header
.PHONY: gitinfo
gitinfo:
	@echo 'char GITHASH[] = "$(GITHASH_S)";' > src/gitinfo.h
	@echo 'char GITVERS[] = "$(GITVERS_S)";' >> src/gitinfo.h

# Platform detection
UNAME_S := $(shell uname -s)
NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Common libraries
CLIBS += -lm

# Object files (consistent across all builds)
OBJS = sys.o cmds.o util.o buf.o stats.o conn.o args.o uring.o
OBJS += memcache.o postgres.o tls.o save.o parse.o lz4.o
OBJS += net.o xmalloc.o main.o pogocache.o resp.o http.o hashmap.o

# Dependency paths
LIBURING_PATH := ../deps/liburing/src/liburing.a
OPENSSL_SSL_PATH := ../deps/openssl/libssl.a
OPENSSL_CRYPTO_PATH := ../deps/openssl/libcrypto.a

# Cache directories
CACHE_DIR := ../build/cache
DEP_CACHE_DIR := $(CACHE_DIR)/deps
BUILD_CACHE_DIR := $(CACHE_DIR)/build

# Create cache directories
$(CACHE_DIR):
	@mkdir -p $(CACHE_DIR) $(DEP_CACHE_DIR) $(BUILD_CACHE_DIR)