################################################################################
# Configuration  step:           cmake -S . -B ./build
# Build step:                    cmake --build ./build -v
# Execution step:                mpirun -np 8  ./build/ESMC_HelloWorld
# Clean-up step:                 rm -rf ./build PET*
################################################################################

cmake_minimum_required(VERSION 3.22)

# Where to look for the local Find<Package>.cmake files
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Find ESMF
find_package(ESMF 8.3.0 MODULE REQUIRED)

# Set compilers consistent with ESMF
set(CMAKE_Fortran_COMPILER        "${ESMF_F90COMPILER}")
set(CMAKE_CXX_COMPILER            "${ESMF_CXXCOMPILER}")
set(CMAKE_C_COMPILER              "${ESMF_CCOMPILER}")

# Optionally set compiler options consistent with ESMF
set(CMAKE_Fortran_FLAGS           "${ESMF_F90COMPILEOPTS}")
set(CMAKE_CXX_FLAGS               "${ESMF_CXXCOMPILEOPTS}")
set(CMAKE_C_FLAGS                 "${ESMF_CCOMPILEOPTS}")

# Project
project(ESMC_HelloWorld_CMake
        VERSION 1.0
        LANGUAGES Fortran CXX C
        )

# Executable
add_executable(ESMC_HelloWorld ESMC_HelloWorld.c)

# Executable depends on ESMF
target_link_libraries(ESMC_HelloWorld ESMF::ESMC)

# Support C99 standard
set_target_properties(ESMC_HelloWorld PROPERTIES C_STANDARD 99)
