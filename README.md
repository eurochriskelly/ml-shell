# ml-shell

## Installation


To get started, create a folder for ml-shell, e.g.
```
mkdir -p ~/opt/ml-shell
cd ~/opt/ml-shell
```

The download and unpack the release
```
curl -s https://api.github.com/repos/eurochriskelly/ml-shell/releases/latest \
  | grep zipball_url \
  | awk -F": " '{print $2}' \
  | awk -F\" '{print $2}' \
  | wget -qi - -O release.zip
```

Move the archive contents into the current folder

Add the following to your `.bashrc` or equivalent init file.

`source path/to/ml-shell/init.sh`

## Usage

To see available options, run `mlsh`