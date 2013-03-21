LinkTheDots
===========

Easily keep your git-managed dotfiles linked to your home directory with this
simple bash script.

Prerequisite
------------
This script assumes you have a dotfiles repository that mimics the layout of
your home directory without the leading `.`.  So say for example you want
`~/.bashrc`, `~/.vimrc`, and `~/.vim/colors/inkpot.vim` to be managed by git.
Then your dotfiles directory should look like:
<pre>
dotfiles/
  bashrc
  vimrc
  vim/colors/inkpot.vim
</pre>

This way it's easy to tell where everything is going to go, and you don't have
to use `ls -a` to see your files inside the repo.

Installation
------------

###By Submodule (Recommended)

To add this project as a submodule, navigate to the root of your dotfiles repo
and enter:
```bash
git submodule add git://github.com/jmatth/LinkTheDots.git .ltd
```
This will add the repository as a submodule into your dotfiles repo. Now to
check for updates, navigate into the submodule directory and run `git pull`. If
there are any new updates then they'll get pulled down. Then you can navigate
back to the root of your dotfiles, commit the changes, and push back to github.

**NOTE**: If you plan on adding custom extensions (see bellow) or just hacking
at the script, I would HIGHLY recommend forking this repository first, and then
adding your fork as a submodule instead. That way you can commit and push any
changes you make.

###By Committing Directly

If submodules aren't your style, you can just add the script directly to your
dotfiles repo and it will still work. Unfortunately, to get any future updates
you'll have to manually check this repo for new commits. To add this script
directly, just download it into the root of your dotfiles repo, possibly with:
```bash
wget http://raw.github.com/jmatth/LinkTheDots/master/link.sh
```
Then add and commit the script as you would any other file. It will
automatically detect that it's not in a submodule and adjust its settings
accordingly, and ignore itself by default.

Usage
-----

###Basic Linking
Once you have LinkTheDots installed in your dotfiles repo, using it to create
links is simple: `./.ltd/link.sh` or `./link.sh`, depending on where you
installed it. Running the script without any arguments will make it search
through your dotfiles and create corresponding links in your home directory.
After it's done creating the links it will also create a post-merge hook in your
local repo, so that whenever you pull down new updates the script will get rerun
and automatically link the new files for you.

###Additional Options
Besides the main functionality, LTD has a few other built in options for you to
use. I've described them below, but you can always access a list of them by
running the script with `--help` as an argument.

| Option              | Meaning                                             |
| ------------------- | --------------------------------------------------- |
| `--help`            | Display help text and exit.                         |
| `--skip-hook`       | Don't install a post-merge hook.                    |
| `--skip-extensions` | Don't execute extension scripts (see next section). |
| `--remove-links`    | Remove any links created by LTD.                    |
| `--remove-hook`     | Remove the post-merge hook installed by LTD.        |


Extending
---------

So this is all well and good, but what if you have some files you want to do
something special with? Easy, just write a simple script that:

1. Adds the file name(s) to the string `link_ignore`.

2. Performs whatever special checks and actions you require.

If you installed LTD by committing it directly to your dotfiles, create a
directory in the root of your repo called `link_ext`. If you installed via a
submodule, then this directory should already exist there. Place/commit your
script there. Then the next time you run `./link.sh` your script will be
executed before any linking takes place, and any files matching the patterns you
have added to `link_ignore` will be...well, ignored. 

Also, please keep in mind that files are ignored based on
[regular expressions](http://en.wikipedia.org/wiki/Regular_expression). So if
you have two files called `myfile` and `myfile2`, and you append `"myfile"` to the
`link_ignore` string, then both files will be ignored. If you wanted to ignore
just the first file, you would have to append `"^myfile$"` to `link_ignore`.

For a simple example, look at the included `99-example` file in `link_ext`.
