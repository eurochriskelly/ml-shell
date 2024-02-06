#!/bin/bash

# Log analysis tasks
source $MLSH_TOP_DIR/scripts/common.sh > /dev/null 2>&1

main() {
  #
  local env=$1
  echo ""
  if [ -z "$env" ];then
    echo "Current env is [$ML_ENV]"
    showHelp
  fi
  export ML_ENV=$env
  source ~/.mlshrc

  output_file=~/.mlshrc-gen
  echo "#!/bin/bash" > "$output_file"
  # Loop through environment variables starting with "ML_"
  for var in $(env | grep -o 'ML_[A-Za-z0-9_]*='); do
    # Extract the variable name and value
    var_name=$(echo "$var" | sed 's/=$//')
    var_value="${!var_name}"

    # Export the variable to the output file
    echo "export $var_name=\"$var_value\"" >> "$output_file"
  done
  chmod +x "$output_file"

  if [ -n "$env" ];then
    echo "Setting local env to [$env]"
  else
    echo "Env contains:"
  fi

  echo "  ML_ENV: $ML_ENV"
  echo "  ML_HOST: $ML_HOST"
  echo "  ML_USER: $ML_USER"
}

showHelp() {
  local envs=$(cat ~/.mlshrc | grep ")$" | grep -v "*" | awk '{print $1}' | awk -F\) '{print $1}')
  echo "Available environments:"
  echo "$envs" | sed 's/^/  /'
}

main "$@"
