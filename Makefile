# PogoCacheDB - High-performance caching system
# Root Makefile with optimized build coordination

# Default build type
BUILD_TYPE ?= release

# Parallel build detection
NPROCS := $(shell nproc 2>/dev/null || echo 4)
MAKEFLAGS += -j$(NPROCS)

# Forward build type to src Makefile
export BUILD_TYPE

# Primary targets
.PHONY: all debug release profile test install clean distclean deps-clean help bench

# Default target
all: release

# Build targets with parallel coordination
debug release profile:
	@echo "Building pogocache ($@)..."
	@cd src && $(MAKE) BUILD_TYPE=$@

# Test with dependency build
test: 
	@echo "Running comprehensive tests..."
	@cd src && $(MAKE) test

# Benchmarking target
bench: release
	@echo "Running performance benchmarks..."
	@cd tests && ./run.sh --bench

# Installation
install:
	@cd src && $(MAKE) install

# Cleaning targets
clean:
	@cd src && $(MAKE) clean

deps-clean:
	@cd src && $(MAKE) deps-clean

distclean:
	@cd src && $(MAKE) distclean

# Development workflow targets
.PHONY: dev quick check format modern-build modern-install modern-test

# Quick development build
dev: debug

# Fast incremental build (skip dependency checks)
quick:
	@echo "Quick build (incremental)..."
	@cd src && $(MAKE) BUILD_TYPE=debug SKIP_DEP_CHECK=1

# Code quality checks
check: test
	@echo "Running code quality checks..."
	@command -v cppcheck >/dev/null 2>&1 && cppcheck --quiet --error-exitcode=1 src/*.c || echo "cppcheck not found, skipping..."
	@command -v clang-format >/dev/null 2>&1 && find src -name "*.c" -o -name "*.h" | xargs clang-format -style=file --dry-run --Werror || echo "clang-format not found, skipping..."

# Auto-format code
format:
	@echo "Formatting code..."
	@command -v clang-format >/dev/null 2>&1 && find src -name "*.c" -o -name "*.h" | xargs clang-format -style=file -i || echo "clang-format not found, skipping..."

# Modern build system integration
.PHONY: modern-build modern-debug modern-install modern-test cmake-build cmake-clean

# Modern script-based builds
modern-build:
	@echo "Using modern build script..."
	@./scripts/build.sh

modern-debug:
	@echo "Using modern debug build..."
	@./scripts/build.sh --type debug

modern-install:
	@echo "Using modern install script..."
	@./scripts/install.sh

modern-test:
	@echo "Using modern test script..."
	@./scripts/test.sh

# CMake build support
cmake-build: build/Makefile
	@echo "Building with CMake..."
	$(MAKE) -C build

cmake-clean:
	@echo "Cleaning CMake build..."
	rm -rf build/ build-*

build/Makefile: CMakeLists.txt
	mkdir -p build
	cd build && cmake ..

# Docker builds
.PHONY: docker docker-build docker-test

docker: docker-build

docker-build:
	@echo "Building Docker image..."
	@docker build -t pogocache:latest .

docker-test: docker-build
	@echo "Testing Docker image..."
	@docker run --rm pogocache:latest --help

# Performance monitoring
.PHONY: profile-run valgrind

profile-run: profile
	@echo "Running with profiling..."
	@cd src && gprof ../pogocache_profile > ../profile.out && echo "Profile saved to profile.out"

valgrind: debug
	@echo "Running with Valgrind..."
	@cd src && valgrind --tool=memcheck --leak-check=full ../pogocache_debug --help

# Help
help:
	@echo "PogoCacheDB Build System"
	@echo "========================"
	@echo ""
	@echo "Primary targets:"
	@echo "  all       - Build optimized release version (default)"
	@echo "  debug     - Build debug version with symbols"
	@echo "  release   - Build optimized release version" 
	@echo "  profile   - Build profiling version"
	@echo "  test      - Build and run tests"
	@echo "  install   - Install to system"
	@echo ""
	@echo "Development targets:"
	@echo "  dev       - Quick debug build (alias for debug)"
	@echo "  quick     - Fast incremental build"
	@echo "  check     - Run code quality checks"
	@echo "  format    - Auto-format source code"
	@echo "  bench     - Run performance benchmarks"
	@echo ""
	@echo "Modern build targets:"
	@echo "  modern-build   - Use scripts/build.sh"
	@echo "  modern-debug   - Debug build with scripts"
	@echo "  modern-install - Install with scripts/install.sh"
	@echo "  modern-test    - Test with scripts/test.sh"
	@echo "  cmake-build    - Build using CMake"
	@echo "  cmake-clean    - Clean CMake artifacts"
	@echo ""
	@echo "Docker targets:"
	@echo "  docker    - Build Docker image"
	@echo "  docker-test - Test Docker image"
	@echo ""
	@echo "Analysis targets:"
	@echo "  profile-run - Run with gprof profiling"
	@echo "  valgrind    - Run with Valgrind memory check"
	@echo ""
	@echo "Cleaning targets:"
	@echo "  clean     - Remove build artifacts"
	@echo "  deps-clean - Clean dependency cache"
	@echo "  distclean - Full clean including downloads"
	@echo ""
	@echo "Build options:"
	@echo "  BUILD_TYPE=debug|release|profile"
	@echo "  NOURING=1     - Disable io_uring support"
	@echo "  NOOPENSSL=1   - Disable OpenSSL support"
	@echo "  CCSANI=1      - Enable AddressSanitizer"

# Forward any unrecognized targets to src Makefile
.DEFAULT:
	@cd src && $(MAKE) $@
