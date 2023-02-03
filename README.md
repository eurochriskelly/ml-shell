# mulsh

`mulsh` (MarkLogic shell) is a command-line tool for interacting with MarkLlogic using bash.

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

## Usage

To see available options, run `mulsh`