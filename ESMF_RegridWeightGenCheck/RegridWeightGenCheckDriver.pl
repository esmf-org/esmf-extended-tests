#!/usr/bin/env/perl
#
# $Id$
#
# Earth System Modeling Framework
# Copyright (c) 2002-2023, University Corporation for Atmospheric Research,
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
my $weights = 7;
my $NUM_PROCS = 4;
my $ESMF_TOOLRUN = "";
my $ESMF_MPIRUN = "mpirun";
my $junk = "junk";
my $netcdf4_flag = 0;
my $run_success = 0;

my @data;
my $pnum;

if (!-e $DATADIR) {system("mkdir $DATADIR");}

if ($dryrun == 1) {print "Dryrun mode, only download the input grid files.\n";}

open (my $DATAFILE, "<", "RegridTestData.txt") or die "Cannot open RegridTestData.txt";

while (<$DATAFILE>) {
    my $fail = 0;
    my @tokens;
    next if /^\s*$/;                  # skip blank lines
    next if /^[ \t]*#/;               # likewise skip comment lines
    if (/^[ \t]*wgettar/) {
        @tokens=split;
        if (!-e "$DATADIR$tokens[1]") {
            system("cd $DATADIR; wget -q -nd http://data.earthsystemmodeling.org/download/data/$tokens[1]") == 0
                or $fail = 1;
            if ($fail) {system("echo 'wget FAILED :$tokens[1]\n'");}
            else {system("echo 'wget SUCCESS :$tokens[1] ... untar ...\n'");}
            system("cd $DATADIR; tar xvf $tokens[1]") == 0 
                or $fail = 1;
            if ($fail) {system("echo 'untar FAILED :$tokens[1]\n'");}
        }
    } else {
        push @data, [split (/[:]+/, $_)]; # add lines to data array, split columns on :
    }
}

# find out if ESMF_MPIRUN is set
if (defined $ENV{'ESMF_MPIRUN'}){
  $ESMF_MPIRUN = $ENV{'ESMF_MPIRUN'}
}
print "\nESMF_MPIRUN: $ESMF_MPIRUN\n";

# find out if ESMF_TOOLRUN is set
if (defined $ENV{'ESMF_TOOLRUN'}){
    $ESMF_TOOLRUN = $ENV{'ESMF_TOOLRUN'}}
else {
  $ESMF_TOOLRUN = ""}
print "\nESMF_TOOLRUN: $ESMF_TOOLRUN\n";

# find out how many procs to use on this machine
if (defined $ENV{'ESMF_NUM_PROCS'}){
  $NUM_PROCS = $ENV{'ESMF_NUM_PROCS'}
}
print "\nNUM_PROCS: $NUM_PROCS\n";

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

  my $weights = "$g1\_to_$g2\_$method\_test$i";

  print "$weights\n";
}

print "\nTest or Dryrun Results:\n";

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
    
    my $weights = "$g1\_to_$g2\_$method\_test$i";
    
    # Get the grid file if not exist
    if (!-e "$DATADIR$grid1") {
        system("cd $DATADIR; wget -q -nd http://data.earthsystemmodeling.org/download/data/$grid1") == 0
               or $fail = 1;
        if ($fail) {system("echo 'wget FAILED :$grid1\n' > $weights.out");} 
    }
    if (!-e "$DATADIR$grid2") {
        system("cd $DATADIR; wget -q -nd http://data.earthsystemmodeling.org/download/data/$grid2") == 0
               or $fail = 1;
        if ($fail) {system("echo 'wget FAILED :$grid2\n' >> $weights.out");}
    }
    if ($dryrun && !$fail) {system("echo 'dryrun mode: wget SUCCESS\n' >> $weights.out");}
    # if "--dryrun" flag is not given, run the checker
    if ($dryrun != 1) {
        if (!$fail) { 

                  $grid1 = "$DATADIR$grid1";
                  $grid2 = "$DATADIR$grid2";
               
                  # run the offline tool
            my $run_command = "$ESMF_MPIRUN -np $NUM_PROCS $ESMF_TOOLRUN $APPDIR/ESMF_RegridWeightGen -s $grid1 -d $grid2 -w $weights.nc -m $method $options --check";
                  system("echo '\n$run_command\n' > $weights.out");
                  system("$run_command 2>&1 >> $weights.out");

            # next print the tolerance values to the results file
            system("echo '\nTolerance values:' >> $weights.out");
            system("echo '  - Mean Relative Error: $mean_tol' >> $weights.out");
            system("echo '  - Max  Relative Error: $max_tol' >> $weights.out");
            system("echo '  - Area Conservation  : $area_tol\n' >> $weights.out");

            #if the run was not successful, append Log files to the output file
            $run_success = 0;
            open (FH,"$weights.out") or die "Failed to open $weights.out: $!";
            while (<FH>) {
                if (/Completed weight generation successfully./) {
                    $run_success = 1;
                }
            }
            close(FH);

            for (my $j=0; $j<$NUM_PROCS; $j++) {
                if ($NUM_PROCS < 10) {
                            $pnum=$j
                } elsif ($NUM_PROCS < 100) {
                    $pnum=sprintf("%02d",$j);
                } else {
                    $pnum=sprintf("%03d",$j);
                }
                if (-e "PET${pnum}.RegridWeightGen.Log") {
                    system("cat PET${pnum}.RegridWeightGen.Log >> $weights.Log");
                    if ($run_success != 1) {
                        system("cat PET${pnum}.RegridWeightGen.Log >> $weights.out");
                    }
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

    # first find out if netcdf4 is being used.
    if ($options =~ "--netcdf4" || $options =~ "--64bit_offset") {$netcdf4_flag = 1;}
    # then check the results
    check_results($mean_tol, $max_tol, $area_tol, "$weights.out", $netcdf4_flag);
} # i

# subroutine to check the results of the interpolation and conservation  
sub check_results {

    my $FAIL_RWG = 1;
    my $FAIL_NOOUTPUT = 0;
    my $FAIL_WGET = 0;
    my $FAIL_NETCDF4 = 0;
    my $DRYRUN_OK = 0;
    my $DING = 1;
    
    # inputs trigger failure if not updated
    my $mean_err = 1;
    my $max_err = 1;
    my $grid1_area = 1;
    my $grid2_area = 0;
    my $conserve_result = 1;
    
    my $mean_tol = $_[0];
    my $max_tol = $_[1];
    my $area_tol = $_[2];
    my $weights = $_[3];
    my $netcdf4_flag = $_[4];
    
    # search the output file for error info
    open(FH,"$weights") or die "$!";
    while (<FH>){ 
        if (/Mean relative error.*/) {
          chomp($_);
          s/ //g;
          (my $str, $mean_err) = split(/=/,$_);
          $DING = 0;
        }
        if (/Maximum relative error.*/) {
          chomp($_);
          s/ //g;
          (my $str, $max_err) = split(/=/,$_);
          $DING = 0;
        }
        if (/Grid 1 area.*/) {
          chomp($_);
          s/ //g;
          (my $str, $grid1_area) = split(/=/,$_);
          $DING = 0;
        }
        if (/Grid 2 area.*/) {
          chomp($_);
          s/ //g;
          (my $str, $grid2_area) = split(/=/,$_);
          $DING = 0;
        }
        if (/Conservation error.*/) {
          chomp($_);
          s/ //g;
          (my $str, $conserve_result) = split(/=/,$_);
          $DING = 0;
        }
        if (/Completed weight generation successfully./) {
          $FAIL_RWG = 0;
          $DING = 0;
        }
        if (/.*file format is not supported.*/) {
          $FAIL_NETCDF4 = 1;
          $DING = 0;
        }
        if (/wget FAILED.*/) {
          $FAIL_WGET = 1;
          $DING = 0;
        }
        if (/wget SUCCESS.*/) {
          $DING = 0;
          $DRYRUN_OK = 1;
        }
    }
    if ($DING) {
        $FAIL_NOOUTPUT = 1;
    }
    close (FH);

    # test the results for interpolation and conservation error
    print "$weights";
    if ($dryrun){
      if ($DRYRUN_OK) {
        print " - PASSED\n";
      } else {
        print " - FAILED\n";
      }
    } else {    
      if ($FAIL_WGET) {
        print " - FAILED - wget one of the input files failure\n";
      } elsif ($FAIL_RWG) {
        if ($FAIL_NETCDF4) {
          if ($netcdf4_flag) {
            print " - SKIPPED  -  NetCDF4 is not available on this machine\n";
          } else {
            print " - FAILED  -  NetCDF4 is not available on this machine, even though it was not specified in the options..\n";
          }
        } else {
          print " - FAILED  -  ESMF_RegridWeightGen failure\n";
        }
      } elsif ($FAIL_NOOUTPUT) {
        print " - FAILED  -  NO OUTPUT failure\n";
      } elsif ($mean_err < $mean_tol && $max_err < $max_tol && $conserve_result < $area_tol) {
        print " - PASSED\n";
      } else {
        print " - FAILED - above tolerance\n";
      }
    }
}
