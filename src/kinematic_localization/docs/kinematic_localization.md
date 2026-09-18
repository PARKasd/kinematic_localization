# Node guide

[English README](../../../README.md) | [한국어](../../../docs/ko/kinematic_localization.md)

## 1. Nodes and operating modes

`localization_node` consumes 2D scans and wheel odometry. With a nonempty
`map_name`, the patched ICP core registers against a frozen point map. Send an
approximate pose on `/initialpose` before localization can publish.

With an empty `map_name`, the same node uses an updating local odometry map and
still waits for `/initialpose`. With `slam_mode: true`, it starts at identity,
accumulates map points, and supports saving them; there is no loop closure.

`mapping_node` reads a rosbag offline and writes a `.kissmap`. Its input topics
are configured in `config/mapping.yaml`. It uses message timestamps for motion
alignment and processes bag messages without relying on bag playback timing.

## 2. Start the node

After building and sourcing the workspace as described in the root README:

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  map_name:=/absolute/path/to/map.kissmap
```

Provide `/scan` (`sensor_msgs/msg/LaserScan`), `/odom`
(`nav_msgs/msg/Odometry`), and the robot's TF tree. Set an approximate initial pose
through `/initialpose` (`geometry_msgs/msg/PoseWithCovarianceStamped`) in `map`.
The static LiDAR extrinsic must agree with the scan's `header.frame_id`.

The node publishes `/pf/pose/odom` (`nav_msgs/msg/Odometry`), `map -> odom` TF,
`/map` (`nav_msgs/msg/OccupancyGrid`), and `~/diagnostics`
(`diagnostic_msgs/msg/DiagnosticArray`). The pose is expressed in `map`, with
child frame `base_link`; twist is taken from wheel odometry. In online mapping,
`~/map_points` (`sensor_msgs/msg/PointCloud2`) and `~/save_map`
(`std_srvs/srv/Trigger`) are available as well.

## 3. Configuration

Both launch files require their installed YAML to exist. Both nodes require
`config_schema_version: 20260824`; a missing or mismatched version fails startup.
Use the launch files so the node receives the complete configuration.

| Parameter group | Meaning and current localization defaults |
| --- | --- |
| Topics and frames | `/scan`, `/odom`, `/pf/pose/odom`, `/initialpose`; `map`, `odom`, `base_link` |
| Map | `map_name` selects a fixed map; empty means odometry |
| Scan timing | `odom_window_at_scan_end: true`, `scan_stamp_convention: begin`; the end time is header time plus `(N-1) * time_increment` |
| Synchronization queue | Wait up to `0.08` s for bracketing odometry; queue limit `4`; no registration-time extrapolation |
| Map voxel / source voxel | `voxel_size: 1.0` m controls the map and search scale; `source_voxel_size: 0.25` m independently controls source downsampling |
| Range / iterations | `min_range: 0.1` m, `max_range: 12.0` m, `max_num_iterations: 30` |
| Output smoothing | Enabled; translation gain varies with speed, rotation gain `smoothing_alpha_rot: 0.12`; filtered poses do not update the ICP map |
| Lateral correction | `lateral_dof_enable: true`; soft regularization permits lateral motion in addition to the inherited arc model |
| Rejection gate | `gate_enable: true`, `gate_chi2: 11.34`; rejected updates fall back to the odometry prediction |
| Watchdog | Starts after `scan_timeout_sec: 0.15`; dead reckoning limited by `max_dead_reckoning_sec: 2.0` |
| Tilt | Enabled; roll estimate is gain times speed times yaw rate; roll gain `0.0270`, pitch gain `0.0`, angle clamp `0.26` rad |
| Map display | Resolution `0.05` m, point dilation `0.15` m, publication period `10.0` s |

Settings are read at startup. Adjust YAML and restart; do not assume live parameter
updates retune the ICP core. The launch file exposes only selected overrides.
For `scan_stamp_convention: end`, the header is already the scan-end timestamp.
Confirm the sensor's timestamp convention rather than inferring it from arrival lag.

Mapping uses its own YAML, including `max_range: 30.0`. Match tilt settings when
building a frozen map from fast-driving data. Roll compensation is vehicle-specific;
disable it or calibrate it for a different suspension. The experimental
`fast_corner_free_mode` remains off by default.

## 4. Failure handling and limits

- A nonempty map path that cannot be loaded is a fatal startup error.
- Empty-correspondence and non-finite-pose guards protect registration state.
- Missing bracketing odometry causes a scan to wait, then drop on timeout or queue
  overflow; it is not registered against an extrapolated prior.
- During a scan gap, the watchdog publishes wheel dead reckoning with increasing
  covariance until its time limit. Accuracy can degrade during that interval.
- The rejection gate can force-accept after a rejection streak, unless the map
  validity check prevents it. It is not a guarantee against wrong localization.
- The map validity check reports poses inside occupied regions. It does not by
  itself reject every such pose.
- Watchdog, pose checking, rejection gate, and lateral correction are disabled in
  online mapping mode.
- Fixed-map localization still depends on a good initial pose, map quality,
  timing, extrinsic calibration, and observable geometry.

Diagnostics include inlier ratio, residual RMS, convergence, gate status,
dead-reckoning duration, and applied tilt. Inspect these together with a map/scan
overlay. A low residual alone does not establish correct global localization.

## 5. Map format

The package defines `.kissmap`; it is not an upstream interchange standard:

| Field | Storage |
| --- | --- |
| Magic | 8 bytes: `KISSMAP1` |
| Voxel size | float64 |
| Maximum range | float64 |
| Point count | uint64 |
| Points | Point-count triples of float64 `x, y, z` in the map frame |

The Python converter writes little-endian values. C++ IO uses native binary
values; use little-endian platforms, as on the target x86-64/ARM64 machines.
Voxel size in the file is metadata; point density is set by conversion or mapping.

## 6. Verification

Run `colcon test --packages-select kinematic_localization` and
`colcon test-result --verbose`. Configuration tests check missing files and schema
agreement; C++ tests check scan synchronization decisions and tilt compensation.
Before deploying a configuration on a robot, validate it with representative
sensor data. CI startup and unit tests do not measure localization accuracy.
