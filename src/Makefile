# Build Configuration
# Set BUILD_TYPE=debug for development, release for production
BUILD_TYPE ?= release

# Compiler detection and optimization
CC ?= gcc
CPROCS := $(shell nproc 2>/dev/null || echo 4)
MAKEFLAGS += -j$(CPROCS)

# Base compiler flags
BASE_CFLAGS := -Wall -Wextra -Werror -std=c11

# Build-specific flags
ifeq ($(BUILD_TYPE),debug)
    CFLAGS := $(BASE_CFLAGS) -O0 -g3 -DDEBUG -fno-omit-frame-pointer
    ifdef CCSANI
        CFLAGS += -fsanitize=address -fsanitize=undefined -DCCSANI
    endif
    TARGET_SUFFIX := _debug
else ifeq ($(BUILD_TYPE),profile)
    CFLAGS := $(BASE_CFLAGS) -O2 -g -pg -DPROFILE
    TARGET_SUFFIX := _profile
else
    # Release build (default)
    CFLAGS := $(BASE_CFLAGS) -O3 -flto=auto -DNDEBUG -march=native
    TARGET_SUFFIX :=
endif

# Allow user override
CFLAGS := $(CFLAGS) $(EXTRA_CFLAGS)

# Base libraries
CLIBS += -lm

# System detection
UNAME_S := $(shell uname -s)

# Git version info with caching
GITINFO_H := gitinfo.h
GITHASH_S := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GITVERS_S := $(shell git describe --tags 2>/dev/null | sed 's/^v//' || echo "dev")

# Git version info generation with fallback
$(GITINFO_H):
	@if [ -d .git ]; then \
		echo "Updating git version info..."; \
		echo 'char GITHASH[] = "$(GITHASH_S)";' > $@; \
		echo 'char GITVERS[] = "$(GITVERS_S)";' >> $@; \
	else \
		echo "Generating fallback version info..."; \
		echo 'char GITHASH[] = "unknown";' > $@; \
		echo 'char GITVERS[] = "dev";' >> $@; \
	fi

# Dependency management with caching
DEP_DIR := ../deps
DEP_CACHE_DIR := $(DEP_DIR)/.cache

# Create dependency cache directory
$(DEP_CACHE_DIR):
	@mkdir -p $@

# liburing dependency (Linux only)
ifeq ($(UNAME_S), Linux)
ifdef NOURING
    CFLAGS += -DNOURING
else
    LIBURING_A := $(DEP_DIR)/liburing/src/liburing.a
    LIBURING_STAMP := $(DEP_CACHE_DIR)/liburing.stamp
    
    $(LIBURING_STAMP): | $(DEP_CACHE_DIR)
	@echo "Building liburing..."
	@cd $(DEP_DIR) && ./build-uring.sh
	@touch $@
    
    $(LIBURING_A): $(LIBURING_STAMP)
	@test -f $@ || (echo "liburing build failed" && exit 1)
    
    DEPS += $(LIBURING_A)
    CLIBS += $(LIBURING_A)
endif
endif

# OpenSSL dependency
ifdef NOOPENSSL
    CFLAGS += -DNOOPENSSL
else
    OPENSSL_LIBSSL := $(DEP_DIR)/openssl/libssl.a
    OPENSSL_LIBCRYPTO := $(DEP_DIR)/openssl/libcrypto.a
    OPENSSL_STAMP := $(DEP_CACHE_DIR)/openssl.stamp
    
    $(OPENSSL_STAMP): | $(DEP_CACHE_DIR)
	@echo "Building OpenSSL..."
	@cd $(DEP_DIR) && ./build-openssl.sh
	@touch $@
    
    $(OPENSSL_LIBSSL) $(OPENSSL_LIBCRYPTO): $(OPENSSL_STAMP)
	@test -f $(OPENSSL_LIBSSL) && test -f $(OPENSSL_LIBCRYPTO) || (echo "OpenSSL build failed" && exit 1)
    
    DEPS += $(OPENSSL_LIBSSL) $(OPENSSL_LIBCRYPTO)
    CLIBS += $(OPENSSL_LIBSSL) $(OPENSSL_LIBCRYPTO)
    
    ifdef USEFULLOPENSSLHEADER
        CFLAGS += -I$(DEP_DIR)/openssl/include
    endif
endif

# Object files with automatic dependency generation
SOURCES := $(wildcard *.c)
OBJS := $(SOURCES:.c=.o)
DEP_FILES := $(OBJS:.o=.d)

# Target executable
TARGET := ../pogocache$(TARGET_SUFFIX)

# Default target
all: $(TARGET)

# Include dependency files (auto-generated)
-include $(DEP_FILES)

# Compile rule with dependency generation
%.o: %.c $(GITINFO_H) | $(DEP_CACHE_DIR)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Link rule
$(TARGET): $(DEPS) $(OBJS)
	@echo "Linking $(TARGET)..."
	@$(CC) $(CFLAGS) -o $@ $(OBJS) $(CLIBS)
	@echo "Build complete: $(TARGET)"

# Build targets
.PHONY: all clean distclean debug release profile test install deps-clean help

# Development target
debug:
	@$(MAKE) BUILD_TYPE=debug

# Release target (optimized)
release:
	@$(MAKE) BUILD_TYPE=release

# Profile target
profile:
	@$(MAKE) BUILD_TYPE=profile

# Test target
test: $(TARGET)
	@echo "Running tests..."
	@cd ../tests && ./run.sh

# Install target
install: $(TARGET)
	@echo "Installing pogocache..."
	@install -D $(TARGET) /usr/local/bin/pogocache$(TARGET_SUFFIX)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf *.o *.d *.dSYM *.out *.a $(GITINFO_H)
	@rm -f ../pogocache ../pogocache_debug ../pogocache_profile

# Clean dependencies
deps-clean:
	@echo "Cleaning dependencies..."
	@rm -rf $(DEP_CACHE_DIR)
	@rm -rf ../deps/openssl/ ../deps/liburing/

# Full clean
distclean: clean deps-clean
	@echo "Cleaning downloads..."
	@rm -rf ../deps/*.tar.gz

# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Build pogocache (default: release)"
	@echo "  debug    - Build debug version with symbols"
	@echo "  release  - Build optimized release version"
	@echo "  profile  - Build profiling version"
	@echo "  test     - Build and run tests"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  clean    - Remove build artifacts"
	@echo "  deps-clean - Clean dependency cache"
	@echo "  distclean  - Full clean including downloads"
	@echo "  help     - Show this help"
	@echo ""
	@echo "Build options:"
	@echo "  BUILD_TYPE=debug|release|profile (default: release)"
	@echo "  NOURING=1     - Disable io_uring support"
	@echo "  NOOPENSSL=1   - Disable OpenSSL support"
	@echo "  CCSANI=1      - Enable AddressSanitizer (debug builds)"
	@echo "  EXTRA_CFLAGS  - Additional compiler flags"
