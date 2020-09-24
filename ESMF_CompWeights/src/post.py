#!/usr/bin/python
# coding: utf-8

import os, re, sys
from subprocess import check_call, TimeoutExpired
from shutil import copy2
from time import localtime, strftime
from math import floor
import numpy as np
import pandas
from src.propagatingthread import PropagatingThread

def call_script(*args, **kwargs):
    status = 4.2

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
                    status = kwargs["tol"]
                elif "FAIL" in line:
                    status = 6.9

    return status

def do(EXECDIR, config, clickargs):
    SRCDIR = config.SRCDIR
    MODULES = config.modules
    MPIRUN = config.mpirun
    tol = config.diff_tolerance

    platform = clickargs["platform"]
    rwgtimeout = clickargs["rwgtimeout"]

    # read the dataframe generated during previous execution
    df = pandas.read_csv(os.path.join(EXECDIR, "StatusDataFrame.csv"))

    # create numpy array of length of data frame for status values
    status = 7.7*np.ones(len(df))

    # set up DiffWeights jobs to be run
    job_list = []
    run_command = []
    # used to map indices of threads to dataframe
    thread2dataframe_map = []
    for index, testcase in df.iterrows():
        if (testcase["RWG MBMesh"] == "Pass") and (testcase["RWG Native"] == "Pass"):

            thread2dataframe_map.append(index)

            srcgrid = testcase["SourceGrid"].strip()
            dstgrid = testcase["DestinationGrid"].strip()
            method = testcase["RegridMethod"].strip()

            weights_base = srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method
            weights = weights_base+".nc"
            weights_mb_base = srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method+"_mb"
            weights_mb=weights_mb_base+".nc"

            # set up the call to the pbs script
            pbs_dw = os.path.join(SRCDIR, "runDiffWeights.pbs")
            pbs_args = [EXECDIR, MODULES, MPIRUN, weights, weights_mb, str(tol)]

            run_command = ""
            if platform == "Cheyenne":
                run_command = ["qsub", "-N", "runDiffWeights", "-A", "P93300606", "-l",  
                               "walltime=00:30:00", "-q", "economy", "-l",
                               "select=1:ncpus=36:mpiprocs=36", "-j", "oe", "-m", "n", 
                               "-W", "block=true", "--", pbs_dw] + pbs_args
            else:
                run_command = ["bash", pbs_dw] + pbs_args
            # this should be a tuple, but tolerance needs to be updated..
            job_list.append([run_command, weights, tol])

    # call jobs in queue (parallel)
    if platform == "Cheyenne":
        jobs_running = []
        for jobtuple in job_list:
            job_ready = PropagatingThread(target=call_script, args=(jobtuple[0],), kwargs={"weights" : jobtuple[1], "tol" : jobtuple[2]})
            job_ready.start()
            jobs_running.append(job_ready)
        for index, job in enumerate(jobs_running):
            status[thread2dataframe_map[index]] = job.join()
            print (".", end=" ", flush=True)
    # execute jobs in serial
    else:
        for index, jobtuple in enumerate(job_list):
            status[thread2dataframe_map[index]] = call_script(jobtuple[0], weights=jobtuple[1], tol=jobtuple[2])
            print (".", end=" ", flush=True)

    # iterate DiffWeights until passing tolerance level is found, or 0
    while np.any(status[:] == 6.9):
        ind = np.where(status[:] == 6.9)
        for j in ind[0]:
            k = thread2dataframe_map[j]

            job_tuple = job_list[k]
            run_command = job_tuple[0]
            weights = job_tuple[1]
            tol = job_tuple[2]

            # update tol
            tol10 = tol * 10
            if tol10 > 1e-1:
                break
            run_command[-1] = str(tol10)
            job_list[k][2] = tol10

            jobs_running = []
            if platform == "Cheyenne":
                job = PropagatingThread(target=call_script, args=(run_command,), kwargs={"weights" : weights, "tol" : tol10})
                job.start()
                jobs_running.append((job, k))
            else:
                status[k] = call_script(run_command, weights=weights, tol=tol10)
                print (".", end=" ", flush=True)
        if platform == "Cheyenne":
            for jobtuple in enumerate(jobs_running):
                status[jobtuple[1]] = jobtuple[0].join()
                print (".", end=" ", flush=True)

    # convert numerical status values to strings for addition to the dataframe
    status_str = []
    for i in range(status.shape[0]):
        if status[i] == 4.2:
            status_str.append("OhNO!")
        elif status[i] == 6.9:
            status_str.append("Fail")
        elif status[i] == 7.7:
            status_str.append("N/A")
        else:
            status_str.append(str('{:.0e}'.format(status[i])))

    df['Diff Weights'] = status_str

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

        # trim some columns from the dataframe
        keep_col = ["SourceGrid", "DestinationGrid", "RegridMethod","Options", "RWG MBMesh", "RWG Native", "Diff Weights"]
        dfPrint = dfPass[keep_col]
        print ('')
        print (dfPrint)

        print ("\nWeight file comparison completed successfully.", strftime("%a, %d %b %Y %H:%M:%S", localtime()))
    
    except:
        raise RuntimeError("Error submitting the tests.")
