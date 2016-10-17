# Soheil's Simple Pipeline
#### Simple, easy, one-file bash pipeline management system

An easy pipeline management system for running a long procedure aimed at
running neuroimaging pipeline. It will help large pipelines to:

- Keep track of the process and just run the one need to be updated
- Generate the actual reproduce script containing all the commands that actualy get run by the process
- Monitor progress of each process
- Make logging easy
- Everything is Bash!

## Getting started
The pipeline should be consist of different stage. For each stage you just need to source the `ssp.sh` in your script

```bash
source "ssp.sh"
```

The convension is to specify the required files for the script to be run.

```bash
depends_on "${INPUT_1}" "${INPUT_2}" "${INPUT_3}"
```
Then the files that this process is expected to generate should be specified. If all these files are present after finishing the script the process is considered successful. The expected outputs are to be set in a variable called `EXPECTED_FILES` one per line.

```bash
expects	my.output.txt
```

Most of the time you need to check if this process has already been successfuly run and if it is not already done, the expected output files can be removed with:
```bash
check_already_run
remove_expected_output
```

After all these small boilerplate to define the procedure, each command can be run by `run_and_log` command.

```bash
run_and_log step_name command arg1 arg2
```
You can run any regular command or functions.

Each pipeline will be run in a directory structure:
```bash
PROCDIR
  |-- Log
  |-- Touch
  |-- Lock
  `-- Scripts
```

You can specify more directory relative to the root directory in `directory_structure.sh` located in the same directory as the running script. The user is responsible for creating those directory. For example:

```bash
# Let's define a directory for quality control
declare -r QCDIR=${PROCDIR}/QC
mkdir -p "${QCDIR}"
```

Here a sample full script as starting point `example.0.boilerplate.sh`:

```bash
#!/bin/bash

source "ssp.sh"

# Expected input files
# depends_on "${INPUT_1}" "${INPUT_2}" "${INPUT_3}"

# Expected output files
expects	${QCDIR}/It.is.working.txt

# Check if we need to run this stage
check_already_run
remove_expected_output

run_and_log 1.command.run printf "Hello\n"

# More complex tasks can be defined in a function
foobar(){
	printf "%s\n" $@ >"${QCDIR}/It.is.working.txt"
}

# Logs can be done with log_*
log_debug "User running: $(whoami)"

# Comments describing the work can be added
comment "Running function to test"

run_and_log 2.function.run foobar this is an example
```

Once all the process is defined, a pipeline would consist of many of them in series (e.g. `pipeline.sh`):
```bash
#!/bin/bash

set -e

# export input variables:
export PROCDIR=$1

# Just create directories
DO_NOTHING=YES source ssp.sh

# stdout would be all commands to be run to recreate the run
example.0.boilerplate.sh 1>${PROCDIR}/Scripts/pipeline.${START_TIME}.sh
```

## Reference guide

### Pipeline usage
`run_and_log` runs a command or a bash function
```bash
run_and_log step_name command [args] ...

$ run_and_log 1.copy.initial.files cp T1.nii.gz ${MRIDIR}/original.nii.gz
```

`depends_on` adds a list of dependencies to the script. It can be used multiple times in a script.
```bash
depends_on file1 [file2] ...

$ depends_on T1.nii.gz
```

`expects` adds a list of expected output to the script. It can be used multiple times in a script.
```bash
expects file1 [file2] ...

$ expects ${MRIDIR}/original.nii.gz
```

`remove_expected_output` removes the files that specified as expected output.

`check_updated` checks if the input files have been updated since the last run (i.e. newer than any expected output). 

`check_already_run` checks whether the script has already been run.

#### Environment variables
You can set these env variables:
- `PROCDIR` The root directory to create. Defaults to the first argument of the script
- `EXPECTED_FILES` list of expected output files one per line
- `DO_NOTHING` for the pipeline to create directory structure

Read only environment variables:
- `LOGDIR=${PROCDIR}/Log`: Where the logs go
- `TOUCHDIR=${PROCDIR}/Touch`: For notifying running of each part, touch a file here
- `LOCKDIR=${PROCDIR}/Lock`: For managing concurrent pipelines, lock files can be placed here. Note each `PROCDIR` is restricted to one pipeline at a time
- `RERUNDIR=${PROCDIR}/Scripts`: For scripts to rerun the pipeline (Typicaly the the stdout from previous run)
- `CON_TEMPDIR=${PROCDIR}/Temp.$$`: Temporary directory, will be created and removed by the pipeline
- `START_TIME`: Starting timestamp for the current run

### Utils
`pjoin` joins arguments with a delimiter:

```bash
pjoin delimiter item1 [item2] ...

$ pjoin , 1 2 3 4 5
1,2,3,4,5
```

`trace_stack` prints the stack trace[starting-frame=0].
```bash
trace_stack [frame=0]

$ trace_stack
18 func_3 ./test.sh
14 func_2 ./test.sh
10 func_1 ./test.sh
23 main ./test.sh 
$ trace_stack 2
10 func_1 ./test.sh
23 main ./test.sh 
```

`date_string` print an OS-independent timestamp.

### Logging
`log_{info,run,success,error,warning,debug}` for logging:

```bash
log_* "Text to be logged as 1 argument"
```

### Outputing
`error` and `warning` are used to produce output to the user. The output is redirected to `stderr`. `comment` used to put comment in the reproduce scripts. All commands works exactly the same way:

```bash
command Hello
error "You can quote the text"
warning or use multiple arguments
```

`hline` print a 80 charachter wide horizontal line with `#`.

## Requirement
The pipeline only depends on `bash` 3.0+.
