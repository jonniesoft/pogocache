/**
 * @file advanced_features.c
 * @brief Advanced pogocache features demonstration
 * 
 * This example demonstrates advanced pogocache features:
 * - TTL (Time-To-Live) expiration
 * - Compare-And-Swap (CAS) operations
 * - Custom eviction callbacks
 * - Batch operations
 * - Cache iteration
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "../include/pogocache/pogocache.h"

// Eviction callback to track evicted entries
static void eviction_callback(int shard, int reason, int64_t time, const void *key,
                             size_t keylen, const void *value, size_t valuelen, 
                             int64_t expires, uint32_t flags, uint64_t cas, void *udata) {
    printf("🗑️  Entry evicted - Key: %.*s, Reason: %s\n", 
           (int)keylen, (char*)key,
           reason == POGOCACHE_REASON_EXPIRED ? "EXPIRED" :
           reason == POGOCACHE_REASON_LOWMEM ? "LOW_MEMORY" : "CLEARED");
}

// Iterator callback to display cache contents
static int iter_callback(int shard, int64_t time, const void *key, size_t keylen,
                        const void *value, size_t valuelen, int64_t expires, 
                        uint32_t flags, uint64_t cas, void *udata) {
    printf("  📋 %.*s = %.*s (expires: %s, cas: %llu)\n", 
           (int)keylen, (char*)key, (int)valuelen, (char*)value,
           expires == 0 ? "never" : "yes", (unsigned long long)cas);
    return POGOCACHE_ITER_CONTINUE;
}

// Load callback for CAS operations
static void load_callback(int shard, int64_t time, const void *key, size_t keylen,
                         const void *value, size_t valuelen, int64_t expires, 
                         uint32_t flags, uint64_t cas, struct pogocache_update **update, 
                         void *udata) {
    uint64_t *cas_value = (uint64_t *)udata;
    *cas_value = cas;
}

int main() {
    printf("=== Pogocache Advanced Features Example ===\n");
    
    // Create cache with advanced options
    struct pogocache_opts opts = {
        .usecas = true,           // Enable Compare-And-Swap
        .evicted = eviction_callback,
        .nshards = 16,            // Fewer shards for demo
        .loadfactor = 75
    };
    
    struct pogocache *cache = pogocache_new(&opts);
    if (!cache) {
        fprintf(stderr, "Failed to create cache\n");
        return 1;
    }
    
    printf("✓ Advanced cache created with CAS support\n");
    
    // === TTL Operations ===
    printf("\n--- TTL (Time-To-Live) Operations ---\n");
    
    struct pogocache_store_opts ttl_opts = {
        .ttl = POGOCACHE_SECOND * 2  // 2 seconds TTL
    };
    
    pogocache_store(cache, "temp:data", 9, "temporary", 9, &ttl_opts);
    printf("✓ Stored temporary data with 2s TTL\n");
    
    // Store permanent data
    struct pogocache_store_opts perm_opts = {0};
    pogocache_store(cache, "perm:data", 9, "permanent", 9, &perm_opts);
    printf("✓ Stored permanent data\n");
    
    printf("Initial count: %zu entries\n", pogocache_count(cache, NULL));
    
    // Wait for TTL expiration
    printf("Waiting 3 seconds for TTL expiration...\n");
    sleep(3);
    
    // Trigger sweep to remove expired entries
    size_t swept, kept;
    pogocache_sweep(cache, &swept, &kept, NULL);
    printf("Sweep completed - Swept: %zu, Kept: %zu\n", swept, kept);
    printf("Final count: %zu entries\n", pogocache_count(cache, NULL));
    
    // === Compare-And-Swap Operations ===
    printf("\n--- Compare-And-Swap Operations ---\n");
    
    // Store initial value and get CAS
    pogocache_store(cache, "counter", 7, "10", 2, NULL);
    
    uint64_t cas_value = 0;
    struct pogocache_load_opts load_opts = {
        .entry = load_callback,
        .udata = &cas_value
    };
    pogocache_load(cache, "counter", 7, &load_opts);
    printf("✓ Loaded counter with CAS: %llu\n", (unsigned long long)cas_value);
    
    // Attempt CAS update with correct CAS value
    struct pogocache_store_opts cas_opts = {
        .casop = true,
        .cas = cas_value
    };
    
    int cas_result = pogocache_store(cache, "counter", 7, "20", 2, &cas_opts);
    printf("CAS update result: %s\n", 
           cas_result == POGOCACHE_REPLACED ? "SUCCESS" : "FAILED");
    
    // === Batch Operations ===
    printf("\n--- Batch Operations ---\n");
    
    struct pogocache *batch = pogocache_begin(cache);
    printf("✓ Started batch operation\n");
    
    // Perform multiple operations in batch
    for (int i = 0; i < 5; i++) {
        char key[32], value[32];
        snprintf(key, sizeof(key), "batch:item:%d", i);
        snprintf(value, sizeof(value), "value_%d", i);
        pogocache_store(batch, key, strlen(key), value, strlen(value), NULL);
    }
    
    pogocache_end(batch);  // Commit batch
    printf("✓ Batch committed with 5 operations\n");
    
    // === Cache Iteration ===
    printf("\n--- Cache Contents ---\n");
    
    struct pogocache_iter_opts iter_opts = {
        .entry = iter_callback
    };
    pogocache_iter(cache, &iter_opts);
    
    // === Cache Statistics ===
    printf("\n--- Final Statistics ---\n");
    printf("Total entries: %zu\n", pogocache_count(cache, NULL));
    printf("Total operations: %llu\n", (unsigned long long)pogocache_total(cache, NULL));
    printf("Memory usage: %zu bytes\n", pogocache_size(cache, NULL));
    
    // Cleanup
    pogocache_clear(cache, NULL);  // This will trigger eviction callbacks
    pogocache_free(cache);
    printf("\n✓ Cache cleared and freed\n");
    
    return 0;
}