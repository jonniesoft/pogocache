# Testing build configuration
# Optimized for test coverage and debugging

include ../build/config/common.mk

# Testing compilation flags
CFLAGS := -O1 -g -Wall -Wextra -Werror --coverage $(CFLAGS)
CFLAGS += -DTESTING -DDEBUG -DTEST_MODE
CFLAGS += -fprofile-arcs -ftest-coverage

# Coverage linking
LDFLAGS += --coverage -lgcov

# Testing-specific settings  
PARALLEL_JOBS := 1  # Single-threaded for deterministic coverage
STRIP_BINARY := false
DEBUG_SYMBOLS := true

# Enable all test features
CFLAGS += -DTEST_VERBOSE -DTEST_MEMORY_TRACKING -DTEST_ASSERTIONS

# Moderate dependency optimization (debugging friendly)
DEP_CFLAGS := -O1 -g
DEP_CONFIGURE_FLAGS := --enable-debug --enable-testing

# Testing target
test: $(CACHE_DIR) gitinfo deps-test ../pogocache-test

../pogocache-test: $(DEPS) $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o ../pogocache-test $(OBJS) $(CLIBS)
	@echo "Testing build complete: pogocache-test"

# Coverage targets
coverage: test
	@echo "Running coverage analysis..."
	cd ../tests && ./run.sh ../pogocache-test
	gcov -r $(OBJS:.o=.c)
	lcov --capture --directory . --output-file coverage.info
	genhtml coverage.info --output-directory coverage-html
	@echo "Coverage report generated in coverage-html/"

clean-coverage:
	rm -f *.gcno *.gcda *.gcov coverage.info
	rm -rf coverage-html/

.PHONY: test deps-test coverage clean-coverage