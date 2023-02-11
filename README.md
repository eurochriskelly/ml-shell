# mulsh

`mulsh` (MarkLogic shell) is a command-line, "swiss-army knife" for
interacting with and developing MarkLogic Application. It is
developed lowest-common-denominator tool, (fully written in
bash), and preloaded in your user environment where it can be used
across projects, regardless of build system.

`mulsh` commands can be run with known parameters and scripted. However,
if no parameters are provided, the will run interactively. See #Usage below.>

## Installation

### Download
To get started, create a folder for mulsh, e.g.
```
mkdir -p ~/.mulsh.d
cd ~/.mulsh.d
```

The download and unpack the release
```
curl -s https://api.github.com/repos/eurochriskelly/mulsh/releases/latest \
  | grep zipball_url \
  | awk -F": " '{print $2}' \
  | awk -F\" '{print $2}' \
  | wget -qi - -O mulsh.zip
```
Move the archive contents into the current folder.

### Configure

Add the following to your `.profile` or equivalent init file. e.g.

`source ~/mulsh.d/init.sh`

First time you run, a `~/mulshrc` file is created for your environment.
Please fix any warnings so yo have full mulsh capabilities!

## Updates

To update to the latest version, run:

`mulsh update`

Alternatively, if not using the release, pull the latest code using `git pull`.

## Features & Usage

`mulsh`, when run alone lists all available commands. Commands are typically
interactive (but can be scripted) and run using the syntax `mulsh <command>`.
More information on any command can be found using `mulsh help <command>`.

The following table list the main features:

|Command  |Description                                |
|---------|-------------------------------------------|
|qc       |Push and pull workspaces from database     |
|modules  |Download modules, edit, load & reset state |
|eval     |Evaluate a locally stored script           |
|mlcp     |Mlcp wrapper                               |

# Usage

## Interactive
Commands run withoiut options should prompt the user for input.
e.g. Transferring documents from one instance to another should be as
simple as:

```
$ mulsh transfer
mulsh v0.1.0:
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

`mulsh help <command>`
