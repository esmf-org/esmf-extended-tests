ESMF_HelloWorld_CMake
=====================

This directory contains code that is based on the ESMF Fortran API.

The application writes ">>> Hello ESMF World <<<" to the ESMF default log (see PET*.ESMF_LogFile's).

The main purpose of this example is to demonstrate the use of CMake for ESMF applications written in Fortran. The code is accompanied by `CMakeLists.txt` that leverages the standard ESMF CMake package configuration file that is installed for ESMF version 9 and higher.

> [!IMPORTANT]
> CMake uses the `CMAKE_PREFIX_PATH` environment variable to search for package configuration files. Ensure that the ESMF installation root directory is included in this path. Spack loaded installations automatically satisfy this requirement.

The code can be built using any of the usual CMake build procedures:

    mkdir build; cd build
    cmake ..
    make

or alternatively using the `-S`, `-B`, and `--build` CMake options:

    cmake -S . -B ./build
    cmake --build ./build

And execute on 8 PETs, e.g. via mpirun:

    mpirun -np 8  ./build/ESMF_HelloWorld

================================================================================

Please contact esmf_support@ucar.edu with any questions or problems.

================================================================================
