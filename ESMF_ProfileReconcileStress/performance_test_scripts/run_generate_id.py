import os, sys, re

ROOTDIR  = sys.argv[1]

rundir = os.path.join(ROOTDIR, "runs")

if not os.path.isdir(rundir):
    try:
        os.makedirs(rundir)
    except OSError as exc: # Guard against race condition
        if exc.errno != errno.EEXIST:
            raise

dirnums = []
for path in os.listdir(rundir):
    directory = os.path.join(rundir, path)
    if os.path.isdir(directory):
        head, tail = os.path.split(directory)
        dirnums.append(int(tail))

print (os.path.join(rundir, str(max(dirnums or [0]) + 1)))
