LinkTheDots
===========

A convenient script for keeping your git-managed dotfiles linked into your home
directory.

Installation
------------

###Dotfiles Layout

LTD expects your dotfiles repo to be laid out in a specific way so that it knows
what to do with each file. In the top of your repo, it looks for:

1. `link/`: Any files in this directory will get symlinked to your home
   directory.

2. `copy/`: Any files in this directory will get copied to your home directory
   **once**. If there is already a file there that conflicts, then you will be
   prompted to resolve it, unless you specified an override flag at runtime.
   Once a file has been copied like this, it will not be overwritten on
   subsequent runs.

3. `pre/` Any files placed here will be sourced at runtime, before any
   linking. This should contain scripts for accomplishing any special tasks that
   aren't supported out of the box.

4. `post/` Similar to the previous directory, but scripts here are sourced after
   all linking and copying is done, as the last action before ltd exits.

For example, if you want to keep `.bashrc` linked to your dotfiles on all your
machines, install a base `.ssh/config` on new machines, and run `fancyscript.sh`
before linking every time you pull updates to your dotfiles, your dotfiles repo
should look something like this:

```
dotfiles
├── copy
│   └── .ssh
│        └── config
├── link
│   └── .bashrc
└── pre
    └── fancyscript.sh
```

Once your dotfiles are in the proper places, you can install this script in one
of two ways.

###Installation with Submodule (Recommended)

To install as a submodule, navigate to the root of your dotfiles repo and run:
`git submodule add http://github.com/jmatth/LinkTheDots.git ltd`. This will add
this repo as a submodule in the directory ltd. This method is recommended
because it will be easy to update to later versions of LTD just by updating the
submodule.

###Installation by Copying

If you don't appreciate submodules in your dotfiles, you can always just copy
the script "link.sh" into the top directory of your dotfiles repo and run it
from there. The script is written to detect whether or not it is inside a
submodule, so you can just commit and run.


Usage
-----

`./link.sh [OPTIONS]`

| Option              | Meaning                                   |
| ------------------- | ----------------------------------------- |
| `--help`            | Print this message and exit.              |
| `--skip-hook`       | Don't install post-merge hook.            |
| `--skip-submodules` | Don't init and update submodules.         |
| `--skip-pre`        | Don't run pre scripts.                    |
| `--skip-post`       | Don't run post scripts.                   |
| `--skip-link`       | Don't link files in link/.                |
| `--skip-copy`       | Don't copy files in copy/.                |
| `--copy-replace`    | Replace conflicting files during copy.    |
| `--copy-ignore`     | Ignore conflicting files during copy.     |
| `--remove-hook`     | Remove post-merge hook.                   |
| `--remove-links`    | Remove all linked files.                  |
| `--remove-copies`   | Remove all copied files.                  |
| `--remove-all`      | Remove copied and linked files, and hook. |

**NOTE:** All arguments given to `link.sh` are also passed to any custom scripts
in `source/`, and specifying arguments not listed here will not create an error.
This way you can write your scripts to respond to these arguments or create a
completely different set of arguments for them to use without having to modify
the main script.
