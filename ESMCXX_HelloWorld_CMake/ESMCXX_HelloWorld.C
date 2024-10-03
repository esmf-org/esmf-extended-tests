// Earth System Modeling Framework
// Copyright (c) 2002-2024, University Corporation for Atmospheric Research,
// Massachusetts Institute of Technology, Geophysical Fluid Dynamics
// Laboratory, University of Michigan, National Centers for Environmental
// Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
// NASA Goddard Space Flight Center.
// Licensed under the University of Illinois-NCSA License.

#include "ESMC.h"

int main(int argc, char *argv[]){

  // local variables
  int rc;

  rc = ESMC_Initialize(nullptr, ESMC_ArgLast);
  if (rc != ESMF_SUCCESS) ESMC_FinalizeWithFlag(ESMC_END_ABORT);

  rc = ESMC_LogWrite(">>> Hello ESMC World from C++ <<<", ESMC_LOGMSG_INFO);
  if (rc != ESMF_SUCCESS) ESMC_FinalizeWithFlag(ESMC_END_ABORT);

  rc = ESMC_Finalize();

  return 0;
}
