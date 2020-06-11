import sys, os
import numpy as np
import pandas as pd

nprocs = sys.argv[1]
nprocs = int(nprocs)

runs = sys.argv[2]
runs = int(runs)

procs = [8, 16, 32, 64, 128, 256, 1024, 4096, 16384, 65536]
timeoutfilename = "reconcile_timing_results.csv"

for num_run in range(1,runs+1):
    for num_procs in procs:
        if num_procs <= nprocs:

            resfilename = os.path.join(os.getcwd(), str(num_procs)+"-"+str(num_run), "ESMF_Profile.summary")
            rftmp = resfilename+".tmp"
    
            out = open(rftmp,"a")
            with open(resfilename) as f:
                for line in f:
                    # remove leading whitespace
                    nl = line.lstrip()
                    if str(num_procs) in nl:
                        # split out the method name
                        method, rest = nl.split(str(num_procs),1)
                        # remove all but one space in between words
                        newmethod = " ".join(method.split())
                        nl = newmethod+"    "+str(num_procs)+rest
                    out.write(nl)
            out.close()
    
            f_in = pd.read_csv(rftmp, sep=r"\s{2,}", index_col=False, engine='python')
    
            # delete unwanted columns
            keep_col = []
            keep_col.append("Region")
            keep_col.append("Mean (s)")
            f_out = f_in[keep_col]
    
            # switch columns for rows and reorder
            f_out.set_index("Region", inplace=True)
            f_out = f_out.T
    
            f_out.rename(index={"Mean (s)":str(num_procs)}, inplace=True)
    
            keep_col = ["Reconcile"]
            f_out = f_out[keep_col]
    
            # write new csv
            if not os.path.isfile(timeoutfilename):
                f_out.to_csv(timeoutfilename)
            else:
                with open(timeoutfilename, 'a') as f:
                    f_out.to_csv(f, header=False)
    
            # remove the temp file
            os.remove(rftmp)
    
            print (("Processed {}").format(resfilename))
