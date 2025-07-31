# Development build configuration
# Optimized for fast compilation and debugging

include ../build/config/common.mk

# Development compilation flags
ifndef CCSANI
CFLAGS := -O0 -g3 -Wall -Wextra -Werror $(CFLAGS)
CFLAGS += -DDEBUG -DDEVEL
else
# Address sanitizer build
SFLAGS := -O0 -g3 -Wall -Wextra -Werror -fsanitize=address 
SFLAGS += -fno-omit-frame-pointer -DCCSANI -DDEBUG
CFLAGS := $(SFLAGS) $(CFLAGS)
LDFLAGS += -fsanitize=address
endif

# Development-specific settings
PARALLEL_JOBS := $(NPROC)
STRIP_BINARY := false
DEBUG_SYMBOLS := true

# Enable all debugging features
CFLAGS += -DDEBUG_VERBOSE -DDEBUG_MEMORY -DDEBUG_NETWORK

# Fast dependency building (less optimization)
DEP_CFLAGS := -O1 -g
DEP_CONFIGURE_FLAGS := --enable-debug

# Development target
dev: $(CACHE_DIR) gitinfo deps-dev ../pogocache-dev

../pogocache-dev: $(DEPS) $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o ../pogocache-dev $(OBJS) $(CLIBS)
	@echo "Development build complete: pogocache-dev"

.PHONY: dev deps-dev