# mlsh

`mlsh` (MarkLogic shell) is a command-line, "swiss-army knife" for
interacting with and developing MarkLogic Application. It is intended
as a lowest-common-denominator tool, (fully written in bash), and
preloaded in your user environment where it can be used across
projects, regardless of build system.

`mlsh` commands can be run with known parameters and scripted. However,
if no parameters are provided, the will run interactively. See #Usage below.>

## Installation

### Download
To get started, create a folder for mlsh, e.g.
```
mkdir -p ~/.mlsh.d
cd ~/.mlsh.d
```

The download and unpack the release
```
curl -s https://api.github.com/repos/eurochriskelly/mlsh/releases/latest \
  | grep zipball_url \
  | awk -F": " '{print $2}' \
  | awk -F\" '{print $2}' \
  | wget -qi - -O mlsh.zip
```
Move the archive contents into the current folder.

### Configure

Add the following to your `.profile` or equivalent init file. e.g.

`source ~/mlsh.d/init.sh`

First time you run, a `~/mlshrc` file is created for your environment.
Please fix any warnings so yo have full mlsh capabilities!

## Updates

To update to the latest version, run:

`mlsh update`

Alternatively, if not using the release, pull the latest code using `git pull`.

## Features & Usage

`mlsh`, when run alone lists all available commands. Commands are typically
interactive (but can be scripted) and run using the syntax `mlsh <command>`.
More information on any command can be found using `mlsh help <command>`.

The following table list the main features:

|Command  |Description                                |
|---------|-------------------------------------------|
|qc       |Push and pull workspaces from database     |
|modules  |Download modules, edit, load & reset state |
|eval     |Evaluate a locally stored script           |

# Usage

## Interactive
Commands run withoiut options should prompt the user for input.
e.g. Transferring documents from one instance to another should be as
simple as:

```
$ mlsh transfer
mlsh v0.1.0:
  Select the source host:
  1) LOC: http://localhost
  2) TST: http:/foo.bar.com
  3) ACC: http://baz.qux.com
  #? 2

  Select the destination host:
  1) LOC: http://localhost
  #? 1

  Select a collector or enter name of custom collector:
  1) First 100 documents
  2) My favourites list
  #? ../custom.xqy

etc.
```

## Scripting

Check the help for scripting options as follows:

`mlsh help <command>`


