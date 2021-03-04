#!/usr/bin/python
# coding: utf-8
#
#
# Ryan O'Kuinghttons
# July 1, 2020
# profile.py

import sys, os
import numpy as np
import argparse
import subprocess
from time import localtime, strftime, time
import click

@click.command()
@click.option('-n', type=int, required=True, help='Number of processing cores')
@click.option('-testcase', type=str, required=True, help='Test case  [create,dual,grid2mesh,redist,regridbilinear,regridbilinearcorner,regridconservative,rendezvous]')
@click.option('--branch', type=str, default="develop", help='Branch of the ESMF repo to use, defaults to develop')
@click.option('--esmfmkfile', type=str, default="", help='Path to esmf.mk, will build ESMF if not supplied')
@click.option('--platform', type=str, default="Darwin", help='Platform configuration [Cheyenne, Darwin, Linux], defaults to Darwin')
@click.option('--runs', type=int, default=1, help='Number of runs, defaults to 1')
@click.option('--gnu10', is_flag=True, default=False, help='Fix for gnu10 ESMF compiler options, defaults to False')
@click.option('--collectdir', type=str, default="", help='Directory to use when only collecting results without running new tests')
def cli(n, testcase, branch, esmfmkfile, platform, runs, gnu10, collectdir):
    # Raw print arguments
    print("\nRunning 'profile.py' with following input parameter values: ")
    print("-n = ", n)
    print("-testcase = ", testcase)
    print("--branch = ", branch)
    print("--esmfmkfile = ", esmfmkfile)
    print("--platform = ", platform)
    print("--runs = ", runs)
    print("--gnu10 = ", gnu10)
    print("--collectdir = ", collectdir)

    # add config directory to sys.path, regardless of where this script was called from originally
    sys.path.insert(0,os.path.join(os.path.dirname(os.path.realpath(sys.argv[0])), "config"))

    # import platform specific specific parameters
    config = __import__(platform)

    clickargs = {"n" : n,
                 "testcase": testcase,
                 "branch": branch,
                 "esmfmkfile": esmfmkfile,
                 "platform": platform,
                 "runs": runs,
                 "gnu10": gnu10,
                 "collectdir": collectdir}

    EXECDIR = ""
    if collectdir == "":
        # 1 initialize: build and install esmf and tests with appropriate env vars
        try:
            from src import init
            ESMFMKFILE = init.esmf(config, clickargs)
            init.test(ESMFMKFILE, config, clickargs)
        except:
            raise RuntimeError("Error building the tests.")

        # 2 run: submit the test runs
        try:
            from src import run
            EXECDIR = run.test(config, clickargs)
        except:
            raise RuntimeError("Error submitting the tests.")

    if sys.version_info < (3, 5):
        raise EnvironmentError ("Sorry, Python 3.5 or higher is required for test result collection.")
        
    if collectdir != "":
        EXECDIR = collectdir

    # 3 post: collect the results into csv files
    try:
        from src import collectResults
        timingfile = collectResults.timing(EXECDIR, config, clickargs)
        memoryfile = collectResults.memory(EXECDIR, config, clickargs)
        
        print ("Results are in the following files:\n", timingfile, "\n", memoryfile)
    except:
        raise RuntimeError("Error collecting the test results.")

# # 4 report: manual, scp, copy and paste the files into drive spreadsheet and make the appropriate graphs
# 
# # scp rokuingh@cheyenne.ucar.edu:/glade/work/rokuingh/MBMeshPerformanceResults/runs/<num>/mbmesh_$testcase_timing_profile_results.csv .
# # more mbmesh_$testcase_timing_profile_results.csv | xclip -sel clip
# # scp rokuingh@cheyenne.ucar.edu:/glade/work/rokuingh/MBMeshPerformanceResults/runs/<num>/mbmesh_$testcase_memory_profile_results.csv .
# # more mbmesh_$testcase_memory_profile_results.csv | xclip -sel clip


if __name__ == '__main__':
    cli()