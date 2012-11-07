#!/usr/bin/env bash

# This array will contain any strings for directories you want to ignore.
declare -a IGNORE

# Obviously we don't want to link this script.
IGNORE+=('link.sh')
IGNORE+=('.link_ext')

# Get current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# This directory will contain any custom extension scripts.
EXT_DIR="$DIR/.link_ext"

# Now we run any custom extensions.
for i in $(ls $EXT_DIR)
do
	source $EXT_DIR/$i
done

pushd $DIR &> /dev/null

# to the ignore array.
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
	echo "git submodule init && git submodule update" >> $hook

	# if this script was run with an argument then we want
	# to keep it when it's run by the hook.
	if ! [ -z $1 ]
	then
		echo "./link.sh $1" >> $hook
	else
		echo "./link.sh" >> $hook
	fi
	chmod 755 $hook

	echo "Assuming submodules are empty, initializing now"
	git submodule init && git submodule update
fi

popd &> /dev/null
