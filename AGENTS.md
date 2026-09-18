# Repository guidance

This repository contains only the kinematic localization ROS 2 package and its
C++ dependencies as pinned upstream submodules. Do not add other vehicle-stack packages, recorded data,
private maps, or history from a parent repository.

- Target ROS 2 Jazzy; runtime nodes are C++17.
- Read the package-level AGENTS.md before editing nodes.
- Keep ROS interfaces standard and configuration in YAML.
- Preserve upstream license notices and local ICP patches.
- Keep submodule worktrees clean. Store localization changes in `patches/` and
  apply them to build-tree copies through `cmake/Dependencies.cmake`.
- Keep default documentation in English and Korean translations in `docs/ko/`.
  Link both languages and keep their instructions consistent with the code.
- Run colcon build and colcon test on Jazzy for runtime changes. Report any checks
  that could not run; do not claim hardware validation from unit tests.
