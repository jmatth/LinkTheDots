#!/usr/bin/env bash

# Exit if any of the commands fail.
# set -e

# This array will contain any strings for directories you want to ignore.
declare -a IGNORE

# Obviously we don't want to link this script.
IGNORE+=('link.sh')
IGNORE+=('link_ext')

# Get current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# This directory will contain any custom extension scripts.
EXT_DIR="$DIR/.link_ext"

# Now we run any custom extensions.
for script in $(ls $EXT_DIR)
do
	source $EXT_DIR/$script
done

pushd $DIR &> /dev/null

# Now symlink and files that git is tracking
# but that haven't been added to the ignore array.
echo -e "\e[1;35mSymlinking dotfiles:\e[m"
for file in $(git ls-files)
do
	ignoreThis=false

	for word in ${IGNORE[@]}
	do
		if echo $file | grep -q $word
		then
			ignoreThis=true
			break
		fi
	done

	if [ $ignoreThis != true ]
	then
		if [ "$(readlink ~/.$file)" != "$DIR/$file" ]
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
			ln -sf $DIR/$file ~/.$file
		fi
	fi
done

# Last, we install a post-merge hook to keep everything up to date.
if ! [ -f $DIR/.git/hooks/post-merge ]
then
	echo "Installing post merge hook"
	hook="$DIR/.git/hooks/post-merge"
	echo "#!/usr/bin/env bash" > $hook
	echo "cd $DIR" >> $hook
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
