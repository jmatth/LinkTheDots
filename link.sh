#!/usr/bin/env bash

# This directory will contain any custom extension scripts.
ext_dir=".link_ext"

# Variables used to check specified args. Prefixed with "option"
# to avoid confusion with otherwise similarly named functions.
option_install_hook=true
option_remove_hook=false
option_remove_links=false

# Where to store a list of linked files.
linked_files_list=$HOME/.ltd_linked_files_list

# This string will contain regex for any
# files or directories you want to ignore.
link_ignore="\.gitmodules \.gitignore"

# FIXME: this is here and not in a fucntion so that script_dir and dotfiles_dir
# will be global in the script. Is there a better way to get them into the
# global scope without exporting?
# Get script directory
script_dir="$( cd "$( dirname "$0" )" && pwd )"

#Check if we're in a submodule and set directories accordingly.
if (cd $script_dir && is_submodule)
then
	dotfiles_dir=`dirname $script_dir`
	link_ignore="$(basename $script_dir) $link_ignore"
else
	dotfiles_dir="$script_dir"
	link_ignore="link\.sh $ext_dir $link_ignore"
fi

function link_dotfiles()
{

	# Now symlink any files that git is tracking
	# but that haven't been added to the ignore array.
	echo -e "\e[36mSymlinking dotfiles:\e[m"
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
				echo -e "\e[32m$file\e[m"

				if ! grep "$HOME/\.$file" $linked_files_list &> /dev/null
				then
					echo "$HOME/.$file" >> $linked_files_list
				fi

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
}

function check_ltd_args()
{
	for arg in $@
	do
		case $arg in
			"--help") print_help; exit 0;;
			"--skip-hook") option_install_hook=false;;
			"--remove-hook") option_remove_hook=true;;
			"--remove-links") option_remove_links=true;;
		esac
	done
}

function run_extension_scripts()
{
	# Now we run any custom extensions.
	if [ -d $script_dir/$ext_dir ]
	then
		for extension in $(ls $script_dir/$ext_dir)
		do
			source $script_dir/$ext_dir/$extension
		done
	fi
}

function print_help()
{
	echo "Usage: ./link.sh [OPTIONS]"
	echo "OPTIONS"
	echo "--help:           Print this message and exit."
	echo "--remove-links:   Remove all linked files."
	echo "--remove-hook:    Remove post-merge hook."
}

function install_post_merge_hook()
{
	if ! [ -f $dotfiles_dir/.git/hooks/post-merge ]
	then
		echo -e "\e[36mInstalling post merge hook.\e[m"
		hook="$dotfiles_dir/.git/hooks/post-merge"
		echo "#!/usr/bin/env bash" > $hook
		echo "(cd $dotfiles_dir && git submodule update --init --recursive)" \
			>> $hook

		# if this script was run with any arguments then we want
		# to keep them when it's run by the hook.
		echo "$script_dir/link.sh $@" >> $hook

		# Make it executable
		chmod 755 $hook

		# This seems to be the first run, so we'll go ahead
		# and initialize the submodules.
		echo -e "\e[36mAssuming submodules are empty, initializing now:\e[m"
		(cd $dotfiles_dir && git submodule update --init --recursive)
	fi
}

function remove_dead_links()
{
	current_line_number=1

	echo -e "\e[33mRemoving broken links:\e[m"
	for file in `cat $linked_files_list`
	do
		if [ -h $file ]
		then
			if ! [ -r $file ]
			then
				echo -e "\e[31m$file\e[m"
				unlink $file
				sed -i -e $current_line_number"d" $linked_files_list
			else
				current_line_number=$(($current_line_number+1))
			fi
		else
			sed -i -e $current_line_number"d" $linked_files_list
		fi
	done

	if ! [ -s $linked_files_list ]
	then
		rm $linked_files_list
	fi
}

function remove_linked_files()
{
	if [ -f $linked_files_list ] && ! [ -z $linked_files_list ]
	then
		echo -e "\e[33mRemoving all linked files:\e[m"
		for file in `cat $linked_files_list`
		do
			if [ -h $file ]
			then
				echo -e "\e[31m$file\e[m"
				unlink $file
			fi
		done

		rm $linked_files_list
	fi
}

function remove_post_merge_hook()
{
	rm -f $dotfiles_dir/.git/hooks/post-merge
}

function is_submodule() 
{       
	(cd "$(git rev-parse --show-toplevel 2> /dev/null)/.." && 
	git rev-parse --is-inside-work-tree) 2> /dev/null | grep true &> /dev/null
}

check_ltd_args $@

# If we're removing anything then do that and exit.
# FIXME: is there a better way to handle this?
if [[ "$option_remove_hook" == "true" || "$option_remove_links" == "true"]]
then
	if [[ "$option_remove_hook" == "true" ]]
	then
		remove_post_merge_hook
	elif [[ "$option_remove_links" == "true" ]]
	then
		remove_linked_files
	fi
	exit 0
fi

run_extension_scripts $@

link_dotfiles $@

# Unless told otherwise, we install a post merge hook here.
if [[ "$option_install_hook" == "true" ]]
then
	install_post_merge_hook $@
fi

remove_dead_links
