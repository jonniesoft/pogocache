# Pogocache Examples Makefile

CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -I../include
LDFLAGS = -L../
LIBS = -lpogocache -lm

# Source and target files
EXAMPLES = basic_usage advanced_features
EXAMPLE_TARGETS = $(addsuffix .out, $(EXAMPLES))

# Default target
all: $(EXAMPLE_TARGETS)

# Build individual examples
%.out: %.c
	@echo "Building example: $<"
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LIBS)

# Static linking version (when pogocache is built as static lib)
static: LDFLAGS = ../pogocache.a
static: LIBS = -lm
static: $(EXAMPLE_TARGETS)

# Clean targets
clean:
	rm -f *.out *.o

.PHONY: all static clean

# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Build all examples (requires shared library)"
	@echo "  static   - Build examples with static linking"
	@echo "  clean    - Remove built examples"
	@echo "  help     - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make all           # Build with shared library"
	@echo "  make static        # Build with static library"
	@echo "  make basic_usage.out # Build specific example"