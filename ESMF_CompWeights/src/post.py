#!/usr/bin/python
# coding: utf-8

import os, re
from subprocess import check_call, TimeoutExpired
from shutil import copy2
from time import localtime, strftime
from math import floor
import numpy as np
import pandas
from src.propagatingthread import PropagatingThread

def call_script(*args, **kwargs):
    status = 0

    args_local = args[0]
    if type(args[0]) is str:
        args_local = args[0].split(",")

    try:
        check_call(args_local)
    except:
        print (sys.exc_info()[0])
        raise
    else:
        # add Status columns to the dataframe
        with open (kwargs["weights"]+"-DiffWeights.out", "r") as outfileobj:
            for line in outfileobj:
                if "SUCCESS" in line:
                    status = 4.2

    return status

def do(EXECDIR, config, clickargs):
    SRCDIR = config.SRCDIR
    MODULES = config.modules
    MPIRUN = config.mpirun

    platform = clickargs["platform"]
    rwgtimeout = clickargs["rwgtimeout"]

    # read the dataframe generated during previous execution
    df = pandas.read_csv(os.path.join(EXECDIR, "StatusDataFrame.csv"))

    # create numpy array of length of data frame for status values
    status = np.zeros(len(df))

    # run DiffWeights on all testcase pairs with positive Status
    job_threads = []
    run_command = []
    for index, testcase in df.iterrows():
        if (testcase["Status RWG MBMesh"] == "P") and (testcase["Status RWG Native"] == "P"):

            srcgrid = testcase["SourceGrid"].strip()
            dstgrid = testcase["DestinationGrid"].strip()
            method = testcase["RegridMethod"].strip()
            options = testcase["Options"]

            weights_base = srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method
            weights = weights_base+".nc"
            weights_mb_base = srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method+"_mb"
            weights_mb=weights_mb_base+".nc"

            # set up the call to the pbs script
            pbs_dw = os.path.join(SRCDIR, "runDiffWeights.pbs")
            pbs_args = [EXECDIR, MODULES, MPIRUN, weights, weights_mb]

            run_command = ""
            if platform == "Cheyenne":
                run_command = ["qsub", "-N", "runDiffWeights", "-A", "P93300606", "-l",  
                               "walltime=00:30:00", "-q", "economy", "-l",
                               "select=1:ncpus=36:mpiprocs=36", "-j", "oe", "-m", "n", 
                               "-W", "block=true", "--", pbs_dw] + pbs_args
                job = PropagatingThread(target=call_script, args=(run_command,), kwargs={"weights" : weights})
                job_threads.append(job)

            # call all jobs without submitting to queue (serial) to avoid memory issues
            else:
                run_command = ["bash", pbs_dw] + pbs_args
                status[index] = call_script(run_command, weights=weights)
                print (".", end=" ", flush=True)

    # call jobs in queue (parallel)
    if platform == "Cheyenne":
        for job in job_threads:
            job.start()
        for index, job in enumerate(job_threads):
            status[index] = job.join()
            print (".", end=" ", flush=True)

    status_str = []
    for i in range(status.shape[0]):
        if status[i] == 4.2:
            status_str.append("Pass")
        else:
            status_str.append("Fail")

    df['Status Diff Weights'] = status_str

    return df

def process(EXECDIR, config, clickargs):
    SRCDIR = config.SRCDIR

    platform = clickargs["platform"]
    rwgtimeout = clickargs["rwgtimeout"]

    try:
        print ("\nCompare weight files:", strftime("%a, %d %b %Y %H:%M:%S", localtime()))

        # call from EXECDIR to avoid polluting the source directory with output files 
        os.chdir(EXECDIR)
        
        # copy executable to EXECDIR
        copy2(os.path.join(SRCDIR, "DiffWeights"), EXECDIR) # created by init.test()

        # Run DiffWeights.F90 on all testcase pairs which have positive Status, return dataframe with Pass column added
        dfPass = do(EXECDIR, config, clickargs)

        print ('')
        print (dfPass)

        print ("\nWeight file comparison completed successfully.", strftime("%a, %d %b %Y %H:%M:%S", localtime()))
    
    except:
        raise RuntimeError("Error submitting the tests.")
