cmake_minimum_required(VERSION 3.0)
enable_language(Fortran)

# Project
project(ESMF_HelloWorld_CMake)
add_executable(ESMF_HelloWorld ESMF_HelloWorld.F90)

# Where to look for Find<Package>.cmake files
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Find ESMF
find_package(ESMF REQUIRED) 

# Project depends on ESMF
target_link_libraries(ESMF_HelloWorld ESMF) 

# Set compilers per ESMFMKFILE
set(CMAKE_CXX_COMPILER ${ESMF_CXXCOMPILER})
set(CMAKE_Fortran_COMPILER ${ESMF_F90LINKER})

# Diagnostic output
get_filename_component (Fortran_COMPILER_NAME ${CMAKE_Fortran_COMPILER} NAME)
message("------------------------------------")
message("Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION} (${Fortran_COMPILER_NAME})")
message("------------------------------------")


