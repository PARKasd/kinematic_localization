# Kinematic Localization

[English](README.md) | [한국어](docs/ko/README.md)

ROS 2 Jazzy map localization for a wheeled robot with a 2D LiDAR and wheel
odometry. The package adapts [Kinematic-ICP](https://github.com/PRBonn/kinematic-icp)
to align scans against a **fixed, previously built map**, publishing a pose in the
`map` frame and the `map -> odom` transform.

This repository contains the localization package, map-building utilities, tests,
and the C++ libraries needed by the package. It does not include a planner,
controller, simulator, recorded bags, or track maps. It builds without `f110_msgs`.

## How it works

1. Receive a `sensor_msgs/msg/LaserScan`, wheel `nav_msgs/msg/Odometry`, and the
   static transform between the robot base and LiDAR.
2. Wait for odometry samples that bracket the end of the scan. Use their relative
   motion as the registration prior and for scan deskewing.
3. Optionally compensate chassis tilt, then register the scan against a frozen
   voxel map using the patched Kinematic-ICP core.
4. Check the registration, apply optional output smoothing, and publish the pose,
   diagnostics, and `map -> odom` TF at the scan-end timestamp.

An approximate initial pose is required for fixed-map localization. Set it using
RViz **2D Pose Estimate** or `/initialpose`. This is local scan matching, not a
global localization or automatic kidnapped-robot recovery system.

## Difference from Kinematic-ICP

[Upstream Kinematic-ICP](https://github.com/PRBonn/kinematic-icp) estimates LiDAR
odometry using wheel-motion information and planar kinematic constraints. It
supports both 3D point clouds and 2D laser scans. This package reuses that approach
and adds a fixed-map localization application; it is not an independent ICP method.

| Aspect | Upstream Kinematic-ICP | This package |
| --- | --- | --- |
| Main task | Estimate robot motion over time | Estimate robot pose within a known map |
| Registration target | Local voxel map updated from scans | Preloaded `.kissmap`, unchanged during localization |
| Reference frame | Odometry relative to the starting frame | The supplied map's coordinate frame |
| Drift | Relative odometry can accumulate drift | Map matching anchors the estimate when registration succeeds; accuracy is not guaranteed |
| Initialization | Odometry startup | Approximate map pose supplied through `/initialpose` |
| LiDAR interface | 3D `PointCloud2` or 2D `LaserScan` | 2D `LaserScan` |
| ROS output | LiDAR odometry and its TF | `/pf/pose/odom`, `map -> odom`, `/map`, and diagnostics |
| Motion correction | Planar kinematic model | Inherited model plus an optional soft lateral degree of freedom |
| Application additions | See upstream implementation | Scan-end odometry synchronization, output smoothing, scan-gap watchdog, pose checks, rejection gate, and tilt compensation |
| Map creation | Incremental odometry map | Optional online accumulation, offline bag mapping, or occupancy-map conversion |

In `slam_mode`, this package also updates a local map and accumulates points for
export. Despite the parameter name, it does **not** provide loop closure or a
globally optimized SLAM back end. This mode can drift.

The comparison describes functionality, not a measured performance advantage.
See the [Kinematic-ICP paper](https://arxiv.org/abs/2410.10277) for the original
method and evaluation, and [third-party notes](THIRD_PARTY.md) for local patches.

## Build

Target: Ubuntu 24.04 with ROS 2 Jazzy, a C++17 compiler, `colcon`, and an initialized
`rosdep`, Git, and the `patch` utility. Run these commands in Bash:

```bash
source /opt/ros/jazzy/setup.bash
mkdir -p ~/kinematic_ws/src
git clone --recurse-submodules https://github.com/PARKasd/kinematic_localization.git \
  ~/kinematic_ws/src/kinematic_localization
cd ~/kinematic_ws
rosdep update
rosdep install --from-paths src --ignore-src --rosdistro jazzy -r -y
colcon build --symlink-install --packages-select kinematic_localization
source install/setup.bash
```

Kinematic-ICP, KISS-ICP, Sophus, and robin-map are pinned Git submodules of their
official upstream repositories. For an existing clone, initialize them with:

```bash
git submodule update --init --recursive
```

Run that command again after pulling changes that update dependency revisions.
After changing dependency revisions, force CMake to regenerate patched sources:
`colcon build --packages-select kinematic_localization --cmake-force-configure`.
GitHub source ZIP archives do not include submodule contents; use a recursive clone.
Eigen and TBB are system dependencies installed through `rosdep`; install `patch`
with `sudo apt-get install patch` if it is missing. Once submodules and system
dependencies are available, the C++ build needs no further downloads.

The build applies the [localization patch](patches/kinematic-icp-localization.patch)
and KISS-ICP's Sophus compatibility patch to copies in the build directory. It
leaves the submodule working trees unchanged. See [THIRD_PARTY.md](THIRD_PARTY.md)
for pins and patch maintenance.

## Prepare a map

No map is included. Convert your own occupancy-map YAML and PGM/PNG into a point
map; the YAML must reference the image and define its resolution and origin:

```bash
mkdir -p ~/kinematic_maps
ros2 run kinematic_localization pgm_to_kissmap.py \
  /absolute/path/to/map.yaml ~/kinematic_maps/map.kissmap \
  --voxel-size 1.0 --max-range 12.0 --downsample 0.1
```

The converter currently assumes the occupancy grid has **zero origin yaw**.
`--downsample` controls point spacing; `--voxel-size` records metadata and does not
change point density. Alternatively, use one of the mapping modes below.

## Run localization

Provide `/scan`, `/odom`, wheel-odometry TF `odom -> base_link`, and the static TF
`base_link -> <scan frame>`. Sensor timestamps must use a consistent clock.

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  map_name:=$HOME/kinematic_maps/map.kissmap
```

In RViz, set the fixed frame to `map`, add `/map`, and use **2D Pose Estimate**
near the robot's actual pose. An explicit initial-pose message is also supported:

```bash
# Example only: replace position and orientation with the actual starting pose.
ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  '{header: {frame_id: map}, pose: {pose: {position: {x: 0.0, y: 0.0}, orientation: {w: 1.0}}}}'
```

An absolute `map_name` is a file path. A basename resolves to
`share/kinematic_localization/maps/<name>.kissmap`. An empty `map_name` selects
odometry without a frozen map; always supply a map for map-based localization.
An unreadable nonempty map path stops startup.

For simulation or bag replay, add `use_sim_time:=true` and provide `/clock`
(for example, `ros2 bag play /path/to/bag --clock`). Ensure another localizer or
replayed topic is not also publishing `/pf/pose/odom` or `map -> odom`.

## Create a map from scans

Offline mapping reads a rosbag containing scans, wheel odometry, and the required
TF messages:

```bash
ros2 launch kinematic_localization mapping.launch.py \
  bag_path:=/absolute/path/to/bag \
  output_path:=$HOME/kinematic_maps/from_bag.kissmap
```

Online accumulation initializes at identity on the first scan:

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  slam_mode:=true map_output_file:=$HOME/kinematic_maps/online.kissmap

# In another sourced terminal:
ros2 service call /kinematic_localization/save_map std_srvs/srv/Trigger '{}'
```

The online map is also saved on clean shutdown. Both mapping modes estimate
relative motion and can accumulate drift; inspect the result before using it as
a fixed localization map.

## Configuration and ROS interfaces

Edit the package's [localization YAML](src/kinematic_localization/config/kinematic_localization.yaml)
and [mapping YAML](src/kinematic_localization/config/mapping.yaml), then rebuild
and source the workspace as needed. Launch arguments select maps, mode, time, and
scan timing; other parameters are loaded from the installed YAML at startup.

| Default interface | Type | Role |
| --- | --- | --- |
| `/scan` | `sensor_msgs/msg/LaserScan` | Input 2D scan |
| `/odom` | `nav_msgs/msg/Odometry` | Input wheel pose and twist |
| `/initialpose` | `geometry_msgs/msg/PoseWithCovarianceStamped` | Initial pose or reset |
| `/tf`, `/tf_static` | `tf2_msgs/msg/TFMessage` | Transforms |
| `/pf/pose/odom` | `nav_msgs/msg/Odometry` | Output map pose and wheel-sourced twist |
| `/map` | `nav_msgs/msg/OccupancyGrid` | Rasterized map, transient-local QoS |
| `~/diagnostics` | `diagnostic_msgs/msg/DiagnosticArray` | Registration and watchdog status |
| `~/map_points` | `sensor_msgs/msg/PointCloud2` | Accumulated map in online mapping mode |
| `~/save_map` | `std_srvs/srv/Trigger` | Save service in online mapping mode |

Here `~` resolves to `/kinematic_localization` under the default launch file.
The output TF is `T_map_odom = T_map_base * inverse(T_odom_base)`.
The public package initializes through `/initialpose`; it has no dependency on
another package's waypoint messages.

Important defaults: `voxel_size: 1.0`, `source_voxel_size: 0.25`,
`max_range: 12.0`, `scan_stamp_convention: begin`, and scan-end synchronization on.
Smoothing, diagnostics, watchdog, rejection gate, lateral correction, and tilt
compensation are enabled in the localization YAML. These are starting settings
from a particular vehicle, not universal calibrations. In particular, calibrate
the roll gain or disable tilt compensation for a different chassis. Mapping uses
`max_range: 30.0`; review both configurations when building a map.

See the [node guide](src/kinematic_localization/docs/kinematic_localization.md)
for parameter behavior, failure handling, and the map format.

## Tests

```bash
colcon test --packages-select kinematic_localization --event-handlers console_direct+
colcon test-result --verbose
```

The included tests cover configuration guards, scan/odometry synchronization,
and tilt compensation. GitHub Actions builds and tests the package on ROS 2 Jazzy
and checks node startup. These checks do not replace sensor replay or robot tests.

## License and attribution

The package declares the [MIT license](LICENSE). Upstream components retain their
own notices; see [THIRD_PARTY.md](THIRD_PARTY.md). Please credit the original
[Kinematic-ICP research](https://arxiv.org/abs/2410.10277) when using its method in
academic work.
