# Performance Tuning Guide

## Overview

This guide covers the performance optimizations implemented in Pogocache for better out-of-the-box performance on modern systems.

## Phase 1 Improvements (Implemented)

### 1. Enhanced Default Parameters

The following default parameters have been optimized for modern hardware:

| Parameter | Old Default | New Default | Improvement |
|-----------|-------------|-------------|-------------|
| `backlog` | 1024 | 2048 | +100% network queue capacity |
| `queuesize` | 128 | 512 | +300% event processing capacity |
| `maxconns` | 1024 | 4096 | +300% concurrent connection support |

### 2. Improved Auto-Tuning Algorithms

#### Backlog Scaling
- **Base Formula**: `256 * cpu_cores`
- **Memory Boost**: +50% for high-memory systems (>4GB)
- **Core Boost**: +25% for many-core systems (>4 cores)
- **Range**: 256 - 16,384 (doubled upper limit)

#### Queue Size Scaling
- **Base Formula**: `64 * cpu_cores` (doubled from 32)
- **Memory Scaling**: 128 events/core for high-memory, 32 for low-memory
- **Multi-core Boost**: +20% for 8+ cores, +30% additional for 16+ cores
- **Range**: 64 - 4,096 (doubled upper limit)

#### Max Connections Scaling
- **Base Formula**: Enhanced memory and FD calculation
- **Safety Factors**: 85% for high-perf systems (up from 80%), 75% for capable systems (up from 60%)
- **CPU Scaling**: +10% for 8+ cores, +15% additional for 16+ cores
- **Minimum**: 2,048 connections guaranteed
- **Range**: 128 - 131,072 (doubled upper limit)

#### Shard Scaling
- **Base Formula**: `128 * threads` (improved from static ranges)
- **Memory Scaling**: 2x shards for high-memory systems
- **CPU Optimization**: +50% for 16+ cores, +25% for 8+ cores
- **Power-of-2 Alignment**: Optimized for cache performance
- **Memory Constraint**: Uses 25% of available memory for shards

### 3. Performance Validation Enhancements

- **Real-time Warnings**: Alerts when parameters are <50% of optimal
- **Memory Safety**: Enhanced memory usage calculations
- **Bounds Checking**: Improved parameter validation

### 4. System Resource Detection

Enhanced detection includes:
- **CPU Cores**: Accurate core count detection
- **Memory Tiers**: High (>4GB), Medium (>2GB), Low (<512MB)
- **File Descriptors**: Dynamic FD limit detection
- **Capability Flags**: Boolean flags for optimization decisions

## Performance Impact

### Expected Improvements

1. **Throughput**: 2-4x improvement for high-concurrency workloads
2. **Latency**: Reduced queueing delays under load
3. **Scalability**: Better utilization of modern multi-core systems
4. **Memory Efficiency**: Improved memory-to-performance ratios

### Benchmark Targets

- **Small Systems** (1-2 cores, <2GB): 50% performance improvement
- **Medium Systems** (4-8 cores, 2-8GB): 100% performance improvement  
- **Large Systems** (8+ cores, 8GB+): 200-300% performance improvement

## Configuration Examples

### High-Performance Server (16 cores, 32GB RAM)
```bash
# Auto-tuned values (--autotune=yes, default)
backlog: 6144      # 256 * 16 * 1.5 * 1.25
queuesize: 2048    # 64 * 16 * 1.2 * 1.3
maxconns: 25600    # Calculated from memory/FD limits
shards: 8192       # 128 * 16 * 2 * 1.5 (power-of-2 aligned)
```

### Development System (4 cores, 8GB RAM)
```bash
# Auto-tuned values
backlog: 1536      # 256 * 4 * 1.5
queuesize: 512     # 64 * 4 * 1.2
maxconns: 8192     # Calculated from memory/FD limits
shards: 2048       # 128 * 4 * 2 (power-of-2 aligned)
```

### Minimal System (2 cores, 1GB RAM) 
```bash
# Auto-tuned values with memory constraints
backlog: 384       # 256 * 2 * 0.75
queuesize: 128     # 64 * 2 * 0.5  
maxconns: 2048     # Memory constrained
shards: 256        # 128 * 2 (power-of-2 aligned)
```

## Manual Tuning

For specific workloads, manual tuning may be beneficial:

```bash
# Disable auto-tuning and set custom values
pogocache --autotune=no --backlog=4096 --queuesize=1024 --maxconns=16384

# Enable auto-tuning but override specific parameters
pogocache --autotune=yes --backlog=8192  # Override just backlog
```

## Monitoring and Validation

The system provides performance warnings when parameters are suboptimal:

```
# Performance Warning: queuesize (128) is significantly below optimal (512)
# Performance Warning: maxconns (1024) is significantly below optimal (4096)
```

## Best Practices

1. **Use Auto-Tuning**: Keep `--autotune=yes` (default) for most use cases
2. **Monitor Warnings**: Pay attention to performance warnings in logs
3. **Profile Your Workload**: Use custom parameters for specific workload patterns
4. **System Resources**: Ensure adequate memory and file descriptor limits
5. **Benchmark**: Test performance improvements with your specific workload

## Future Improvements (Phase 2+)

- Dynamic runtime parameter adjustment
- Workload-specific optimization profiles
- Adaptive scaling based on real-time metrics
- Integration with system monitoring tools
- Advanced NUMA-aware optimizations

## Troubleshooting

### Common Issues

1. **Low Performance Despite High Resources**
   - Check if `--autotune=no` is set
   - Verify system resource limits (ulimit -n)
   - Monitor for performance warnings

2. **Memory Pressure**
   - Reduce `maxconns` if experiencing OOM
   - Check `PERF_MEMORY_PER_CONNECTION` usage
   - Consider system memory fragmentation

3. **High CPU Usage**
   - May indicate oversized queues for workload
   - Consider reducing `queuesize` for low-throughput scenarios
   - Check thread-to-core ratio

## Technical Details

### Algorithm Changes

1. **Backlog**: Linear scaling with CPU cores instead of fixed tiers
2. **Queue Size**: Doubled baseline with multi-core bonuses
3. **Max Connections**: Enhanced memory calculations with safety factors
4. **Shards**: Dynamic scaling with power-of-2 alignment

### Memory Model

- **Connection Memory**: 12KB per connection (increased from 8KB)
- **Shard Memory**: 2KB per shard (increased from 1KB)
- **Safety Margins**: 85% utilization for high-performance systems

### Bounds

All parameters have both minimum and maximum bounds to prevent:
- Resource exhaustion on small systems
- Inefficient configurations on large systems
- Memory allocation failures
- File descriptor exhaustion

---

For questions or issues related to performance tuning, please refer to the main documentation or submit an issue on the project repository.