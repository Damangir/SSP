# Add any directory structure here:
# Directory structure should be relative to PROCDIR
# Directory should be created by the user.

# Let's define a directory for quality control
declare -r QCDIR=${PROCDIR}/QC
mkdir -p "${QCDIR}"
