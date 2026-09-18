# Third-party code

The repository includes only the C++ dependency trees needed by localization,
with upstream licenses retained. Vendored directories contain `COLCON_IGNORE`
so colcon discovers only the application package.

| Component | Upstream | Bundled version | License |
| --- | --- | --- | --- |
| Kinematic-ICP core | [PRBonn/kinematic-icp](https://github.com/PRBonn/kinematic-icp) | CMake project version 0.1.1, locally patched | [MIT](third_party/kinematic-icp/LICENSE) |
| KISS-ICP | [PRBonn/kiss-icp](https://github.com/PRBonn/kiss-icp) | 1.2.0 | [MIT](third_party/kiss-icp/LICENSE) |
| Sophus | [strasdat/Sophus](https://github.com/strasdat/Sophus) | 1.22.10, bundled patch applied | [MIT](third_party/sophus/LICENSE.txt) |
| robin-map | [Tessil/robin-map](https://github.com/Tessil/robin-map) | 1.2.1 | [MIT](third_party/robin-map/LICENSE) |

Kinematic-ICP is a modified source snapshot, not a claim of equivalence to an
unmodified upstream release. Local core changes include frozen-map operation,
empty-correspondence guards, registration diagnostics, optional lateral motion,
independent source voxel size, and experimental free-corner registration.
The CMake integration prefers bundled sources. Do not replace it with upstream
sources without carrying over the patches required by the ROS package.

`src/kinematic_localization/src/utils.hpp` adapts upstream ROS utilities and
retains their copyright and permission notice. Eigen and TBB are external system
dependencies, not copied application packages.

Original method: Tiziano Guadagnino et al.,
*Kinematic-ICP: Enhancing LiDAR Odometry with Kinematic Constraints for Wheeled
Mobile Robots Moving on Planar Surfaces*,
[arXiv:2410.10277](https://arxiv.org/abs/2410.10277).
