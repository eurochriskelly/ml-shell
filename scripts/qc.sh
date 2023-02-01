#!/bin/bash
#
# Extract and upload workspaces to and from query console.
#
QC_WORKDIR=$(pwd)
cd $QC_TOP_DIR
TS=$(date +%s)

main() {
  #
  if [ -z "$ML_HOST" ];then
    echo "Please source env.sh in top level directory to setup environment"
    return
  fi
  local option=$1
  II "test"
  doEval cleanupArtefacts "App-Services"
  case $option in
    pull | down | download)
      clear
      pullQueries
      ;;
    push | up | upload)
      clear
      pushQueries
      ;;
    *)
      echo "Please select an option [push/pull]"
      echo "e.g."
      echo "qc push"
      cd $QC_TOP_DIR
      return
      ;;
  esac
}

processOptions() {
  option=$1
  shift
}

## option implementations
{
  pullQueries() {
    II "Pulling queries from local query console."
    echo ""
    # TODO: Check if any files are newer than the _workspace.xml and, if yes, warn
    local workspace=
    local results=$(doEval prepWorkspaces "App-Services")
    local numRows=$(echo $results |wc -l)
    if [ "$QC_WORKDIR" != "$QC_TOP_DIR" ]; then
      workspace=$(basename $QC_WORKDIR)
    else
      # Ask which workspace to download
      local i=1
      local options=()
      for r in $results; do
        local w=$(echo $r | grep "^WW")
        if [ -n "$w" ]; then
          local parts=($(echo $r | sed 's/,/\n/g'))
          local path="${parts[6]}"
          options=("${options[@]}" $path)
          echo $i ${path/stories\n/}
          i=$(($i + 1))
        fi
      done
      echo -n "Enter choice: "
      read choice
      workspace="${options[$(($choice - 1))]}"
    fi
    if [ -n "$workspace" ]; then
      echo ""
      II "Downloading artefacts of workspace.. [$workspace]"
      local notFound=true
      for q in $results; do
        local parts=($(echo $q | sed 's/,/\n/g' | sed 's/ *$//g'))
        local selected="${parts[6]}"
        if [ "$workspace" == "$selected" ]; then
          notFound=false
          local type="${parts[0]}"
          local fname="${QC_TOP_DIR}/${parts[1]}"
          if [ -n "${fname}" ]; then
            if [ "$type" == "WW" ]; then
              local uri="${parts[2]}"
              downloadWorkspace "$uri" "$fname" "App-Services"
            else
              local qid="${parts[2]}"
              local db="${parts[3]}"
              local order="${parts[4]}"
              local ext="${parts[5]}"
              downloadQuery "$qid" "$fname" "App-Services" "$db" "$ext"
            fi
          else
            EE "No filename [$fname]"
          fi
        fi
      done
      if "$notFound";then
        echo ""
        echo "Cannot pull workspace [$workspace] because it does not exist in server"
        echo ""
        echo "Available workspaces are:"
        echo "$results"|awk -F, '{print $7}'|sort|uniq | while read line;do
          echo " "$line
        done
        echo ""
        echo "Try renaming the /local folder/ or /workspace/ so they match."
        echo "Alternatively, import the /_workspace.xml/ to query console."
        echo""
      fi
    else
      echo "No workspace selected!"
    fi
  }

  # Push selected workspace
  pushQueries() {
    II "Pushing queries to query console."
    local workspace=
    if [ "$QC_WORKDIR" != "$QC_TOP_DIR" ]; then
      workspace=$(basename $QC_WORKDIR)
    else
      local i=1
      local options=()
      echo "Found the following workspaces in stories directory:"
      for d in $(find . -name "_workspace.xml"); do
        local path=$(basename $(dirname $d))
        options=("${options[@]}" $path)
        echo $i $path
        i=$(($i + 1))
      done
      echo -n "Enter choice: "
      read choice
      workspace="${options[$(($choice - 1))]}"
    fi

    # Upload the workspace definition
    local wsLocal=$(find "stories/$workspace" -name "_workspace.xml")
    if [ -z "$wsLocal" ]; then
      echo ""
      echo "WARNING: No local workspace file found. Please create in localhost and pull!"
      echo ""
    else
      for f in $(find $QC_TOP_DIR/stories/$workspace -type f -name "*.xqy" -o -name "*.js" -o -name "*.sql" -o -name "*.spl"); do
        uploadUri $f /qcsync/${TS}/$(basename $f)
      done
      for f in $(find $QC_TOP_DIR/stories/$workspace -type f -name "*.xml"); do
        uploadUri $f /qcsync/${TS}/$(basename $f)
      done
      doEval updateWorkspaces "App-Services" "{\"ts\":\"$TS\"}"
      echo ""
      echo "Reload the workspaces to see changes!"
      echo ""
    fi
    # uploadWorkspace $workspace
    # Import the workspace (server-side)
    # Get a list of query uris to be replaced
    # Upload those documents
    # Display warning for local files that have no server match
  }
}

# common functions
{

  # Download contents of a query to a local file
  downloadQuery() {
    local qid=$1
    local uri="/queries/${qid}.txt"
    local fname=$2
    local db=$3
    local qdb=$4
    local ext=$5
    local opts=(-X GET)
    local dir=$(dirname $fname)
    local base=$(basename $fname)
    mkdir -p "$dir"
    echo "  Downloading [$uri] to [${fname/${QC_TOP_DIR}\//}]"
    fetch "/v1/documents?uri=${uri}&database=${db}" "${opts[@]}" > "$fname"
  }

  downloadWorkspace() {
    local uri=$1
    local dir=$2
    local opts=(-X GET)
    local db="App-Services"
    mkdir -p "$dir"
    local fname="$dir/_workspace.xml"
    echo -n "" > $fname
    echo "  Downloading [$uri] to [${fname/$QC_TOP_DIR\//}]"
    fetch "/v1/documents?uri=${uri}&database=${db}" "${opts[@]}" | sed '1d' >>"$fname"
  }

  # Upload contents of a text file to it's stored query
  uploadUri() {
    local fname=$1
    local uri=$2
    local opts=(
      -X PUT -T "$fname"
    )
    local db="App-Services"
    echo "  Uploading [${fname/$QC_TOP_DIR\//}] to [$uri]"
    fetch "/v1/documents?uri=${uri}&database=${db}" "${opts[@]}"
  }
}

main $@
