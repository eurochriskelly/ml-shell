#!/bin/bash

echo "Initializing mulsh..."

if [ ! -f "$HOME/.mulshrc" ]; then
  echo "No ~/.mulshrc file found."
  if [ ! -d "$HOME/.mulsh.d" ]; then
    echo "mulsh not found in the default location of ~/.mulsh.d/mulsh"
    echo "Please set MULSH_TOP_DIR in your ~/.mulshrc file."
    exit 1
  else
    echo "Creating a default .mulshrc file in your home directory."
    echo "Please modify as needed."
    cp ~/.mulsh.d/mulsh/mulshrc.template ~/.mulshrc
    mkdir -p ~/.mulsh.d/dependencies
  fi
fi

echo "Sourcing ~/.mulshrc"
source ~/.mulshrc

alias qc="bash $MULSH_TOP_DIR/scripts/qc.sh"
alias mulsh="bash $MULSH_TOP_DIR/scripts/mulsh.sh"
alias mulsh:go="cd $MULSH_TOP_DIR"
# shortcuts
alias mle="deno run --allow-write --allow-env --allow-net --allow-run --no-check $MULSH_TOP_DIR/src/eval.ts $@"
alias mlm="mulsh mlcp $@"
alias mlq="mulsh qc $@"
alias mlc="mulsh corb $@"
alias mlr="mulsh rest $@"
alias mlu="mulsh update $@"
alias mli="mulsh init $@"


echo "Done."