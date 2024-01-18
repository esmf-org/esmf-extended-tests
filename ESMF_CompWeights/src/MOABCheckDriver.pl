#!/usr/bin/env/perl
#
# $Id$
#
# Earth System Modeling Framework
# Copyright (c) 2002-2024, University Corporation for Atmospheric Research,
# Massachusetts Institute of Technology, Geophysical Fluid Dynamics
# Laboratory, University of Michigan, National Centers for Environmental
# Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
# NASA Goddard Space Flight Center.
# Licensed under the University of Illinois-NCSA License.
#
#===============================================================================
#                            RegridWeightGenCheckDriver
# 
# This is the driver perl script for the RegridWeightGen application in ESMF
#===============================================================================

use warnings;
use strict;
use Cwd;
use Getopt::Long;
my $dryrun = 0;
my $results = GetOptions("dryrun" => \$dryrun);
my $RUNDIR = getcwd;
my $DATADIR = "$RUNDIR/input/";

my $ap_match = 7;
my $os_match = 7;
my $APPDIR = 7;
my $ESMFOS = 7;
my $esmfos = 7;
my $NUM_PROCS = 4;
my $MPIRUN = "mpirun -np";
my $junk = "junk";
my $netcdf4_flag = 0;
my $ESMF_TOOLRUN = "";

my @data;
my $pnum;

if (!-e $DATADIR) {system("mkdir $DATADIR");}

print "MOABCheckDriver\n";

if ($dryrun == 1) {print "Dryrun mode, only download the input grid files.\n";}

open (my $DATAFILE, "<", "RegridTestData.txt") or die "Cannot open RegridTestData.txt";

while (<$DATAFILE>) {
    next if /^\s*$/;                  # skip blank lines
    next if /^[ \t]*#/;                    # likewise skip comment lines
    push @data, [split (/[:]+/, $_)]; # add lines to data array, split columns on :
}

# find out if ESMF_TOOLRUN is set
if (defined $ENV{'ESMF_TOOLRUN'}){
  $ESMF_TOOLRUN = $ENV{'ESMF_TOOLRUN'}}
else {
  $ESMF_TOOLRUN = ""}

# find out how many procs to use on this machine
if (defined $ENV{'ESMF_NUM_PROCS'}){
  $NUM_PROCS = $ENV{'ESMF_NUM_PROCS'}}
else {
  print "ESMF_NUM_PROCS not defined in user environment, using default ESMF_NUM_PROCS=4\n"}

# read the esmf.mk and get the location of the executable and the OS for this system
open (my $INPUTFILE, "<", "$ENV{'ESMFMKFILE'}") or die "Cannot open file $ENV{'ESMFMKFILE'}";
while (<$INPUTFILE>) 
{
  if (/.*ESMF_APPSDIR.*/) {$ap_match = $_;}
  if (/.*ESMF_OS:.*/) {$os_match = $_;}
}
close ($INPUTFILE);

# process the ap_match and os_match: remove newline and whitespace, and split off useful info
chomp($ap_match);
($junk, $APPDIR) = split(/=/,$ap_match);
$_=$APPDIR;
$APPDIR=~s/ //;

chomp($os_match);
($junk, $ESMFOS) = split(/:/,$os_match);
$_=$ESMFOS;
$ESMFOS=~s/ //;

if (`uname -a | grep -Ec 'ys|geyser|caldera'` == 1) {
  $esmfos = "Yellowstone";
}

if ($ESMFOS eq "Unicos") {
  $MPIRUN = "aprun -n ";
  $NUM_PROCS = 16;
}
elsif ($esmfos eq "Yellowstone") {
  $MPIRUN = "./mpirun.ibmpjl -np ";
  $NUM_PROCS = 12;
}


# get the number of test cases
my $num_cases_index = 0;
my $test_case_start = 1;
my $num_cases = $data[$num_cases_index][0];

# remove whitespace from all but 'options' field
for (my $i=$test_case_start; $i<$test_case_start+$num_cases; $i++) {
  $data[$i][0] =~ s/\s+//g;
  $data[$i][1] =~ s/\s+//g;
  $data[$i][2] =~ s/\s+//g;
  $data[$i][4] =~ s/\s+//g;
  $data[$i][5] =~ s/\s+//g;
  $data[$i][6] =~ s/\s+//g;
}

print "\nTests to be run:\n";

for (my $i=$test_case_start; $i<$test_case_start+$num_cases; $i++) {
  my $grid1 = $data[$i][0];
  my $grid2 = $data[$i][1];
  my $method = $data[$i][2];
  my $options = $data[$i][3];

  (my $g1, $junk) = split(/\.nc/, $grid1);
  (my $g2, $junk) = split(/\.nc/, $grid2);

  my $weights = "$g1\_to_$g2\_$method";

  print "$weights\n";
}

print "\nTest Results:\n";

# loop through the run parameters and run many many test cases
for (my $i=$test_case_start; $i<$test_case_start+$num_cases; $i++) {
    my $fail = 0;
    
    my $grid1 = $data[$i][0];
    my $grid2 = $data[$i][1];
    my $method = $data[$i][2];
    my $options = $data[$i][3];
    my $mean_tol = $data[$i][4];
    my $max_tol = $data[$i][5];
    my $area_tol = $data[$i][6];
    
    (my $g1, $junk) = split(/\.nc/, $grid1);
    (my $g2, $junk) = split(/\.nc/, $grid2);
    
    my $weights = "$g1\_to_$g2\_$method";
    my $weights_moab = "$g1\_to_$g2\_$method\_moab";

    # Get the grid file if not exist
    if (!-e "$DATADIR$grid1") {
        system("cd $DATADIR; wget -q -nd http://www.earthsystemmodeling.org/download/data/$grid1") == 0
           or $fail = 1;
        if ($fail) {system("echo 'wget FAILED :$grid1\n' > $weights.out");} 
    }
    if (!-e "$DATADIR$grid2") {
        system("cd $DATADIR; wget -q -nd http://www.earthsystemmodeling.org/download/data/$grid2") == 0
           or $fail = 1;
        if ($fail) {system("echo 'wget FAILED :$grid2\n' >> $weights.out");}
    }
    if ($dryrun && !$fail) {system("echo 'dryrun mode: wget SUCCESS\n' >> $weights.out");}
    # if "--dryrun" flag is not given, run the checker
    if ($dryrun != 1) {
        if (!$fail) { 

            $grid1 = "$DATADIR$grid1";
            $grid2 = "$DATADIR$grid2";
               
            # run the offline tool first without moab
            my $run_command = "$MPIRUN $NUM_PROCS $ESMF_TOOLRUN $APPDIR/ESMF_RegridWeightGen -s $grid1 -d $grid2 -w $weights.nc -m $method $options";
              system("echo '\n$run_command\n' > $weights.out");
              system("$run_command >> $weights.out");

             # then with moab
            $run_command = "$MPIRUN $NUM_PROCS $ESMF_TOOLRUN $APPDIR/ESMF_RegridWeightGen -s $grid1 -d $grid2 -w $weights_moab.nc -m $method $options --moab";
              system("echo '\n$run_command\n' > $weights_moab.out");
              system("$run_command >> $weights_moab.out");

            for (my $j=0; $j<$NUM_PROCS; $j++) {
                if ($NUM_PROCS < 10) {
                    $pnum=$j
                } elsif ($NUM_PROCS < 100) {
                    $pnum=sprintf("%02d",$j);
                } else {
                    $pnum=sprintf("%03d",$j);
                }
                if (-e "PET${pnum}.RegridWeightGen.Log") {
                    system("cat PET${pnum}.RegridWeightGen.Log >> $weights.out");
                    system("rm PET${pnum}.RegridWeightGen.Log");
                }
            }
        }
    }

    # check that all log files have been written to output file
    my @outputfiles;
    my $outputfile;
    for (my $j=0; $j<$NUM_PROCS; $j++) {
      push(@outputfiles, "PET$j.RegridWeightGen.Log");
    }
    foreach $outputfile (@outputfiles){
      while (-f $outputfile) {
        sleep(1);
      }
    }

    # diff the weight files
    my $run_command = "$MPIRUN 1 $ESMF_TOOLRUN DiffWeights -w1 $weights.nc -w2 $weights_moab.nc";
              system("echo '\n$run_command\n' > $weights-diffweights.out");
              system("$run_command >> $weights-diffweights.out");

    # first find out if netcdf4 is being used.
    if ($options =~ "--netcdf4" || $options =~ "--64bit_offset") {$netcdf4_flag = 1;}
    # then check the results
    check_results("$weights-diffweights.out");
}

# subroutine to check the results of the interpolation and conservation
sub check_results {

    my $FAIL = 0;
    my $weights = $_[0];

    # search the output file for error info
    open(FH,"$weights") or die "$!";
    while (<FH>){
        if (/FAIL.*/) {
          $FAIL = 1;
        }
    }
    close (FH);

    # test the results for interpolation and conservation error
    print "$weights";
    if ($FAIL) {
      print " - FAIL\n";
    } else {
      print " - PASS\n";
    }
}
