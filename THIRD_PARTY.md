# Third-party dependencies

Dependencies are Git submodules of the official upstream repositories, pinned to
specific commits. Their original licenses remain in the submodules. Only the C++
libraries are built; `third_party/COLCON_IGNORE` prevents colcon from discovering
upstream ROS packages in these trees.

| Component | Upstream | Pinned revision | License |
| --- | --- | --- | --- |
| Kinematic-ICP | [PRBonn/kinematic-icp](https://github.com/PRBonn/kinematic-icp) | `d5b513e7a4822362e8307fbed5ff52f0b502a9eb` | [MIT](https://github.com/PRBonn/kinematic-icp/blob/d5b513e7a4822362e8307fbed5ff52f0b502a9eb/LICENSE) |
| KISS-ICP | [PRBonn/kiss-icp](https://github.com/PRBonn/kiss-icp) | `74c1fe8f0c1da91124b81afebe57cf4d828658ea` (`v1.2.0`) | [MIT](https://github.com/PRBonn/kiss-icp/blob/74c1fe8f0c1da91124b81afebe57cf4d828658ea/LICENSE) |
| Sophus | [strasdat/Sophus](https://github.com/strasdat/Sophus) | `de0f8d3d92bf776271e16de56d1803940ebccab9` (`1.22.10`) | [MIT](https://github.com/strasdat/Sophus/blob/de0f8d3d92bf776271e16de56d1803940ebccab9/LICENSE.txt) |
| robin-map | [Tessil/robin-map](https://github.com/Tessil/robin-map) | `d37a41003bfbc7e12e34601f93c18ca2ff6d7c07` (`v1.2.1`) | [MIT](https://github.com/Tessil/robin-map/blob/d37a41003bfbc7e12e34601f93c18ca2ff6d7c07/LICENSE) |

## Initialize and build

```bash
git submodule update --init --recursive
```

Use `git clone --recurse-submodules` for a fresh clone. Submodules are not included
in GitHub source ZIP downloads. Run the update command after pulling changes to
the recorded gitlinks, then build with `--cmake-force-configure` to refresh patched
sources. Do not use `git submodule update --remote` for a reproducible
build: that selects upstream branch revisions instead of the recorded pins.

[cmake/Dependencies.cmake](cmake/Dependencies.cmake) checks that the submodules
exist and points FetchContent to local sources. It requires the `patch` utility
and creates patched Kinematic-ICP and Sophus copies under the package's build
directory. It never edits the submodule checkouts. Eigen and TBB remain external
system dependencies installed through `rosdep`.

## Preserved patches

- [kinematic-icp-localization.patch](patches/kinematic-icp-localization.patch)
  adds frozen-map operation, empty-correspondence guards, registration diagnostics,
  optional lateral motion, independent source voxel size, and experimental
  free-corner registration. It changes four core C++ files.
- Sophus receives the compatibility patch supplied by the pinned KISS-ICP at
  `cpp/kiss_icp/3rdparty/sophus/sophus.patch`. Source overrides bypass FetchContent's
  normal patch step, so the CMake helper applies this patch explicitly.

Build copies are recreated when CMake configures so patch application is repeatable.
A patch failure stops configuration. When updating a submodule, review and rebase
the patches, record the new gitlink, update the revision table, and run the full
ROS 2 build/tests. Confirm `git submodule foreach git status --short` is empty.

`src/kinematic_localization/src/utils.hpp` adapts upstream ROS utilities and
retains their copyright and permission notice.

Original method: Tiziano Guadagnino et al.,
*Kinematic-ICP: Enhancing LiDAR Odometry with Kinematic Constraints for Wheeled
Mobile Robots Moving on Planar Surfaces*,
[arXiv:2410.10277](https://arxiv.org/abs/2410.10277).
