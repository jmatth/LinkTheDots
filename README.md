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
  link.sh
  bashrc
  vimrc
  vim/colors/inkpot.vim
</pre>

This layout has the advantages of being easily linked by a script, while still
having all the files visible without having to resort to `ls -a`.

Installation
------------

Simply add and commit `link.sh` and optionally `.link_ext/99-example` to your
dotfiles git repo. Then run ./link.sh inside the repo once on each machine you
clone the repo to. The script will install a post-merge hook to keep all
symlinks and submodules up to date whenever you pull new changes.

Extending
---------

So this is all well and good, but what if you have some files you want to do
something special with? Easy, just write a simple script that:

1. Adds the file name(s) to the array IGNORE.

2. Performs whatever special checks and actions you require.

Create a directory in the root of your dotfiles repo called `.link_ext` and
place/commit your script there. Then the next time you run `./link.sh` your
script will be executed before any linking takes place, and any files matching
the patterns you have added to `IGNORE` will be...well, ignored. 

Also, please keep in mind that files are ignored based on
[regular expressions](http://en.wikipedia.org/wiki/Regular_expression). So if
you have two files called `myfile` and `myfile2`, and you add the string
`"myfile"` to the IGNORE array, then both files will be ignored. If you wanted
to ignore just the first file, you would have to add `"^myfile$"` to IGNORE.

For a simple example, look at the included `99-example` file in `.link_ext`.
