#!/usr/bin/python
# coding: utf-8

import os, re
import subprocess
from shutil import copy2
from time import localtime, strftime
from math import floor
from threading import Thread
import numpy as np
import time
debug_verbosity_high = True

# from: https://stackoverflow.com/questions/2829329/catch-a-threads-exception-in-the-caller-thread-in-python
class PropagatingThread(Thread):
    def run(self):
        self.exc = None
        try:
            if hasattr(self, '_Thread__target'):
                # Thread uses name mangling prior to Python 3.
                self.ret = self._Thread__target(*self._Thread__args, **self._Thread__kwargs)
            else:
                self.ret = self._target(*self._args, **self._kwargs)
        except BaseException as e:
            self.exc = e

        return self.ret

    def join(self):
        super(PropagatingThread, self).join()
        if self.exc:
            raise self.exc
        return self.ret

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
    status = 0

    # this method found at https://stackoverflow.com/questions/48763362/python-subprocess-kill-with-timeout requires ps_util
    import psutil
    parent=subprocess.Popen(args[0]+[kwargs["weights"], kwargs["mb"]])
    for _ in range(kwargs["rwgtimeout"]): # xx seconds
        if parent.poll() is not None:  # process just ended
            status = 4.2
            break
        time.sleep(1)
    else:
        # the for loop ended without break: timeout
        parent = psutil.Process(parent.pid)
        for child in parent.children(recursive=True):  # or parent.children() for recursive=False
            child.kill()
        parent.kill()

    # try:
    #     subprocess.check_call(args[0]+[kwargs["weights"], kwargs["mb"]], timeout=kwargs["rwgtimeout"])
    # except subprocess.TimeoutExpired as exc:
    #     if debug_verbosity_high:
    #         print (exc)
    #         print ("MPI jobs cannot be reliably killed from Python, it is recommended to issue 'ps' to identify and kill all hanging MPI jobs")
    # else:
    #     # add Status columns to the dataframe
    #     with open (kwargs["weights"]+".out", "r") as outfileobj:
    #         for line in outfileobj:
    #             if "Completed weight generation successfully." in line:
    #                 status = 4.2

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

        weights=srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method+".nc"
        weights_mb=srcgrid.rsplit(".nc",1)[0]+"_to_"+dstgrid.rsplit(".nc",1)[0]+"_"+method+"_mb"+".nc"

        # set up the call to the pbs script
        pbs_rwg = os.path.join(SRCDIR, "runRWG.pbs")
        pbs_args = [str(n), EXECDIR, platform, os.path.join(DATADIR, srcgrid), os.path.join(DATADIR, dstgrid), method, options]

        run_command = ""
        if platform == "Cheyenne":
            run_command = ["qsub", "-N", "runRWG", "-A", "P93300606", "-l",  
                           "walltime=00:30:00", "-q", "economy", "-l",
                           "select=1:ncpus=36:mpiprocs=36", "-j", "oe", "-m", "n", 
                           "-W", "block=true", "--", pbs_rwg] + pbs_args

            job_threads.append(PropagatingThread(target=call_script, args=run_command, rwgtimeout=rwgtimeout, weights=weights, mb=""))
            job_threads.append(PropagatingThread(target=call_script, args=run_command, rwgtimeout=rwgtimeout, weights=weights_mb, mb="--moab"))
        # call all jobs without submitting to queue (serial) to avoid memory issues
        else:
            run_command = ["bash", pbs_rwg] + pbs_args
            status[index, 0] = call_script(run_command, rwgtimeout=rwgtimeout, weights=weights, mb="")
            print (".", end=" ", flush=True)
            status[index, 1] = call_script(run_command, rwgtimeout=rwgtimeout, weights=weights_mb, mb="--moab")
            print (".", end=" ", flush=True)

    # call jobs in queue (parallel)
    if platform == "Cheyenne":
        for index, job in enumerate(job_threads):
            status[index, :] = job.start()
    
        for job in job_threads:
            job.join()
            print (".", end=" ", flush=True)

    status_str = np.empty(status.shape, dtype=str)
    for index, val in np.ndenumerate(status):
        if status[index] == 4.2:
            status_str[index] = "P"
        else:
            status_str[index] = "F"

    df['Status RWG MBMesh'] = status_str[:,1].tolist()
    df['Status RWG Native'] = status_str[:,0].tolist()

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

        print ("\nAll jobs completed successfully.", strftime("%a, %d %b %Y %H:%M:%S", localtime()))
    
    except:
        raise RuntimeError("Error submitting the jobs.")

    return EXECDIR