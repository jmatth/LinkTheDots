#!/usr/bin/env bash

# This directory will contain any custom extension scripts.
ext_dir=".link_ext"

function link_dotfiles()
{
	# This string will contain regex for any
	# files or directories you want to ignore.
	link_ignore=""

	# Some default ignores.
	link_ignore="link\.sh $ext_dir \.gitmodules \.gitignore"

	# Get script directory
	script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

	#Check if we're in a submodule and set directories accordingly.
	if (cd $script_dir && is_submodule)
	then
		dotfiles_dir=`dirname $script_dir`
	else
		dotfiles_dir="$script_dir"
	fi

	# Now we run any custom extensions.
	if [ -d $script_dir/$ext_dir ]
	then
		for extension in $(ls $script_dir/$ext_dir)
		do
			source $script_dir/$ext_dir/$extension
		done
	fi

	# Now symlink and files that git is tracking
	# but that haven't been added to the ignore array.
	echo -e "\e[1;35mSymlinking dotfiles:\e[m"
	for file in $(cd $dotfiles_dir && git ls-files)
	do
		ignoreThis=false

		for word in ${link_ignore}
		do
			if echo $file | grep $word &> /dev/null
			then
				ignoreThis=true
				break
			fi
		done

		if [ $ignoreThis != true ]
		then
			if [ "$(readlink ~/.$file)" != "$dotfiles_dir/$file" ]
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
				rm -rf ~/.$file &> /dev/null
				ln -sf $dotfiles_dir/$file ~/.$file
			fi
		fi
	done

	# Last, we install a post-merge hook to keep everything up to date.
	install_post_merge_hook
}

function install_post_merge_hook()
{
	if ! [ -f $dotfiles_dir/.git/hooks/post-merge ]
	then
		echo "Installing post merge hook"
		hook="$dotfiles_dir/.git/hooks/post-merge"
		echo "#!/usr/bin/env bash" > $hook
		echo "(cd $dotfiles_dir && git submodule update --init --recursive)" \
			>> $hook

		# if this script was run with any arguments then we want
		# to keep them when it's run by the hook.
		echo "$script_dir/link.sh $*" >> $hook

		# Make it executable
		chmod 755 $hook

		# This seems to be the first run, so we'll go ahead
		# and initialize the submodules.
		echo "Assuming submodules are empty, initializing now"
		(cd $dotfiles_dir && git submodule update --init --recursive)
	fi
}

function is_submodule() 
{       
	(cd "$(git rev-parse --show-toplevel 2> /dev/null)/.." && 
	git rev-parse --is-inside-work-tree) 2> /dev/null | grep true &> /dev/null
}

link_dotfiles
