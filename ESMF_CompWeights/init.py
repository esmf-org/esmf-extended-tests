#!/usr/bin/python
# coding: utf-8
#

import sys, os, re
from subprocess import check_call
from time import localtime, strftime

def esmf(RUNDIR, SRCDIR, platform, branch, esmfmkfile, gnu10):
    # # 1.2 initialize: build and install ESMF
    ESMFMKFILE=""
    if (esmfmkfile != ""):
        try:
            # verify validity of ESMFMKFILE before accepting
            accept = False
            with open(esmfmkfile) as esmfmkf:
                for line in esmfmkf:
                    if "ESMF environment variables pointing to 3rd party software" in line: accept = True
            if accept:
                print ("\nSkip ESMF build, esmf.mk provided.")
                ESMFMKFILE = esmfmkfile
            else:
                print ("\nSorry, there is something wrong with the provided esmf.mk, please check it and resubmit: ", esmfmkfile)
                raise EnvironmentError
        except EnvironmentError as err:
            raise
    else:
        try:
            print ("\nBuild and install ESMF (<30 minutes):", strftime("%a, %d %b %Y %H:%M:%S", localtime()))

            # call from RUNDIR to avoid polluting execution dir with output files 
            BUILDDIR = os.path.join(RUNDIR)
            if not os.path.isdir(BUILDDIR):
                try:
                    os.makedirs(BUILDDIR)
                except OSError as exc: # Guard against race condition
                    if exc.errno != errno.EEXIST:
                        raise
            os.chdir(BUILDDIR)

            # checkout ESMF
            esmfgitrepo = "https://github.com/esmf-org/esmf.git"
            ESMFDIR = os.path.join(BUILDDIR, "esmf")
            if not os.path.isdir(ESMFDIR):
                try:
                    check_call(["git", "clone", esmfgitrepo])
                except OSError as exc: # Guard against race condition
                    if exc.errno != errno.EEXIST:
                        raise
            
            os.chdir(ESMFDIR)
            check_call(["git", "checkout", branch])

            # write the pbs script
            run_command = os.path.join(BUILDDIR, "buildESMF.pbs", ESMFDIR, branch, platform, str(gnu10))
            # set up the pbs script for submission to qsub on cheyenne or bash otherwise
            if platform == "Cheyenne":
                run_command = ["qsub", "-W block=true"] + run_command
            else:  
                run_command = ["bash"] + run_command

            check_call(run_command)

            # buildESMF.pbs writes location of esmf.mk to $ESMFDIR/esmfmkfile.out
            with open (os.path.join(ESMFDIR, "esmfmkfile.out"), "r") as esmfmkfileobj:
                ESMFMKFILE = esmfmkfileobj.read().replace("\n","")
            print ("ESMF build and installation success.", strftime("%a, %d %b %Y %H:%M:%S", localtime()))
        except:
            raise RuntimeError("Error building ESMF installation.")

    return ESMFMKFILE


def test(ESMFMKFILE, RUNDIR, SRCDIR, platform):
    ESMFBINDIR = None
    try:
        print ("Build test executable")

        # set up the pbs script for submission to qsub on cheyenne or bash otherwise
        run_command = [os.path.join(SRCDIR, "buildTest.pbs"), ESMFMKFILE, RUNDIR, SRCDIR, platform]
        if platform == "Cheyenne":
            run_command = ["qsub", "-W block=true"] + run_command
        else:  
            run_command = ["bash"] + run_command

        check_call(run_command)

        # get the directory of ESMF INSTALLATION BIN
        with open (ESMFMKFILE, "r") as esmfmkfileobj:
            for line in esmfmkfileobj:
                if "ESMF_APPSDIR" in line:
                    ESMFBINDIR = line.split("=")[1].rstrip()
        

        if isinstance(ESMFBINDIR, type(None)):
            raise RuntimeError("Could not read the ESMF_APPSDIR from esmf.mk")

    except:
        raise RuntimeError("Error building test executable.")

    return ESMFBINDIR