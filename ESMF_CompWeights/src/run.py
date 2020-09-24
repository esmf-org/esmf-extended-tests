#!/usr/bin/python
# coding: utf-8

import os, re
import subprocess
from shutil import copy2
from time import localtime, strftime
from math import floor
import numpy as np
import time
from src.propagatingthread import PropagatingThread

debug_verbosity_high = True

def generate_id(ROOTDIR):
    import os, re

    RUNDIR = os.path.join(ROOTDIR, "runs")

    if not os.path.isdir(RUNDIR):
        try:
            os.makedirs(RUNDIR)
        except OSError as exc: # Guard against race condition
            if exc.errno != errno.EEXIST:
                raise

    dirnums = []
    for path in os.listdir(RUNDIR):
        directory = os.path.join(RUNDIR, path)
        if os.path.isdir(directory):
            head, tail = os.path.split(directory)
            dirnums.append(int(tail))

    EXECDIR = os.path.join(RUNDIR, str(max(dirnums or [0]) + 1))

    if not os.path.isdir(EXECDIR):
        try:
            os.makedirs(EXECDIR)
        except OSError as exc: # Guard against race condition
            if exc.errno != errno.EEXIST:
                raise

    return (EXECDIR)

def call_script(*args, **kwargs):
    status = 4.2

    # this method found at https://stackoverflow.com/questions/48763362/python-subprocess-kill-with-timeout requires ps_util
    import psutil

    args_local = args[0]
    if type(args[0]) is str:
        args_local = args[0].split(",")

    run_command = list(args_local)+[kwargs["weights"], kwargs["mb"]]

    parent=subprocess.Popen(run_command)
    for _ in range(kwargs["rwgtimeout"]): # xx seconds
        if parent.poll() is not None:  # process just ended
            status = parent.returncode
            break
        time.sleep(1)
    else:
        # the for loop ended without break: timeout
        parent = psutil.Process(parent.pid)
        for child in parent.children(recursive=True):  # or parent.children() for recursive=False
            child.kill()
        parent.kill()
        status = 6.9

    return status

def setup(df):
    try:
        # use a set to only save unique grids
        grids = {}
        for index, testcase in df.iterrows():
            datadir = "http://www.earthsystemmodeling.org/download/data"
            srcgrid = testcase["SourceGrid"].strip()
            dstgrid = testcase["DestinationGrid"].strip()
           
            grids[srcgrid] = os.path.join(datadir, srcgrid)
            grids[dstgrid] = os.path.join(datadir, dstgrid)

        for grid, uri in grids.items():
            if not os.path.isfile(grid):
                subprocess.check_call(["wget", uri])

    except:
        raise RuntimeError("Error downloading the data files.")

def do(df, EXECDIR, DATADIR, config, clickargs):

    SRCDIR = config.SRCDIR
    MODULES = config.modules
    MPIRUN = config.mpirun

    n = clickargs["n"]
    platform = clickargs["platform"]
    rwgtimeout = clickargs["rwgtimeout"]

    # create numpy array of length of data frame by two for status values
    status = np.zeros([len(df), 2])

    job_threads = []
    run_command = []
    for index, testcase in df.iterrows():
        srcgrid = testcase["SourceGrid"].strip()
        dstgrid = testcase["DestinationGrid"].strip()
        method = testcase["RegridMethod"].strip()
        options = testcase["Options"]

        weights=os.path.join(EXECDIR,srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method)
        weights_mb=os.path.join(EXECDIR,srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method+"_mb")

        # set up the call to the pbs script
        pbs_rwg = os.path.join(SRCDIR, "runRWG.pbs")
        pbs_args = [str(n), EXECDIR, MODULES, MPIRUN, os.path.join(DATADIR, srcgrid), os.path.join(DATADIR, dstgrid), method, options]

        run_command = ""
        if platform == "Cheyenne":
            run_command = ["qsub", "-N", "runRWG", "-A", "P93300606", "-l",  
                           "walltime=00:30:00", "-q", "economy", "-l",
                           "select=1:ncpus=36:mpiprocs=36", "-j", "oe", "-m", "n", 
                           "-W", "block=true", "--", pbs_rwg] + pbs_args

            # csv string to preserve spaces from input (options)
            run_command2 = ','.join(run_command)

            # pass as a tuple to avoid PropagatingThread expanding incorrectly to list (spaces in options)
            job1 = PropagatingThread(target=call_script, args=(run_command,), kwargs={'rwgtimeout' : rwgtimeout, 'weights' : weights, 'mb' : ""})
            job2 = PropagatingThread(target=call_script, args=(run_command,), kwargs={'rwgtimeout' : rwgtimeout, 'weights' : weights_mb, 'mb' : '--moab'})

            # set up as a tuple of two jobs to conform to the structure of two runs per row of the data frame
            job_threads.append((job1, job2))

        # call all jobs without submitting to queue (serial) to avoid memory issues
        else:
            # pass as a tuple string
            run_command = ["bash", pbs_rwg] + pbs_args
            run_command2 = (','.join(run_command))

            status[index, 0] = call_script(run_command2, rwgtimeout=rwgtimeout, weights=weights, mb="")
            print (".", end=" ", flush=True)

            status[index, 1] = call_script(run_command2, rwgtimeout=rwgtimeout, weights=weights_mb, mb="--moab")
            print (".", end=" ", flush=True)


    # call jobs in queue (parallel)
    if platform == "Cheyenne":
        for jobtuple in job_threads:
            jobtuple[0].start()
            jobtuple[1].start()
    
        for index, jobtuple in enumerate(job_threads):
            status[index, 0] = jobtuple[0].join()
            print (".", end=" ", flush=True)
            status[index, 1] = jobtuple[1].join()
            print (".", end=" ", flush=True)

    status_str = np.zeros(shape=status.shape, dtype='<U256')
    for (x,y), val in np.ndenumerate(status):
        if val == 0:
            status_str[x,y] = "Pass"
        elif val == 6.9:
            status_str[x,y] = "Timeout"
        else:
            status_str[x,y] = "Fail"

    df['RWG MBMesh'] = status_str[:,1].tolist()
    df['RWG Native'] = status_str[:,0].tolist()

    # write status df to read when post processing in separate execution
    df.to_csv(os.path.join(EXECDIR, "StatusDataFrame.csv"))

    return df

def test(df, ESMFBINDIR, config, clickargs):
    try:
        print ("\nSubmit the jobs for weight file generation:", strftime("%a, %d %b %Y %H:%M:%S", localtime()))

        RUNDIR = config.RUNDIR

        n = clickargs["n"]
        platform = clickargs["platform"]
        rwgtimeout = clickargs["rwgtimeout"]

        # first download all grid files
        DATADIR = os.path.join(RUNDIR, "data")
        if not os.path.isdir(DATADIR):
            try:
                os.makedirs(DATADIR)
            except OSError as exc: # Guard against race condition
                if exc.errno != errno.EEXIST:
                    raise
        # call setup from DATADIR so all runs can use the same datafiles
        os.chdir(DATADIR)
        setup(df)

        # call from EXECDIR to avoid polluting the source directory with output files 
        EXECDIR = generate_id(RUNDIR)
        os.chdir(EXECDIR)
        
        # copy executables to EXECDIR
        copy2(os.path.join(ESMFBINDIR, "ESMF_RegridWeightGen"), EXECDIR) # created by init.esmf()

        # Run RegridWeightGen.F90 on all testcases for Native and MBMesh, return dataframe with Status columns added
        do(df, EXECDIR, DATADIR, config, clickargs)

        print ("\nAll jobs completed.", strftime("%a, %d %b %Y %H:%M:%S", localtime()))
    
    except:
        raise RuntimeError("Error submitting the jobs.")

    return EXECDIR