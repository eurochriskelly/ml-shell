# mulsh

`mulsh` (MarkLogic shell) is a command-line, "swiss-army" tool for
interacting with and developing MarkLlogic Application. It is
developed purely as lowest-common-denominator tool, (fully written in
bash), and preloaded in your user environment where it can be used
across projects, regardless of build system.

## Installation

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
Move the archive contents into the current folder

Add the following to your `.bashrc` or equivalent init file.

`source path/to/mulsh/init.sh`

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