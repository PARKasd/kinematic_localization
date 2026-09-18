# Use pinned upstream submodules without modifying their working trees.
get_filename_component(_localization_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(_third_party "${_localization_root}/third_party")

foreach(_dependency kinematic-icp kiss-icp sophus robin-map)
  if(NOT EXISTS "${_third_party}/${_dependency}/LICENSE" AND
     NOT EXISTS "${_third_party}/${_dependency}/LICENSE.txt")
    message(FATAL_ERROR
      "Missing ${_dependency} submodule. From the repository root, run: "
      "git submodule update --init --recursive")
  endif()
endforeach()

find_program(_patch_program patch)
if(NOT _patch_program)
  message(FATAL_ERROR "The patch utility is required to prepare localization dependencies.")
endif()

function(_localization_patch_copy name patch_file output_variable)
  set(destination "${CMAKE_CURRENT_BINARY_DIR}/patched_dependencies/${name}")
  # Recreate on configure so applying a patch is repeatable, including after a
  # submodule revision changes. Only generated sources in the build tree are removed.
  file(REMOVE_RECURSE "${destination}")
  file(MAKE_DIRECTORY "${destination}")
  file(COPY "${_third_party}/${name}/" DESTINATION "${destination}"
       PATTERN ".git" EXCLUDE)
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${patch_file}")
  execute_process(
    COMMAND "${_patch_program}" -p1 --batch --forward -i "${patch_file}"
    WORKING_DIRECTORY "${destination}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error)
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Cannot apply ${name} patch:\n${output}\n${error}")
  endif()
  set(${output_variable} "${destination}" PARENT_SCOPE)
endfunction()

_localization_patch_copy(kinematic-icp
  "${_localization_root}/patches/kinematic-icp-localization.patch" _kinematic_source)
_localization_patch_copy(sophus
  "${_third_party}/kiss-icp/cpp/kiss_icp/3rdparty/sophus/sophus.patch" _sophus_source)

# Source overrides skip FetchContent's download and patch steps. Sophus's
# upstream KISS-ICP compatibility patch has therefore been applied above.
set(FETCHCONTENT_SOURCE_DIR_KISS_ICP "${_third_party}/kiss-icp" CACHE PATH "" FORCE)
set(FETCHCONTENT_SOURCE_DIR_SOPHUS "${_sophus_source}" CACHE PATH "" FORCE)
set(FETCHCONTENT_SOURCE_DIR_TESSIL "${_third_party}/robin-map" CACHE PATH "" FORCE)
set(USE_SYSTEM_SOPHUS OFF CACHE BOOL "Use the pinned Sophus submodule" FORCE)
set(USE_SYSTEM_TSL-ROBIN-MAP OFF CACHE BOOL "Use the pinned robin-map submodule" FORCE)
add_subdirectory("${_kinematic_source}/cpp/kinematic_icp"
                 "${CMAKE_CURRENT_BINARY_DIR}/kinematic_icp_core")
