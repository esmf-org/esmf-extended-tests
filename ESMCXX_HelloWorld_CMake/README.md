ESMCXX_HelloWorld_CMake
=======================

This directory contains code that is based on the ESMF C API (commonly referred to as ESMC) from C++.

The application writes ">>> Hello ESMC World from C++ <<<" to the ESMF default log (see PET*.ESMF_LogFile's).

The main purpose of this example is to demonstrate the use of CMake for ESMF applications written in C++. The code is accompanied by `CMakeLists.txt` and `cmake/FindESMF.cmake` files.

Notice the dependency of the example on a relatively recent release of CMake: version 3.22. This is specified in file `CMakeLists.txt`. The primary reason for this restictive dependency is that not until version 3.22 was it supported to use the `find_package()` and `set()` functions before `project()`. Hence it was more difficult in the older versions to specified the compilers consistent with those used by ESMF.

Notice that it is possible to get the desired end result with previous versions of CMake, requiring some re-arranging of the order of functions in `CMakeLists.txt`. However, the more recently supported order of functions leads to a simpler and more intuitive version of `CMakeLists.txt` file shown here.

The code can be built using any of the usual CMake build procedures:

    mkdir build; cd build
    cmake ..
    make

or alternatively using the `-S`, `-B`, and `--build` CMake options:

    cmake -S . -B ./build
    cmake --build ./build

And execute on 8 PETs, e.g. via mpirun:

    mpirun -np 8  ./build/ESMCXX_HelloWorld

================================================================================

Please contact esmf_support@ucar.edu with any questions or problems.

================================================================================
