/**
 * @file basic_usage.c
 * @brief Basic pogocache usage example
 * 
 * This example demonstrates the fundamental operations of pogocache:
 * - Creating a cache instance
 * - Storing key-value pairs
 * - Loading values by key
 * - Deleting entries
 * - Cache cleanup
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "../include/pogocache/pogocache.h"

// Simple callback to capture loaded values
static void load_callback(int shard, int64_t time, const void *key, size_t keylen,
                         const void *value, size_t valuelen, int64_t expires, 
                         uint32_t flags, uint64_t cas, struct pogocache_update **update, 
                         void *udata) {
    char **result = (char **)udata;
    *result = malloc(valuelen + 1);
    memcpy(*result, value, valuelen);
    (*result)[valuelen] = '\0';
}

int main() {
    printf("=== Pogocache Basic Usage Example ===\n");
    
    // Create cache with default options
    struct pogocache_opts opts = {0};
    struct pogocache *cache = pogocache_new(&opts);
    if (!cache) {
        fprintf(stderr, "Failed to create cache\n");
        return 1;
    }
    
    printf("✓ Cache created successfully\n");
    
    // Store some key-value pairs
    const char *keys[] = {"user:1", "user:2", "config:timeout"};
    const char *values[] = {"John Doe", "Jane Smith", "30"};
    
    for (int i = 0; i < 3; i++) {
        struct pogocache_store_opts store_opts = {0};
        int result = pogocache_store(cache, keys[i], strlen(keys[i]), 
                                   values[i], strlen(values[i]), &store_opts);
        
        if (result == POGOCACHE_INSERTED) {
            printf("✓ Stored: %s = %s\n", keys[i], values[i]);
        } else {
            printf("✗ Failed to store: %s\n", keys[i]);
        }
    }
    
    // Load and verify stored values
    printf("\n--- Loading Values ---\n");
    for (int i = 0; i < 3; i++) {
        char *loaded_value = NULL;
        struct pogocache_load_opts load_opts = {
            .entry = load_callback,
            .udata = &loaded_value
        };
        
        int result = pogocache_load(cache, keys[i], strlen(keys[i]), &load_opts);
        
        if (result == POGOCACHE_FOUND && loaded_value) {
            printf("✓ Loaded: %s = %s\n", keys[i], loaded_value);
            free(loaded_value);
        } else {
            printf("✗ Failed to load: %s\n", keys[i]);
        }
    }
    
    // Display cache statistics
    printf("\n--- Cache Statistics ---\n");
    size_t count = pogocache_count(cache, NULL);
    size_t size = pogocache_size(cache, NULL);
    printf("Entries: %zu\n", count);
    printf("Memory usage: %zu bytes\n", size);
    printf("Shards: %d\n", pogocache_nshards(cache));
    
    // Delete an entry
    printf("\n--- Deleting Entry ---\n");
    struct pogocache_delete_opts delete_opts = {0};
    int delete_result = pogocache_delete(cache, "user:1", strlen("user:1"), &delete_opts);
    
    if (delete_result == POGOCACHE_DELETED) {
        printf("✓ Deleted: user:1\n");
        printf("Remaining entries: %zu\n", pogocache_count(cache, NULL));
    } else {
        printf("✗ Failed to delete: user:1\n");
    }
    
    // Cleanup
    pogocache_free(cache);
    printf("\n✓ Cache cleaned up successfully\n");
    
    return 0;
}