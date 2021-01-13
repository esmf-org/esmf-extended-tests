#!/usr/bin/python
# coding: utf-8
#
# Ryan O'Kuinghttons
# July 20, 2020
# profile.py

import sys, os
import numpy as np
import argparse
import subprocess
from time import localtime, strftime, time
import click
import pandas
import psutil

@click.command()
@click.option('--n', type=int, default=4, help='Number of processing cores, default to 4')
# @click.option('--testcase', type=str, default="", help='Single test case to run')
@click.option('--branch', type=str, default="develop", help='Branch of the ESMF repo to use, default to develop')
@click.option('--esmfmkfile', type=str, default="", help='Path to esmf.mk, will build ESMF if not supplied')
@click.option('--platform', type=str, default="Linux", help='Platform configuration [Cheyenne, Darwin, Linux], defaults to Linux')
@click.option('--gnu10', is_flag=True, default=True, help='Fix for gnu10 ESMF compiler options, defaults to True')
@click.option('--rwgtimeout', type=int, default=60, help='Timeout in seconds for RegridWeightGen.F90, defaults to 60 seconds')
@click.option('--debug_execdir', type=str, default="", help='Execution directory to use for debugging purposes')
def cli(n, branch, esmfmkfile, platform, gnu10, rwgtimeout, debug_execdir):
    # Raw print arguments
    print("\nRunning 'compweights.py' with following input parameter values: ")
    print("--n = ", n)
    # print("--testcase = ", testcase)
    print("--branch = ", branch)
    print("--esmfmkfile = ", esmfmkfile)
    print("--platform = ", platform)
    print("--gnu10 = ", gnu10)
    print("--rwgtimeout = ", rwgtimeout)
    print("--debug_execdir = ", debug_execdir)
    EXECDIR = debug_execdir

    # add config directory to sys.path, regardless of where this script was called from originally
    sys.path.insert(0,os.path.join(os.path.dirname(os.path.realpath(sys.argv[0])), "config"))

    # import platform specific specific parameters
    config = __import__(platform)

    clickargs = {"n" : n,
                 # "testcase": testcase,
                 "branch": branch,
                 "esmfmkfile": esmfmkfile,
                 "platform": platform,
                 "gnu10": gnu10,
                 "rwgtimeout": rwgtimeout}

    df_dirty = pandas.read_csv(os.path.join(config.CFGDIR, config.RegridTestData), sep=":", skipinitialspace=True, comment="#")
    df = df_dirty.apply(lambda x: x.str.strip() if x.dtype == "object" else x)

    # if we are not in debug mode
    if EXECDIR == "":
        # 1 initialize: build and install esmf and tests with appropriate env vars
        try:
            from src import init
            ESMFMKFILE, ESMFBINDIR = init.esmf(config, clickargs)
            init.test(ESMFMKFILE, config, clickargs)
        except:
            raise RuntimeError("Error building the tests.")
        
        # 2 run: submit the test runs
        try:
            from src import run
            EXECDIR = run.test(df, ESMFBINDIR, config, clickargs)
        except:
            raise RuntimeError("Error submitting the tests.")

    # 3 post: collect the results into csv files
    try:
        from src import post
        post.process(EXECDIR, config, clickargs)
    except:
        raise RuntimeError("Error processing the test results.")

if __name__ == '__main__':
    cli()