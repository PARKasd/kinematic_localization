# kinematic_localization

- `src/localization_node.cpp`: frozen-map localization and optional online mapping.
  Initialize with `/initialpose`; no custom waypoint messages or planner dependency.
- `src/mapping_node.cpp`: offline rosbag-to-kissmap conversion.
- `src/utils.hpp`: shared ROS, map IO, and tilt helpers.
- `src/scan_odom_sync.hpp`: ROS-independent scan/odometry timing decisions.
- `config/*.yaml` and `launch/*.launch.py`: keep both launch files' absolute YAML
  existence checks and both nodes' mandatory config_schema_version checks.
- `test/`: preserve configuration, scan synchronization and tilt regression tests.
- `docs/kinematic_localization.md`: English operation guide; update when interfaces change.
- `../../docs/ko/`: Korean translations; keep them consistent with English documentation.

Use standard sensor_msgs, nav_msgs, geometry_msgs, diagnostic_msgs, std_srvs and TF.
Keep the single-threaded executor: callback state is intentionally lock-free.
Registration priors and output stamps refer to scan end. Never clamp or extrapolate
odometry for registration; wait for bracketing samples, then drop on timeout.
Keep NaN guards, frozen-map behavior, registration diagnostics, source-only voxel
downsampling and optional lateral motion patches in the vendored core.
Output smoothing must not feed back into the registration pose or accumulated map.
Keep tilt configuration consistent between localization and mapping when making a
map from fast-driving data. Vehicle-specific gains require calibration.
