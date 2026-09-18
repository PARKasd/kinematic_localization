# 노드 가이드

[English](../../src/kinematic_localization/docs/kinematic_localization.md) | [한국어 README](README.md)

## 1. 노드와 모드

`localization_node`는 2D 스캔과 휠 오도메트리를 받습니다. `map_name`을 지정하면
고정 포인트 맵에 정합하며, `/initialpose`로 근사 초기 자세를 받아야 위치추정을
발행합니다. `map_name`이 비어 있으면 갱신하는 로컬 맵을 사용하는 오도메트리 모드가
되며 이때도 초기 자세를 기다립니다.

`slam_mode: true`이면 첫 스캔에서 항등 자세로 시작하고 포인트를 누적·저장합니다.
루프 클로저는 없습니다. `mapping_node`는 rosbag을 오프라인으로 읽어 `.kissmap`을
만들며 `config/mapping.yaml`로 입력을 설정합니다. 이동 정합에는 메시지 타임스탬프를
사용하고 rosbag 재생 속도에 의존하지 않습니다.

## 2. 실행과 ROS 인터페이스

README에 따라 빌드하고 환경을 source한 다음 실행합니다.

```bash
ros2 launch kinematic_localization kinematic_localization.launch.py \
  map_name:=/absolute/path/to/map.kissmap
```

입력은 `/scan` (`sensor_msgs/msg/LaserScan`), `/odom` (`nav_msgs/msg/Odometry`),
로봇 TF입니다. `/initialpose` (`geometry_msgs/msg/PoseWithCovarianceStamped`)로
`map` 기준 초기 자세를 보냅니다. LiDAR 정적 TF는 스캔의 `header.frame_id`와 일치해야 합니다.

출력은 `/pf/pose/odom` (`nav_msgs/msg/Odometry`), `map -> odom` TF,
`/map` (`nav_msgs/msg/OccupancyGrid`), `~/diagnostics`
(`diagnostic_msgs/msg/DiagnosticArray`)입니다. 자세는 `map` 기준이고 child frame은
`base_link`이며, twist는 휠 오도메트리에서 가져옵니다. 온라인 매핑에서는
`~/map_points` (`sensor_msgs/msg/PointCloud2`)와 `~/save_map`
(`std_srvs/srv/Trigger`)도 제공합니다.

## 3. 설정

두 launch 파일 모두 설치된 YAML의 존재를 검사합니다. 두 노드는
`config_schema_version: 20260824`를 요구하며 값이 없거나 다르면 시작에 실패합니다.
완전한 설정을 전달하려면 launch 파일을 사용하세요.

| 파라미터 | 의미와 위치추정 기본값 |
| --- | --- |
| 토픽과 프레임 | `/scan`, `/odom`, `/pf/pose/odom`, `/initialpose`; `map`, `odom`, `base_link` |
| `map_name` | 고정 맵 선택, 빈 값은 오도메트리 |
| 스캔 시각 | `odom_window_at_scan_end: true`, `scan_stamp_convention: begin`; 종료 시각은 헤더 시각에 `(N-1) * time_increment`를 더한 값 |
| 동기화 큐 | 최대 대기 `0.08`초, 큐 한도 `4`; 정합용 오도메트리는 외삽하지 않음 |
| 복셀 크기 | 맵·탐색 기준 `voxel_size: 1.0` m, 소스 다운샘플 기준 `source_voxel_size: 0.25` m |
| 거리와 반복 | `min_range: 0.1` m, `max_range: 12.0` m, `max_num_iterations: 30` |
| 출력 필터 | 활성화, 이동 게인은 속도에 따라 변경, 회전 게인 `smoothing_alpha_rot: 0.12`; ICP 맵에는 필터 전 자세 사용 |
| 횡방향 보정 | `lateral_dof_enable: true`; 기존 원호 모델에 부드러운 횡방향 제약 추가 |
| 정합 게이트 | `gate_enable: true`, `gate_chi2: 11.34`; 거부 시 휠 이동 예측 사용 |
| 워치독 | 스캔 중단 `0.15`초 후 작동, dead reckoning 최대 `2.0`초 |
| 기울기 | 활성화, 롤은 게인 × 속도 × yaw rate; 롤 게인 `0.0270`, 피치 게인 `0.0`, 각도 한도 `0.26` rad |
| 맵 표시 | 해상도 `0.05` m, 포인트 팽창 `0.15` m, 발행 주기 `10.0`초 |

설정은 시작 시 읽습니다. YAML을 수정하고 재시작하세요. 실행 중 파라미터 변경이
ICP 코어에 바로 적용된다고 가정하면 안 됩니다. launch 인자는 일부 항목만 제공합니다.
`scan_stamp_convention: end`이면 헤더가 이미 스캔 종료 시각입니다. 도착 지연만 보고
판단하지 말고 드라이버의 타임스탬프 규약을 확인하세요.

매핑 YAML은 별도이며 `max_range: 30.0`입니다. 빠른 주행 데이터로 맵을 만들 때는
매핑과 위치추정의 기울기 설정을 맞추세요. 롤 보정은 차량별 설정이므로 다른 차체에서는
끄거나 다시 측정해야 합니다. 실험 기능 `fast_corner_free_mode`는 기본적으로 꺼져 있습니다.

## 4. 실패 처리와 한계

- 지정한 맵을 읽지 못하면 시작에 실패합니다.
- 대응점이 없거나 자세가 유한하지 않은 경우 등록 상태를 보호하는 가드가 작동합니다.
- 스캔 종료 시각을 감싸는 오도메트리가 없으면 기다린 뒤 시간/큐 한도에 따라 스캔을
  버립니다. 정합을 위해 오도메트리를 외삽하지 않습니다.
- 스캔이 끊기면 워치독이 제한 시간 동안 휠 기반 추정과 증가하는 공분산을 발행합니다.
  이 구간에는 오차가 커질 수 있습니다.
- 게이트는 연속 거부 후 맵 유효성 검사에 따라 정합을 강제 수용할 수 있습니다.
  오위치 추정을 완전히 차단하는 장치는 아닙니다.
- 맵 유효성 검사는 점유 영역 내부의 자세를 보고하지만, 단독으로 모든 해당 자세를
  거부하지는 않습니다.
- 온라인 매핑에서는 워치독, 맵 자세 검사, 정합 게이트, 횡방향 보정을 끕니다.
- 고정 맵 위치추정도 초기 자세, 맵 품질, 시간 동기화, 외부 보정, 관측 가능한 지형에
  영향을 받습니다.

진단에는 인라이어 비율, 잔차 RMS, 수렴 여부, 게이트 상태, dead reckoning 시간,
적용한 기울기가 포함됩니다. 맵과 스캔을 겹쳐 보면서 함께 확인하세요. 잔차가 작다는
사실만으로 전역 위치가 정확하다고 판단할 수 없습니다.

## 5. 맵 파일 형식

`.kissmap`은 이 패키지가 정의한 형식이며 원본 라이브러리의 표준 교환 형식은 아닙니다.

| 필드 | 저장 형식 |
| --- | --- |
| 매직 값 | 8바이트 `KISSMAP1` |
| 복셀 크기 | float64 |
| 최대 거리 | float64 |
| 포인트 개수 | uint64 |
| 포인트 | 맵 기준 `x, y, z` float64를 포인트 개수만큼 반복 |

Python 변환기는 little-endian으로 쓰고 C++ IO는 플랫폼의 이진 형식을 사용합니다.
대상인 x86-64/ARM64처럼 little-endian 플랫폼을 사용하세요. 파일의 복셀 크기는
메타데이터이며 실제 포인트 밀도는 변환 또는 매핑 과정에서 정해집니다.

## 6. 검증

`colcon test --packages-select kinematic_localization`과
`colcon test-result --verbose`를 실행하세요. 설정 테스트는 파일 누락과 스키마 일치를,
C++ 테스트는 동기화 판단과 기울기 보정을 검사합니다. 로봇 적용 전에는 대표적인
센서 데이터로 별도 검증하세요. CI의 시작 검사와 단위 테스트는 위치추정 정확도를
측정하지 않습니다.
