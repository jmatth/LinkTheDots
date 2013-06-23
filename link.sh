#!/usr/bin/env bash

#--------------------------------------------------------------------------
# Here we declare some settings variables
#--------------------------------------------------------------------------
# Variables used to check specified args. Prefixed with "option"
# to avoid confusion with otherwise similarly named functions.
option_install_hook=true
option_pre_scripts=true
option_post_scripts=true
option_link_files=true
option_copy_files=true
option_update_submodules=true
option_remove_hook=false
option_remove_links=false
option_remove_copies=false

# p: prompt, r: replace, i: ignore
option_copy_conflict_action="p"

#--------------------------------------------------------------------------
# Now declare our functions
#--------------------------------------------------------------------------
function link_dotfiles()
{
    if test -d $dotfiles_dir/link
    then
        echo "[36mSymlinking dotfiles:[m"
        for file in $(cd $dotfiles_dir/link && git ls-files)
        do
            if [ "$(readlink ~/$file)" != "$dotfiles_dir/link/$file" ]
            then
                echo "[32m$file[m"

                # Create parent directories if they don't exist.
                if test ! -d `dirname ~/$file`
                then
                    mkdir -p `dirname ~/$file`
                fi

                # If a file with that name already exists, back it up.
                if test -e ~/$file
                then
                    mv ~/$file ~/$file.dotfiles.bak
                fi

                # Actually do the linking.
                ln -sf $dotfiles_dir/link/$file ~/$file
            fi

            # Add the file to the list of linked files. This is out here to
            # rebuild the list incase it gets deleted/modified.
            # FIXME: should rebuild_list be a separate function?
            if ! grep "$HOME/$file" $linked_files_list &> /dev/null
            then
                echo "$HOME/$file" >> $linked_files_list
            fi
        done
    fi
}

function copy_dotfiles()
{
    if test -d $dotfiles_dir/copy
    then
        echo "[36mCopying dotfiles:[m"
        for file in $(cd $dotfiles_dir/copy && git ls-files)
        do
            if ! grep "$HOME/$file" $copied_files_list &> /dev/null
            then
                echo "[32m$file[m"

                # Create parent directories if they don't exist.
                if test ! -d `dirname ~/$file`
                then
                    mkdir -p `dirname ~/$file`
                fi

                # If a file with that name already exists, check with the user
                if test -e ~/$file
                then
                    existing_file_action="$option_copy_conflict_action"

                    if [ "$existing_file_action" != "r" ] && \
                        [ "$existing_file_action" != "i" ]
                    then
                        echo "[33mFile $HOME/$file already exists."
                        echo "[33mPlease choose action to take:[m"
                    fi

                    while [ "$existing_file_action" != "r" ] && \
                        [ "$existing_file_action" != "i" ]
                    do
                        echo "r: Replace it with the version from dotfiles. The"
                        echo "   current version will be copied to"
                        echo "   $HOME/.${file}.dotfiles.bak"

                        echo "i: Ignore it. The current version will be left in"
                        echo "   place and you will not receive this prompt on"
                        echo "   subsequent runs."

                        read existing_file_action
                    done

                    if [ "$existing_file_action" == "r" ]
                    then
                        mv ~/$file ~/$file.dotfiles.bak
                    fi
                fi

                if [ "$existing_file_action" != "i" ]
                then
                    # This is here to remove broken symlinks.
                    rm -rf $HOME/$file

                    if test -d $dotfiles_dir/copy/$file
                    then
                        # We have a submodule. Time to do some magic.
                        cp -r $dotfiles_dir/copy/$file ~/$file

                        # First check to make sure .git is there. Might not be
                        # if they tried to run without updating submodules.
                        if test -e $dotfiles_dir/copy/$file/.git
                        then
                            # If it's not a directory, means we're working with
                            # the post 1.7.8 spec and need to copy the git data
                            # from the parent repository.
                            if ! test -d $dotfiles_dir/copy/$file/.git
                            then
                                sm_git_path=`cut -d' ' -f2 \
                                    $dotfiles_dir/copy/$file/.git`

                                rm -f ~/$file/.git

                                cp -r $dotfiles_dir/copy/$file/$sm_git_path \
                                    ~/$file/.git
                            fi
                        fi
                    else
                        # Not a submodule, just copy it.
                        cp $dotfiles_dir/copy/$file ~/$file
                    fi
                fi

                # Store that we copied this file so we don't do it next time.
                echo "$HOME/$file" >> $copied_files_list
            fi
        done
    fi
}

function check_ltd_args()
{
    for arg in $@
    do
        case $arg in
            "--help") print_help; exit 0;;
            "--skip-hook") option_install_hook=false;;
            "--skip-submodules") option_update_submodules=false;;
            "--skip-pre") option_pre_scripts=false;;
            "--skip-post") option_post_scripts=false;;
            "--skip-link") option_link_files=false;;
            "--skip-copy") option_copy_files=false;;
            "--copy-replace") option_copy_conflict_action="r";;
            "--copy-ignore") option_copy_conflict_action="i";;
            "--remove-hook") option_remove_hook=true;;
            "--remove-links") option_remove_links=true;;
            "--remove-copies") option_remove_copies=true;;
            "--remove-all") option_remove_hook=true; \
                option_remove_links=true; option_remove_copies=true;;
        esac
    done
}

function print_help()
{
    echo "Usage: ./link.sh [OPTIONS]"
    echo "OPTIONS"
    echo "--help:              Print this message and exit."
    echo "--skip-hook:         Don't install post-merge hook."
    echo "--skip-submodules:   Don't init and update submodules."
    echo "--skip-pre:          Don't source pre scripts."
    echo "--skip-post:         Don't source post scripts."
    echo "--skip-link:         Don't link files in link/."
    echo "--skip-copy:         Don't copy files in copy/."
    echo "--copy-replace:      Replace conflicting files during copy."
    echo "--copy-ignore:       Ignore conflicting files during copy."
    echo "--remove-hook:       Remove post-merge hook."
    echo "--remove-links:      Remove all linked files."
    echo "--remove-copies:     Remove all copied files."
    echo "--remove-all:        Remove copied and linked files, and hook."
}

function source_pre_scripts()
{
    # Now we source any pre scripts
    if test -d $dotfiles_dir/pre
    then
        for script in $(ls $dotfiles_dir/pre)
        do
            source $dotfiles_dir/pre/$script
        done
    fi
}

function source_post_scripts()
{
    # Now we source any post scripts
    if test -d $dotfiles_dir/post
    then
        for script in $(ls $dotfiles_dir/post)
        do
            source $dotfiles_dir/post/$script
        done
    fi
}

function install_post_merge_hook()
{
    if test ! -f $dotfiles_dir/.git/hooks/post-merge
    then
        echo "[36mInstalling post merge hook.[m"
        hook="$dotfiles_dir/.git/hooks/post-merge"
        echo "#!/usr/bin/env bash" > $hook
        echo "( cd $dotfiles_dir && git submodule update --init --recursive )" \
            >> $hook

        # if this script was run with any arguments then we want
        # to keep them when it's run by the hook.
        echo "$script_dir/link.sh $@" >> $hook

        # Make it executable
        chmod 755 $hook

        # This seems to be the first run, so we'll go ahead
        # and initialize the submodules.
        echo "[36mAssuming submodules are empty, initializing now:[m"
        ( cd $dotfiles_dir && git submodule update --init --recursive )
    fi
}

function remove_dead_links()
{
    if test -r $linked_files_list
    then
        current_line_number=1

        echo "[33mRemoving broken links:[m"
        for file in `cat $linked_files_list`
        do
            if test -h $file
            then
                if test ! -r $file
                then
                    echo "[31m$file[m"
                    unlink $file
                    sed -i -e $current_line_number"d" $linked_files_list
                else
                    current_line_number=$(($current_line_number+1))
                fi
            else
                sed -i -e $current_line_number"d" $linked_files_list
            fi
        done

        if test ! -s $linked_files_list
        then
            rm $linked_files_list
        fi
    fi
}

function remove_dotfiles()
{
    if [[ "$1" == "copied" ]]
    then
        list_file=$copied_files_list
    else
        list_file=$linked_files_list
    fi

    if test -s $list_file
    then
        echo "[33mRemoving all $1 files:[m"
        for file in `cat $list_file`
        do
            echo "[31m$file[m"
            unlink $file

            # Restore backup file if it exists.
            if test -e $file.dotfiles.bak
            then
                mv $file.dotfiles.bak $file
            fi
        done
        rm $list_file
    fi
}

function remove_post_merge_hook()
{
    echo "[33mRemoving post-merge hook.[m"
    rm -f $dotfiles_dir/.git/hooks/post-merge
}

function is_submodule()
{
    ( cd "$(git rev-parse --show-toplevel 2> /dev/null)/.." &&
    git rev-parse --is-inside-work-tree ) 2> /dev/null | grep true &> /dev/null
}

#--------------------------------------------------------------------------
# Start executing the functions
#--------------------------------------------------------------------------
# FIXME: this is here and not in a function so that script_dir and dotfiles_dir
# will be global in the script. Is there a better way to get them into the
# global scope without exporting?
# Get script directory
script_dir="$( cd "$( dirname "$0" )" && pwd )"

# Check if we're in a submodule and set directories accordingly.
# Also decide where to keep the list of linked/copied files.
if ( cd $script_dir && is_submodule )
then
    dotfiles_dir=$( cd `dirname $script_dir` && git rev-parse --show-toplevel )
    linked_files_list=$script_dir/dotfiles_linked
    copied_files_list=$script_dir/dotfiles_copied
else
    dotfiles_dir=$( cd $script_dir && git rev-parse --show-toplevel )
    linked_files_list=$HOME/.dotfiles_linked
    copied_files_list=$HOME/.dotfiles_copied
fi

check_ltd_args $@

# If we're removing anything then do that and exit.
# FIXME: is there a better way to handle this?
if [[ "$option_remove_hook" == "true" || "$option_remove_links" == "true" || \
    "$option_remove_copies" == "true" ]]
then
    if [[ "$option_remove_hook" == "true" ]]
    then
        remove_post_merge_hook
    fi
    if [[ "$option_remove_links" == "true" ]]
    then
        remove_dotfiles "linked"
    fi
    if [[ "$option_remove_copies" == "true" ]]
    then
        remove_dotfiles "copied"
    fi
    exit 0
fi

if [[ "option_update_submodules" == "true" ]]
then
    (cd $dotfiles_dir && git submodule init && git submodule update)
fi

if [[ "$option_pre_scripts" == "true" ]]
then
    source_pre_scripts $@
fi

if [[ "$option_link_files" == "true" ]]
then
    link_dotfiles
fi

if [[ "$option_copy_files" == "true" ]]
then
    copy_dotfiles
fi

# Unless told otherwise, we install a post merge hook here.
if [[ "$option_install_hook" == "true" ]]
then
    install_post_merge_hook $@
fi

remove_dead_links

if [[ "$option_post_scripts" == "true" ]]
then
    source_post_scripts $@
fi
