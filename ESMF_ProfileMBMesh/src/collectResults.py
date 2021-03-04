#!/usr/bin/python
# coding: utf-8
#

import sys, os, math, re
import numpy as np
import subprocess
from time import localtime, strftime

def timing(EXECDIR, config, clickargs):
    try:
        import pandas as pd
    except:
        raise ImportWarning("Pandas not available, cannot collect timing results.")
        exit(0)

    print ("\nCollect timing results.")

    n = clickargs["n"]
    testcase = clickargs["testcase"]
    branch = clickargs["branch"]
    esmfmkfile = clickargs["esmfmkfile"]
    platform = clickargs["platform"]
    runs = clickargs["runs"]
    gnu10 = clickargs["gnu10"]

    procs = config.procs
    if (n > procs[-1]): raise ValueError("--n cannot be greater than "+str(procs[-1])+". Please adjust the 'procs' values in the configuration file for your platform.")

    timeoutfilename = os.path.join(EXECDIR, "mbmesh_"+testcase+"_timing_profile_results.csv")

    template_cols = 0
    template_cols_set = False
    
    col_names = ["Region", "PETs", "Count", "Mean (s)", "Min (s)", "Min PET", "Max (s)", "Max PET"]
    mmm_str = "Max (s)"
    region_str = "Region"

    for num_run in range(1,runs+1):
        for num_procs in procs:
            if num_procs <= n:

                resfilename = os.path.join(EXECDIR, str(num_procs)+"-"+str(num_run), "ESMF_Profile.summary")

                with open(resfilename) as f:
                    for line in f:
                        if region_str in line:
                            col_num = [line.index(substr) for substr in col_names]
       
                # df = pd.read_csv(rftmp, sep=r"\s{2,}", index_col=False, engine='python')
                col_num2 = np.array(col_num[1:]) - np.array(col_num[0:-1])
                df = pd.read_fwf(resfilename, width=col_num2)
                                
                # delete unwanted columns
                keep_col = [region_str, mmm_str]
                df = df[keep_col]
        
                # remove leading whitespace in titles
                df[region_str] = df[region_str].str.lstrip()
        
                # switch columns for rows
                df.set_index(region_str, inplace=True)
                df = df.T
                
                # switch mmm_str to number of cores
                df.rename(index={mmm_str:str(num_procs)}, inplace=True)

                # reorder the columns to the order of the template
                if not template_cols_set:
                    # alphabetise columns
                    df = df.reindex(sorted(df.columns), axis=1)
                    # set the template columns from this dataframe
                    template_cols = [col_name for col_name in df.columns]
                    # indicate that template columns is now set
                    template_cols_set = True

                # reorder columns to template (redundant for first case)
                df = df[template_cols]
                              
                # write new csv
                if not os.path.isfile(timeoutfilename):
                    df.to_csv(timeoutfilename)
                else:
                    with open(timeoutfilename, 'a') as f:
                        df.to_csv(f, header=False)

    return timeoutfilename

def create_output_file(str, EXECDIR, testcase):
    if ("Total allocated space" in str): str = "VmTAS"
    memoutfilename = os.path.join(EXECDIR, "mbmesh_"+testcase+"_"+str+"_profile_results.csv")

    out = None
    if not os.path.isfile(memoutfilename):
        out = open(memoutfilename,"w")
    else:
        out = open(memoutfilename,"a")
    
    return out, memoutfilename

def make_table(info, logname):
    """
    'info' is a tuple containing (measurement, msrtag) 
    return 'table': a list containing 4-element tuples (tag, method, measurement, value)
    """
    table = []

    # pull measurements and ids from log file, as to mem_results* lists
    with open(logname) as f:
        for line in f:
            if (info[0] in line):
                # split out the method name
                method, rest = line.split("- MemInfo")
                junk, method =  re.compile("PET\d+").split(method)
                # remove all but one space in between words
                method = " ".join(method.split())
    
                # split out tag (before or after)
                tag = method.split(" ")[0]

                # remove tag from method
                method = method.split(" ", 1)[1]

                # split out the measurement name
                junk, measurement, mem = rest.split(":",2)
                measurement = " ".join(measurement.split())

                # split out the timing result as a string
                mem = mem.split()[0]
    
                # convert all measurements to Mb
                # most measurements from VMLogMemInfo are given in Kb (default)
                # otherwise, the measurement name includes 'bytes' or 'KiB'
                if "bytes" in measurement:
                    mem = float(mem)/1E6
                elif "KiB" in measurement:
                    mem = float(mem)/976.562
                else:
                    mem = float(mem)/1E3

                # set msrtag to shortened label (second element of tuple from meminfo)
                msrtag = info[1]

                entry = (tag, method, msrtag, mem)

                table.append(entry)

    return table

def process_table(table):
    """
    return 'table': a list containing 4-element tuples (tag, method, measurement, value)
    """
    from operator import itemgetter
    
    # Separate tables
    before = [x for x in table if x[0] == "before"]
    after = [x for x in table if x[0] == "after"]

    before_sorted = np.array(sorted(before, key = itemgetter(1)))
    after_sorted = np.array(sorted(after, key = itemgetter(1)))

    before_mod = [x[1] for x in before]
    before_mod_sorted = sorted(enumerate(before_mod), key = itemgetter(1))

    assert(len(before_sorted) == len(after_sorted))

    # subtract values of "before" measurements from "after"s
    val_list = [ (float(a[3]) - float(b[3])) for a, b in zip(after_sorted, before_sorted) ]

    # get the index of the unsorted before array
    val_index = [x[0] for x in before_mod_sorted]

    #restore the val list to the unsorted version of before measurements
    val_list_unsorted = [val_list[val_index.index(i)] for i in range(len(val_index))]

    # set the subtracted values on the remaining part of the list
    nptable = np.array(before)
    nptable[:,3] = val_list_unsorted

    return nptable


def memory(EXECDIR, config, clickargs):
    print ("Collect memory results (<20 min):", strftime("%a, %d %b %Y %H:%M:%S", localtime()))

    n = clickargs["n"]
    testcase = clickargs["testcase"]
    branch = clickargs["branch"]
    esmfmkfile = clickargs["esmfmkfile"]
    platform = clickargs["platform"]
    runs = clickargs["runs"]
    gnu10 = clickargs["gnu10"]

    procs = config.procs
    if (n > procs[-1]): raise ValueError("--n cannot be greater than "+str(procs[-1])+". Please adjust the 'procs' values in the configuration file for your platform.")

    meminfo = [("VmRSS", "VmRSS"), ("VmHWM", "VmHWM"), ("Total allocated space (bytes)", "VmTAS")]

    rss_file, rssfilename = create_output_file(meminfo[0][0], EXECDIR, testcase)
    hwm_file, hwmfilename = create_output_file(meminfo[1][0], EXECDIR, testcase)
    tas_file, tasfilename = create_output_file(meminfo[2][0], EXECDIR, testcase)

    # iterate sets of runs of different processors numbers from 36 - XXK
    run1 = True
    for num_run in range(1,runs+1):
        # iterate runs of increasing number of processors
        for num_procs in procs:
            if num_procs <= n:

                msrc = 0
                # count the number of measurements
                logname = os.path.join(EXECDIR, str(num_procs)+"-"+str(num_run),
                    "PET"+(str(0).zfill(int(math.ceil(math.log(num_procs,10)))))+
                    ".ESMF_LogFile")
                with open(logname) as f:
                    for line in f:
                        if (meminfo[0][0] in line):
                            msrc = msrc + 1
                msrc = msrc/2

                # initialize an array to hold all memory measurements for all processors
                memres = np.zeros([num_procs,len(meminfo),int(msrc),4], dtype='<U68')

                # iterate per-processor log files
                for proc in range(num_procs):
                    # build the logname
                    logname = os.path.join(EXECDIR, str(num_procs)+"-"+str(num_run),
                        "PET"+(str(proc).zfill(int(math.ceil(math.log(num_procs,10)))))+
                        ".ESMF_LogFile")

                    # initialize a list of tables to hold all memory measurements for one processor
                    tables = []
                    for info in meminfo:
                        tables.append(make_table(info, logname))
                    
                    # process tables of different memory measurement tuples
                    for index, item in enumerate(tables):
                        try:
                            memres[proc, index] = process_table(item)
                        except:
                            raise RuntimeError("Number of measurements in not equal across processors, cannot collect memory reports. Is there a TRACE macro inside a processor-dependant loop?")

                # memres[proc,msr,method[tag,method,msr,val]]

                mem_rss = memres[:,0]
                mem_hwm = memres[:,1]
                mem_tas = memres[:,2]

                labels = [x for x in mem_rss[0,:,1]]

                # write labels to file
                if run1:
                    rss_file.write("processor count,"+(','.join(map(str,labels)))+'\n')
                    hwm_file.write("processor count,"+(','.join(map(str,labels)))+'\n')
                    tas_file.write("processor count,"+(','.join(map(str,labels)))+'\n')
                    run1 = False
                
                mem_rss2 = np.array([x for x in mem_rss[:,:,3].astype(np.float)])
                mem_rss = np.sum(mem_rss2,0)/mem_rss2.shape[0]
                rss_file.write(str(num_procs)+", "+(",".join(format(x, "10.3f") for  x in mem_rss))+"\n")

                mem_hwm2 = np.array([x for x in mem_hwm[:,:,3].astype(np.float)])
                mem_hwm = np.sum(mem_hwm2,0)/mem_hwm2.shape[0]
                hwm_file.write(str(num_procs)+", "+(",".join(format(x, "10.3f") for  x in mem_hwm))+"\n")

                mem_tas2 = np.array([x for x in mem_tas[:,:,3].astype(np.float)])
                mem_tas = np.sum(mem_tas2,0)/mem_tas2.shape[0]
                tas_file.write(str(num_procs)+", "+(",".join(format(x, "10.3f") for  x in mem_tas))+"\n")

    rss_file.close()
    hwm_file.close()
    tas_file.close()
    
    return rssfilename
