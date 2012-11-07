#!/usr/bin/env bash

# Script configs
IGNORE="bashrc|bash_profile|zshrc|ssh|link|gitmodules|pathogen_submodule"

# Get current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXT_DIR="$DIR/.link_ext"

for i in $(ls $EXT_DIR)
do
	source $EXT_DIR/$i
done

echo -e "\e[1;35mSymlinking all other config files:\e[m"
cd $DIR
for file in $(git ls-files | egrep -v $IGNORE)
do
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
done

if ! [ -f .git/hooks/post-merge ]
then
	echo "Installing post merge hook"
	hook=".git/hooks/post-merge"
	echo "#!/usr/bin/env bash" > $hook
	echo "cd $DIR" >> $hook
	echo "git submodule init && git submodule update" >> $hook
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
