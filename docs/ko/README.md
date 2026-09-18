# Kinematic Localization

[English](../../README.md) | [한국어](README.md)

2D LiDAR와 휠 오도메트리를 사용하는 이동 로봇용 ROS 2 Jazzy 위치추정 패키지입니다.
[Kinematic-ICP](https://github.com/PRBonn/kinematic-icp)를 기반으로 현재 스캔을
**미리 만든 고정 맵**에 정합하고, `map` 좌표계의 자세와 `map -> odom` TF를 발행합니다.

이 저장소에는 위치추정 패키지, 맵 생성 도구, 테스트, 필요한 C++ 라이브러리만 포함됩니다.
플래너, 제어기, 시뮬레이터, 기록한 rosbag, 트랙 맵은 포함하지 않으며 `f110_msgs` 없이
빌드할 수 있습니다.

## 동작 원리

1. `LaserScan`, 휠 `Odometry`, 로봇 베이스와 LiDAR 사이의 정적 TF를 받습니다.
2. 스캔 종료 시각을 양쪽에서 감싸는 오도메트리 샘플을 기다립니다. 상대 이동량을
   ICP의 사전 이동 추정값과 스캔 왜곡 보정에 사용합니다.
3. 설정에 따라 차체 기울기를 보정하고, 수정된 Kinematic-ICP 코어로 고정 복셀 맵에
   스캔을 정합합니다.
4. 정합 결과를 검사하고 출력 필터를 적용한 뒤, 스캔 종료 시각에 맞춰 자세, 진단 정보,
   `map -> odom` TF를 발행합니다.

고정 맵 위치추정에는 실제 위치에 가까운 초기 자세가 필요합니다. RViz의 **2D Pose
Estimate** 또는 `/initialpose`로 지정하세요. 전역 위치 탐색이나 로봇을 다른 위치로
옮겼을 때의 자동 복구를 제공하는 방식은 아닙니다.

## Kinematic-ICP와의 차이

[원본 Kinematic-ICP](https://github.com/PRBonn/kinematic-icp)는 휠 이동 정보와 평면
운동학 제약으로 LiDAR 오도메트리를 추정하며, 3D 포인트 클라우드와 2D 스캔을 지원합니다.
이 패키지는 해당 알고리즘을 재사용하고 고정 맵 위치추정 기능을 추가합니다.

| 항목 | 원본 Kinematic-ICP | 이 패키지 |
| --- | --- | --- |
| 주목적 | 시간에 따른 로봇 이동량 추정 | 알려진 맵 안에서 로봇 자세 추정 |
| 정합 대상 | 스캔으로 갱신하는 로컬 복셀 맵 | 위치추정 중 변경하지 않는 `.kissmap` |
| 기준 좌표계 | 출발점을 기준으로 한 오도메트리 좌표계 | 입력 맵의 좌표계 |
| 누적 오차 | 상대 오도메트리 오차가 누적될 수 있음 | 정합이 성공하면 맵이 기준점 역할을 하지만 정확도를 보장하지는 않음 |
| 초기화 | 오도메트리 시작 | `/initialpose`로 맵 기준 초기 자세 지정 |
| LiDAR 입력 | 3D `PointCloud2` 또는 2D `LaserScan` | 2D `LaserScan` |
| ROS 출력 | LiDAR 오도메트리와 TF | `/pf/pose/odom`, `map -> odom`, `/map`, 진단 정보 |
| 운동 보정 | 평면 운동학 모델 | 기존 모델과 선택적인 횡방향 자유도 |
| 추가 기능 | 원본 구현 참고 | 스캔 종료 시각 동기화, 출력 필터, 스캔 중단 워치독, 자세 검사, 정합 게이트, 기울기 보정 |
| 맵 생성 | 오도메트리 기반 점진적 맵 | 온라인 누적, 오프라인 rosbag 매핑, occupancy 맵 변환 |

`slam_mode`에서는 로컬 맵을 갱신하고 저장할 포인트를 누적합니다. 이름과 달리 루프
클로저나 전역 최적화 기능은 없으므로 이 모드에서는 오차가 누적될 수 있습니다.
위 비교는 기능 설명이며 성능 우위를 입증하는 벤치마크가 아닙니다.
원본 방법과 평가는 [논문](https://arxiv.org/abs/2410.10277), 수정 사항은
[의존성 문서](../../THIRD_PARTY.md)를 참고하세요.

## 빌드

Ubuntu 24.04, ROS 2 Jazzy, C++17 컴파일러, `colcon`, 초기화된 `rosdep`을 기준으로 합니다.
아래 명령은 Bash에서 실행합니다.

```bash
source /opt/ros/jazzy/setup.bash
mkdir -p ~/kinematic_ws/src
git clone https://github.com/PARKasd/kinematic_localization.git \
  ~/kinematic_ws/src/kinematic_localization
cd ~/kinematic_ws
rosdep update
rosdep install --from-paths src --ignore-src --rosdistro jazzy -r -y
colcon build --symlink-install --packages-select kinematic_localization
source install/setup.bash
```

Kinematic-ICP, KISS-ICP, Sophus, robin-map 소스와 라이선스는 저장소에 포함됩니다.
Eigen과 TBB 등 시스템 의존성은 `rosdep`으로 설치합니다. 시스템 의존성이 설치되어
있으면 포함된 C++ 라이브러리는 별도 다운로드 없이 빌드됩니다.

## 맵 준비

맵은 제공하지 않습니다. 자신의 occupancy 맵 YAML과 PGM/PNG를 변환하세요.
YAML에는 이미지 경로, 해상도, 원점이 있어야 합니다.

```bash
mkdir -p ~/kinematic_maps
ros2 run kinematic_localization pgm_to_kissmap.py \
  /absolute/path/to/map.yaml ~/kinematic_maps/map.kissmap \
  --voxel-size 1.0 --max-range 12.0 --downsample 0.1
```

현재 변환기는 맵 원점의 **yaw가 0인 경우**를 가정합니다. 포인트 간격은
`--downsample`로 조절하며 `--voxel-size`는 파일의 메타데이터입니다.
아래 매핑 기능으로 직접 `.kissmap`을 만들 수도 있습니다.

## 위치추정 실행

`/scan`, `/odom`, 휠 오도메트리 TF `odom -> base_link`, 정적 TF
`base_link -> <scan frame>`을 준비합니다. 센서 타임스탬프의 시간 기준이 같아야 합니다.

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  map_name:=$HOME/kinematic_maps/map.kissmap
```

RViz의 Fixed Frame을 `map`으로 설정하고 `/map`을 추가한 다음, **2D Pose Estimate**로
실제 로봇 위치에 가까운 자세를 지정합니다. 직접 메시지를 발행해도 됩니다.

```bash
# 예시입니다. 위치와 방향을 실제 시작 자세로 바꾸세요.
ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  '{header: {frame_id: map}, pose: {pose: {position: {x: 0.0, y: 0.0}, orientation: {w: 1.0}}}}'
```

`map_name`이 절대 경로이면 해당 파일을 읽습니다. 이름만 지정하면 설치된 패키지의
`maps/<name>.kissmap`을 읽습니다. 빈 값이면 고정 맵 없는 오도메트리 모드가 되므로,
맵 기반 위치추정을 하려면 맵을 지정해야 합니다. 지정한 맵을 읽지 못하면 시작에 실패합니다.

시뮬레이션이나 rosbag 재생에서는 `use_sim_time:=true`를 추가하고 `/clock`을
발행하세요. 예: `ros2 bag play /path/to/bag --clock`. 다른 위치추정 노드나 재생 토픽이
동시에 `/pf/pose/odom` 또는 `map -> odom`을 발행하지 않도록 구성합니다.

## 스캔으로 맵 생성

오프라인 매핑에는 스캔, 휠 오도메트리, 필요한 TF 메시지가 기록된 rosbag이 필요합니다.

```bash
ros2 launch kinematic_localization mapping.launch.py \
  bag_path:=/absolute/path/to/bag \
  output_path:=$HOME/kinematic_maps/from_bag.kissmap
```

온라인 누적은 첫 스캔에서 항등 자세로 초기화합니다.

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  slam_mode:=true map_output_file:=$HOME/kinematic_maps/online.kissmap

# 환경을 source한 다른 터미널에서 저장:
ros2 service call /kinematic_localization/save_map std_srvs/srv/Trigger '{}'
```

온라인 맵은 정상 종료 시에도 저장됩니다. 두 매핑 모드 모두 상대 이동 추정 오차가
누적될 수 있으므로 고정 맵으로 사용하기 전에 결과를 확인하세요.

## 설정과 인터페이스

[위치추정 YAML](../../src/kinematic_localization/config/kinematic_localization.yaml)과
[매핑 YAML](../../src/kinematic_localization/config/mapping.yaml)을 수정하고 필요에 따라
다시 빌드하고 source합니다. 파라미터는 시작 시 읽습니다.

| 기본 인터페이스 | 메시지/서비스 타입 | 용도 |
| --- | --- | --- |
| `/scan` | `sensor_msgs/msg/LaserScan` | 2D 스캔 입력 |
| `/odom` | `nav_msgs/msg/Odometry` | 휠 자세와 속도 입력 |
| `/initialpose` | `geometry_msgs/msg/PoseWithCovarianceStamped` | 초기 자세와 재초기화 |
| `/tf`, `/tf_static` | `tf2_msgs/msg/TFMessage` | 좌표 변환 |
| `/pf/pose/odom` | `nav_msgs/msg/Odometry` | 맵 기준 자세와 휠 기반 속도 출력 |
| `/map` | `nav_msgs/msg/OccupancyGrid` | 래스터화한 맵, transient-local QoS |
| `~/diagnostics` | `diagnostic_msgs/msg/DiagnosticArray` | 정합 및 워치독 상태 |
| `~/map_points` | `sensor_msgs/msg/PointCloud2` | 온라인 매핑의 누적 맵 |
| `~/save_map` | `std_srvs/srv/Trigger` | 온라인 매핑 저장 서비스 |

기본 launch에서 `~`는 `/kinematic_localization`입니다. 출력 TF는
`T_map_odom = T_map_base * inverse(T_odom_base)`입니다. 공개판은 `/initialpose`로
초기화하며 다른 패키지의 웨이포인트 메시지에 의존하지 않습니다.

위치추정 기본값은 `voxel_size: 1.0`, `source_voxel_size: 0.25`, `max_range: 12.0`,
`scan_stamp_convention: begin`입니다. 스캔 종료 시각 동기화, 출력 필터, 진단,
워치독, 정합 게이트, 횡방향 보정, 기울기 보정이 켜져 있습니다. 특정 차량에서 가져온
초기 설정이므로 다른 차체에서는 롤 게인을 다시 측정하거나 기울기 보정을 끄세요.
매핑은 `max_range: 30.0`을 사용하므로 두 설정 파일을 함께 확인해야 합니다.

자세한 파라미터 동작과 한계는 [한국어 노드 가이드](kinematic_localization.md)를 참고하세요.

## 테스트

```bash
colcon test --packages-select kinematic_localization --event-handlers console_direct+
colcon test-result --verbose
```

테스트는 설정 가드, 스캔/오도메트리 동기화, 기울기 보정을 확인합니다. GitHub Actions는
ROS 2 Jazzy에서 빌드·테스트·노드 시작 검사를 수행합니다. 실제 센서 재생과 로봇 검증은
별도로 필요합니다.

## 라이선스와 출처

패키지는 [MIT 라이선스](../../LICENSE)를 사용합니다. 포함된 라이브러리의 원본
라이선스와 저작권 고지는 유지했습니다. [THIRD_PARTY.md](../../THIRD_PARTY.md)를
참고하고, 학술 연구에 원본 방법을 사용한다면 [Kinematic-ICP 논문](https://arxiv.org/abs/2410.10277)을
인용하세요.
