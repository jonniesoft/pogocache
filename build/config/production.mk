# Production build configuration  
# Optimized for performance and binary size

include ../build/config/common.mk

# Production compilation flags
CFLAGS := -O3 -flto=auto -DNDEBUG -Wall -Werror $(CFLAGS)
CFLAGS += -ffunction-sections -fdata-sections -fomit-frame-pointer
CFLAGS += -march=native -mtune=native

# Linker optimization
LDFLAGS += -flto=auto -Wl,--gc-sections -Wl,--strip-all -s

# Production-specific settings
PARALLEL_JOBS := $(NPROC)
STRIP_BINARY := true
DEBUG_SYMBOLS := false

# Disable debugging features
CFLAGS += -DNDEBUG -DNO_DEBUG_OUTPUT

# Aggressive dependency optimization
DEP_CFLAGS := -O3 -flto=auto -DNDEBUG
DEP_CONFIGURE_FLAGS := --enable-optimizations --disable-debug

# Production target
prod: $(CACHE_DIR) gitinfo deps-prod ../pogocache

../pogocache: $(DEPS) $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o ../pogocache $(OBJS) $(CLIBS)
ifeq ($(STRIP_BINARY), true)
	strip ../pogocache
endif
	@echo "Production build complete: pogocache"
	@ls -lh ../pogocache

.PHONY: prod deps-prod