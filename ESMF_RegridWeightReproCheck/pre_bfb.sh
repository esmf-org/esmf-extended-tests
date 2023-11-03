
# Get tags
export BASE_TAG=$1
export COMP_TAG=$2

# Set working directory
export BFBDIR=${PWD}

# Setup directories for base
export BASE_DIR=${BFBDIR}/${BASE_TAG}
mkdir -p ${BASE_DIR}
cd ${BASE_DIR}

# Get base version of ESMF
git clone -b release/${BASE_TAG} https://github.com/esmf-org/esmf.git

# Setup directories for comp
export COMP_DIR=${BFBDIR}/${COMP_TAG}
mkdir -p ${COMP_DIR}
cd ${COMP_DIR}

# Get comp version of ESMF
# BOB: add release just this time, because having "release" in the dir seems to cause a problem
#git clone -b ${COMP_TAG} https://github.com/esmf-org/esmf.git
git clone -b release/${COMP_TAG} https://github.com/esmf-org/esmf.git

# Download RWG
# (Using base tag because base stuff more likely to work with comp tag, 
# than vise versa)
cd ${BFBDIR}
git clone -b release/${BASE_TAG} https://github.com/esmf-org/esmf-extended-tests
