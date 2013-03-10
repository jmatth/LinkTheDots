#!/usr/bin/env bash

# Exit if any of the commands fail.
# set -e

# This array will contain any strings for directories you want to ignore.
declare -a link_ignore

# This directory will contain any custom extension scripts.
ext_dir=".link_ext"

# Obviously we don't want to link this script.
link_ignore+=("$ext_dir")

# Get current directory
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Now we run any custom extensions.
for script in $(ls $ext_dir)
do
	source $ext_dir/$script
done

pushd $dir &> /dev/null

# Now symlink and files that git is tracking
# but that haven't been added to the ignore array.
echo -e "\e[1;35mSymlinking dotfiles:\e[m"
for file in $(git ls-files)
do
	ignoreThis=false

	for word in ${link_ignore[@]}
	do
		if echo $file | grep -q $word
		then
			ignoreThis=true
			break
		fi
	done

	if [ $ignoreThis != true ]
	then
		if [ "$(readlink ~/.$file)" != "$dir/$file" ]
		then
			echo $file
			if test ! -d `dirname ~/.$file`
			then
				mkdir -p `dirname ~/.$file`
			fi
			if test -h ~/.$file
			then
				unlink ~/.$file
			fi
			rm -rf ~/.file 2>&1 >/dev/null
			ln -sf $dir/$file ~/.$file
		fi
	fi
done

# Last, we install a post-merge hook to keep everything up to date.
if ! [ -f $dir/.git/hooks/post-merge ]
then
	echo "Installing post merge hook"
	hook="$dir/.git/hooks/post-merge"
	echo "#!/usr/bin/env bash" > $hook
	echo "cd $dir" >> $hook
	echo "git submodule update --init --recursive" >> $hook

	# if this script was run with any arguments then we want
	# to keep them when it's run by the hook.
	echo "./link.sh $*" >> $hook

	# Make it executable
	chmod 755 $hook

	# This seems to be the first run, so we'll go ahead
	# and initialize the submodules.
	echo "Assuming submodules are empty, initializing now"
	git submodule update --init --recursive
fi

popd &> /dev/null
