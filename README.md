LinkTheDots
===========

A convenient script for keeping your git-managed dotfiles linked into your home
directory.

Installation
------------

###Dotfiles Layout

LTD expects your dotfiles repo to be laid out in a specific way so that it knows
what to do with each file. In the top directory of your repo, it looks for:

1. `link/`: Any files in this directory will get symlinked to your home
   directory, prefixed with a `.`.

2. `copy/`: Any files in this directory will get copied to your home directory
   **once**. If there is already a file there that conflicts, then you will be
   prompted to resolve it, unless you specified an override flag at runtime.

3. `source/` Any files placed here will be sourced at runtime, before any
   linking. This should contain scripts for accomplishing any special tasks that
   aren't supported out of the box.
