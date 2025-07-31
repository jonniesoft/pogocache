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
// Performance tuning utilities for optimal out-of-the-box configuration

#ifndef PERFORMANCE_TUNING_H
#define PERFORMANCE_TUNING_H

#include <stddef.h>
#include <stdbool.h>

// Performance tuning configuration structure
struct perf_config {
    int optimal_backlog;       // Optimized network backlog
    int optimal_queuesize;     // Optimized event queue size  
    int optimal_maxconns;      // Optimized max connections
    int optimal_nshards;       // Optimized shard count
    bool auto_tuned;           // Whether values were auto-tuned
    char *tuning_summary;      // Human-readable tuning summary
};

// System resource information for tuning
struct system_resources {
    int cpu_cores;             // Number of available CPU cores
    size_t total_memory;       // Total system memory in bytes
    size_t available_memory;   // Available memory in bytes
    int max_file_descriptors;  // Maximum file descriptors
    bool has_high_memory;      // System has >4GB memory
    bool has_many_cores;       // System has >4 CPU cores
};

// Performance tuning functions
struct perf_config *perf_optimize_defaults(void);
struct system_resources *perf_detect_system_resources(void);
bool perf_validate_config(int backlog, int queuesize, int maxconns, int nshards);
void perf_print_recommendations(struct perf_config *config);
void perf_free_config(struct perf_config *config);
void perf_free_resources(struct system_resources *resources);

// Specific optimization functions
int perf_calc_optimal_backlog(struct system_resources *resources);
int perf_calc_optimal_queuesize(struct system_resources *resources);
int perf_calc_optimal_maxconns(struct system_resources *resources);
int perf_calc_optimal_shards(struct system_resources *resources, int nthreads);

// Runtime validation and adjustment
bool perf_validate_backlog(int backlog);
bool perf_validate_queuesize(int queuesize);
bool perf_validate_maxconns(int maxconns, size_t available_memory);
bool perf_validate_shards(int nshards, int nthreads);

// Enhanced performance constants for better out-of-the-box performance
#define PERF_MIN_BACKLOG          256   // Increased from 128 for better concurrency
#define PERF_MAX_BACKLOG          16384 // Increased from 8192 for high-performance systems
#define PERF_MIN_QUEUESIZE        64    // Increased from 32 for better throughput
#define PERF_MAX_QUEUESIZE        4096  // Increased from 2048 for high-throughput workloads
#define PERF_MIN_MAXCONNS         128   // Increased from 64 for modern workloads
#define PERF_MAX_MAXCONNS         131072 // Increased from 65536 for enterprise systems
#define PERF_MIN_SHARDS           32    // Increased from 16 for better parallelization
#define PERF_MAX_SHARDS           131072 // Increased from 65536 for large systems

// Enhanced memory thresholds for modern systems
#define PERF_HIGH_MEMORY_THRESHOLD    (4UL * 1024 * 1024 * 1024)  // 4GB
#define PERF_MEDIUM_MEMORY_THRESHOLD  (2UL * 1024 * 1024 * 1024)  // 2GB (increased from 1GB)
#define PERF_LOW_MEMORY_THRESHOLD     (512UL * 1024 * 1024)       // 512MB threshold
#define PERF_MEMORY_PER_CONNECTION    (12288)                     // ~12KB per connection (increased)
#define PERF_MEMORY_PER_SHARD         (2048)                      // ~2KB per shard (increased)

// Performance scaling factors
#define PERF_HIGH_PERF_MULTIPLIER     1.5   // Multiplier for high-performance systems
#define PERF_MULTI_CORE_MULTIPLIER    1.25  // Multiplier for multi-core systems
#define PERF_MEMORY_SAFETY_FACTOR     0.85  // Safety factor for memory calculations

#endif