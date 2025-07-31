// https://github.com/tidwall/pogocache
//
// Copyright 2025 Polypoint Labs, LLC. All rights reserved.
// This file is part of the Pogocache project.
// Use of this source code is governed by the AGPL that can be found in
// the LICENSE file.
//
// For alternative licensing options or general questions, please contact
// us at licensing@polypointlabs.com.
//
// Performance tuning implementation for optimal out-of-the-box configuration

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>
#include <math.h>
#include "performance_tuning.h"
#include "sys.h"
#include "xmalloc.h"

// Detect system resources for optimization decisions
struct system_resources *perf_detect_system_resources(void) {
    struct system_resources *resources = xmalloc(sizeof(struct system_resources));
    
    // Detect CPU cores
    resources->cpu_cores = sys_nprocs();
    resources->has_many_cores = resources->cpu_cores > 4;
    
    // Detect memory
    resources->total_memory = sys_memory();
    resources->available_memory = resources->total_memory; // Simplified for now
    resources->has_high_memory = resources->total_memory > PERF_HIGH_MEMORY_THRESHOLD;
    
    // Detect max file descriptors
    struct rlimit rl;
    if (getrlimit(RLIMIT_NOFILE, &rl) == 0) {
        resources->max_file_descriptors = (int)rl.rlim_max;
    } else {
        resources->max_file_descriptors = 1024; // Conservative fallback
    }
    
    return resources;
}

// Calculate optimal backlog based on system resources
int perf_calc_optimal_backlog(struct system_resources *resources) {
    int optimal = 2048; // Improved baseline from 1024
    
    // Enhanced scaling algorithm based on CPU cores and memory
    // Base scaling: 256 * cpu_cores for better concurrency handling
    optimal = 256 * resources->cpu_cores;
    
    // Memory-based adjustments
    if (resources->has_high_memory) {
        optimal = (int)(optimal * 1.5); // 50% boost for high-memory systems
    } else if (resources->total_memory < PERF_MEDIUM_MEMORY_THRESHOLD) {
        optimal = (int)(optimal * 0.75); // Reduce for low-memory systems
    }
    
    // Additional boost for many-core systems
    if (resources->has_many_cores) {
        optimal = (int)(optimal * 1.25); // 25% boost for high-core systems
    }
    
    // Ensure within bounds
    if (optimal < PERF_MIN_BACKLOG) optimal = PERF_MIN_BACKLOG;
    if (optimal > PERF_MAX_BACKLOG) optimal = PERF_MAX_BACKLOG;
    
    return optimal;
}

// Calculate optimal queue size based on system resources
int perf_calc_optimal_queuesize(struct system_resources *resources) {
    int optimal = 512; // Improved baseline from 128
    
    // Enhanced scaling: 64 events per core baseline (doubled from 32)
    optimal = resources->cpu_cores * 64;
    
    // Memory-based scaling with improved ratios
    if (resources->has_high_memory) {
        optimal = resources->cpu_cores * 128; // Doubled from 64 for high-memory systems
    } else if (resources->total_memory < PERF_MEDIUM_MEMORY_THRESHOLD) {
        optimal = resources->cpu_cores * 32; // Doubled from 16 for low-memory systems
    }
    
    // Additional scaling for modern workloads
    if (resources->cpu_cores >= 8) {
        optimal = (int)(optimal * 1.2); // 20% boost for 8+ core systems
    }
    if (resources->cpu_cores >= 16) {
        optimal = (int)(optimal * 1.3); // Additional 30% boost for 16+ core systems
    }
    
    // Ensure within bounds
    if (optimal < PERF_MIN_QUEUESIZE) optimal = PERF_MIN_QUEUESIZE;
    if (optimal > PERF_MAX_QUEUESIZE) optimal = PERF_MAX_QUEUESIZE;
    
    return optimal;
}

// Calculate optimal max connections based on system resources
int perf_calc_optimal_maxconns(struct system_resources *resources) {
    int optimal = 4096; // Improved baseline from 1024
    
    // Enhanced calculation based on available memory and file descriptors
    int memory_limit = (int)(resources->available_memory / PERF_MEMORY_PER_CONNECTION);
    int fd_limit = resources->max_file_descriptors - 256; // Reserve more FDs for system use
    
    // Use the more restrictive limit as base
    int calculated_limit = memory_limit < fd_limit ? memory_limit : fd_limit;
    
    // Improved scaling based on system capabilities
    if (resources->has_high_memory && resources->has_many_cores) {
        optimal = (int)(calculated_limit * 0.85); // Increased from 80% for better utilization
    } else if (resources->has_high_memory || resources->has_many_cores) {
        optimal = (int)(calculated_limit * 0.75); // Increased from 60% for capable systems
    } else {
        optimal = (int)(calculated_limit * 0.65); // Slightly increased for basic systems
    }
    
    // CPU-based scaling adjustment
    if (resources->cpu_cores >= 8) {
        optimal = (int)(optimal * 1.1); // 10% boost for 8+ cores
    }
    if (resources->cpu_cores >= 16) {
        optimal = (int)(optimal * 1.15); // Additional 15% boost for 16+ cores
    }
    
    // Ensure reasonable minimum regardless of calculation
    if (optimal < 2048) optimal = 2048; // Higher minimum than PERF_MIN_MAXCONNS
    
    // Ensure within bounds
    if (optimal < PERF_MIN_MAXCONNS) optimal = PERF_MIN_MAXCONNS;
    if (optimal > PERF_MAX_MAXCONNS) optimal = PERF_MAX_MAXCONNS;
    
    return optimal;
}

// Calculate optimal shard count with improved algorithm
int perf_calc_optimal_shards(struct system_resources *resources, int nthreads) {
    int optimal;
    
    // Enhanced dynamic shard calculation based on CPU cores and memory
    // Base formula: 128 shards per thread for better parallelization
    optimal = nthreads * 128;
    
    // Memory-based scaling
    if (resources->has_high_memory) {
        optimal = optimal * 2; // Double shards for high-memory systems
    } else if (resources->total_memory < PERF_MEDIUM_MEMORY_THRESHOLD) {
        optimal = optimal / 2; // Halve shards for low-memory systems
    }
    
    // CPU-specific optimizations
    if (resources->cpu_cores >= 16) {
        optimal = (int)(optimal * 1.5); // 50% more shards for high-core count
    } else if (resources->cpu_cores >= 8) {
        optimal = (int)(optimal * 1.25); // 25% more shards for medium-core count
    }
    
    // Memory constraint check with improved calculation
    size_t shard_memory_usage = optimal * PERF_MEMORY_PER_SHARD;
    size_t available_for_shards = resources->available_memory / 4; // Use 25% of memory for shards
    if (shard_memory_usage > available_for_shards) {
        optimal = (int)(available_for_shards / PERF_MEMORY_PER_SHARD);
    }
    
    // Ensure power-of-2 alignment for better cache performance
    int power_of_2 = 1;
    while (power_of_2 < optimal) {
        power_of_2 *= 2;
    }
    if (power_of_2 / 2 >= optimal * 0.75) {
        optimal = power_of_2 / 2; // Use smaller power of 2 if close enough
    } else {
        optimal = power_of_2;
    }
    
    // Ensure within bounds
    if (optimal < PERF_MIN_SHARDS) optimal = PERF_MIN_SHARDS;
    if (optimal > PERF_MAX_SHARDS) optimal = PERF_MAX_SHARDS;
    
    return optimal;
}

// Validation functions
bool perf_validate_backlog(int backlog) {
    return backlog >= PERF_MIN_BACKLOG && backlog <= PERF_MAX_BACKLOG;
}

bool perf_validate_queuesize(int queuesize) {
    return queuesize >= PERF_MIN_QUEUESIZE && queuesize <= PERF_MAX_QUEUESIZE;
}

bool perf_validate_maxconns(int maxconns, size_t available_memory) {
    if (maxconns < PERF_MIN_MAXCONNS || maxconns > PERF_MAX_MAXCONNS) {
        return false;
    }
    
    // Check if memory can support the connection count
    size_t required_memory = (size_t)maxconns * PERF_MEMORY_PER_CONNECTION;
    return required_memory < (available_memory * 0.5); // Use max 50% of memory for connections
}

bool perf_validate_shards(int nshards, int nthreads) {
    if (nshards < PERF_MIN_SHARDS || nshards > PERF_MAX_SHARDS) {
        return false;
    }
    
    // Ensure reasonable shard-to-thread ratio
    int ratio = nshards / nthreads;
    return ratio >= 4 && ratio <= 8192; // Between 4 and 8192 shards per thread
}

// Comprehensive configuration validation with performance warnings
bool perf_validate_config(int backlog, int queuesize, int maxconns, int nshards) {
    struct system_resources *resources = perf_detect_system_resources();
    
    bool valid = perf_validate_backlog(backlog) &&
                 perf_validate_queuesize(queuesize) &&
                 perf_validate_maxconns(maxconns, resources->available_memory) &&
                 perf_validate_shards(nshards, resources->cpu_cores);
    
    // Performance optimization warnings
    if (valid) {
        // Calculate optimal values for comparison
        int optimal_backlog = perf_calc_optimal_backlog(resources);
        int optimal_queuesize = perf_calc_optimal_queuesize(resources);
        int optimal_maxconns = perf_calc_optimal_maxconns(resources);
        int optimal_shards = perf_calc_optimal_shards(resources, resources->cpu_cores);
        
        // Warn if significantly below optimal
        if (backlog < optimal_backlog * 0.5) {
            printf("# Performance Warning: backlog (%d) is significantly below optimal (%d)\n", 
                   backlog, optimal_backlog);
        }
        if (queuesize < optimal_queuesize * 0.5) {
            printf("# Performance Warning: queuesize (%d) is significantly below optimal (%d)\n", 
                   queuesize, optimal_queuesize);
        }
        if (maxconns < optimal_maxconns * 0.5) {
            printf("# Performance Warning: maxconns (%d) is significantly below optimal (%d)\n", 
                   maxconns, optimal_maxconns);
        }
        if (nshards < optimal_shards * 0.5) {
            printf("# Performance Warning: shards (%d) is significantly below optimal (%d)\n", 
                   nshards, optimal_shards);
        }
    }
    
    perf_free_resources(resources);
    return valid;
}

// Generate optimal configuration
struct perf_config *perf_optimize_defaults(void) {
    struct system_resources *resources = perf_detect_system_resources();
    struct perf_config *config = xmalloc(sizeof(struct perf_config));
    
    // Calculate optimal values
    config->optimal_backlog = perf_calc_optimal_backlog(resources);
    config->optimal_queuesize = perf_calc_optimal_queuesize(resources);
    config->optimal_maxconns = perf_calc_optimal_maxconns(resources);
    config->optimal_nshards = perf_calc_optimal_shards(resources, resources->cpu_cores);
    config->auto_tuned = true;
    
    // Generate summary
    size_t summary_len = 512;
    config->tuning_summary = xmalloc(summary_len);
    snprintf(config->tuning_summary, summary_len,
        "Auto-tuned for %d cores, %.1fGB memory: "
        "backlog=%d, queuesize=%d, maxconns=%d, shards=%d",
        resources->cpu_cores,
        (double)resources->total_memory / (1024.0 * 1024.0 * 1024.0),
        config->optimal_backlog,
        config->optimal_queuesize,
        config->optimal_maxconns,
        config->optimal_nshards);
    
    perf_free_resources(resources);
    return config;
}

// Print performance recommendations
void perf_print_recommendations(struct perf_config *config) {
    printf("# Performance Tuning Recommendations:\n");
    printf("#   Backlog: %d (network accept queue)\n", config->optimal_backlog);
    printf("#   Queue Size: %d (event processing queue)\n", config->optimal_queuesize);
    printf("#   Max Connections: %d (concurrent client limit)\n", config->optimal_maxconns);
    printf("#   Shards: %d (hashmap partitions)\n", config->optimal_nshards);
    if (config->tuning_summary) {
        printf("# %s\n", config->tuning_summary);
    }
}

// Memory cleanup functions
void perf_free_config(struct perf_config *config) {
    if (config) {
        if (config->tuning_summary) {
            xfree(config->tuning_summary);
        }
        xfree(config);
    }
}

void perf_free_resources(struct system_resources *resources) {
    if (resources) {
        xfree(resources);
    }
}