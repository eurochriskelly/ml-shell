#!/bin/bash

main() {
  initialize
  local start=$(date +%s)
  local type="validate"
  local job=$1
  local now=$2
  local dataReport=corb-report-${job}-${now}.txt
  local javaReport=corb-output-${job}-${now}.log
  echo "" >$dataReport
  echo "" >$javaReport

  II "Storing corb log in [$javaReport]"
  II "Storing corb report in [$dataReport]"

  #set -o xtrace
  corbOpts=(
    -server -cp .:$CORB_JAR:$XCC_JAR
    -DXCC-CONNECTION-URI="xcc://${ML_USER}:${ML_PASS}@${ML_HOST}:${ML_CORB_PORT}"
    -DOPTIONS-FILE="${job}.properties"
    -DEXPORT-FILE-NAME="$dataReport"
  )

  set -o xtrace
  java "${corbOpts[@]}" com.marklogic.developer.corb.Manager >$javaReport 2>&1
  set +o xtrace

  echo " ----------------- " >>$javaReport
  II "-> Corb job [$job] took [$(($(date +%s) - $start))] seconds"
  II "-> Report [$dataReport]"
}

II() { echo "$(date +%Y-%m-%dT%H:%M:%S%z): $@"; }

initialize() {
  if [ ! -f "$CORB_JAR" ]; then
    echo "Please set CORB_JAR in your ~/.mlshrc file."
    return
  fi
  if [ ! -f "$XCC_JAR" ]; then
    echo "Please set XCC_JAR in your ~/.mlshrc file."
    return
  fi
  if [ -z "$ML_HOST" ]; then
    echo "ERROR: Expected environment variable [ML_HOST] not defined! Please source your environment."
    exit 1
  fi
  if [ -z "$ML_CORB_PORT" ]; then
    echo "ERROR: Expected environment variable [ML_CORB_PORT] not defined! Please source your environment."
    exit 1
  fi

  # Dump configuration settings used
  local c=$runDir/config.txt
  touch $c
  echo "HOST: $ML_HOST" >>$c
  echo "USER: $ML_USER" >>$c
}
pickAFile() {

  # Show the user a list of all xqy, js and sjs files that can be found in the current folder
  # or in one of it's subfolders. Number the files and ask the user to select one.
  local xqyFiles=$(find . -name "*.xqy" -type f)
  local jsFiles=$(find . -name "*.js" -type f)
  local sjsFiles=$(find . -name "*.sjs" -type f)
  local i=1
  local files=""
  for f in $xqyFiles; do
    files="$files\n$i) $f"
    i=$((i + 1))
  done
  for f in $jsFiles; do
    files="$files\n$i) $f"
    i=$((i + 1))
  done
  for f in $sjsFiles; do
    files="$files\n$i) $f"
    i=$((i + 1))
  done
  echo -e "Select a module for the job:"
  echo -e $files
  echo -n "Module: "
  echo -n "$@"
  read choice
  # loop through the files and assign the filename matching $choice to PICK_A_FILE_CHOICE
  local j=1
  for f in $xqyFiles; do
    if [ "$j" == "$choice" ]; then
      PICK_A_FILE_CHOICE=$f
    fi
    j=$((j + 1))
  done
  for f in $jsFiles; do
    if [ "$j" == "$choice" ]; then
      PICK_A_FILE_CHOICE=$f
    fi
    j=$((j + 1))
  done
  for f in $sjsFiles; do
    if [ "$j" == "$choice" ]; then
      PICK_A_FILE_CHOICE=$f
    fi
    j=$((j + 1))
  done
}

jobWizardJob() {
  local job=$1
  echo "Creating job [$job]..."
  local jf="${job}.properties"
  touch $jf
  pickAFile "Pick collect module: "
  local collectMod=$PICK_A_FILE_CHOICE

  pickAFile "Pick process module: "
  local processMod=$PICK_A_FILE_CHOICE
  echo "URIS-MODULE=${collectMod}|ADHOC" >> $jf
  echo "PROCESS-MODULE=${processMod}|ADHOC" >> $jf
  echo "BATCH-SIZE=1" >> $jf
  echo "THREAD-COUNT=4" >> $jf
  echo "Job [$job] created."
  # Offer to edit the file and, if yes, open with $EDITOR
  echo -n "Edit the job file? [y/n] "
  read edit
  if [ "$edit" == "y" ]; then
    $EDITOR $jf
  fi
  # Run the job
  echo "Corb job created. Please switch to the folder [corb/job_${job}] and run 'mlsh corb' again"
}

while [ "$#" -gt "0" ]; do
  case $1 in
  --task)
    shift
    task=$1
    shift
    ;;

  --job)
    shift
    job=$1
    shift
    ;;

  --threads)
    shift
    threads=$1
    shift
    ;;

  --batchSize)
    shift
    batchSize=$1
    shift
    ;;

  *)
    echo "Unknown option [$1]"
    shift
    exit
    ;;
  esac
done

startedAt="$(date +%s)"
timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
runDir=./results/run-${startedAt}
mkdir -p $runDir
log=./results/run-${startedAt}/log

if [ -n "$job" ]; then
  main $job
else
  # Check for a the existence of at least 1.properties file in the current folder
  if [ -z "$(find . -name "*.properties" -type f -maxdepth 1)" ]; then
    echo "No properties files found in the current folder. "
    echo -n "Please provide a job or type a name to create one: "
    read job
    if [ -n "$job" ]; then
      jobWizardJob $job
      exit 0
    else
      echo "No job provided. Exiting."
    fi
    echo ""
    exit 1
  fi

  echo "Available jobs:"
  # List all properties files in the current folder and get the user to select one
  # by number. Assign theselected to the variable $job
  i=1
  jobs=""
  for f in $(find . -name "*.properties" -type f -maxdepth 1); do
    jobs="$jobs\n$i) $(basename ${f%.properties})"
    i=$((i + 1))
  done
  echo -e $jobs
  echo -n "Select job to run: "
  read choice
  # loop over choices and selec the one match # $choice
  i=1
  for f in $(find . -name "*.properties" -type f -maxdepth 1); do
    if [ "$i" == "$choice" ]; then
      job=$(basename ${f%.properties})
    fi
    i=$((i + 1))
  done
  # preview the properties file
  echo "Job properties [${job}.properties]:"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  grep -v '^#\|^$' ${job}.properties | sort
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo ""
  echo -n "Would you like to edit? "
  read -n 1 answer
  echo ""
  if [[ $answer == [Yy] ]]; then
      $EDITOR ${job}.properties
  fi
  now="$(date +%s)"
  main $job $now
  # Ask user if they want to preview the output file
  rep=./corb-output-${job}-${now}.log
  echo -ne "\nPreview the output file [$rep]? [y/n] "
  read -n 1 answer
  if [[ $answer == [Yy] ]]; then
      $EDITOR $rep
  fi

  rep=./corb-report-${job}-${now}.txt
  if [ -f "$rep" ];then
    echo -ne "\nPreview the report file [$rep]? [y/n] "
    read -n 1 answer
    if [[ $answer == [Yy] ]]; then
        $EDITOR $rep
    fi
  fi
  mkdir -p corbLogs
  mv corb-report*.txt corbLogs
  mv corb-output*.log corbLogs
fi
