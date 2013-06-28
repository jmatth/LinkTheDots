#!/usr/bin/env bash
# Get script directory
script_dir=$( cd $( dirname $0 ) && pwd )

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
option_remove_hook=true
option_remove_links=true
option_remove_copies=true

# p: prompt, r: replace, i: ignore
option_copy_conflict_action="p"
option_link_conflict_action="r"

# Locations to store lists of installed files if installed
# in a submodule
linked_list_location_sub=$script_dir/dotfiles_linked
copied_list_location_sub=$script_dir/dotfiles_copied
ignored_list_location_sub=$script_dir/dotfiles_ignored

# Locations to store lists of installed files if installed
# in the main dotfiles repo
linked_list_location_no_sub=$HOME/.dotfiles_linked
copied_list_location_no_sub=$HOME/.dotfiles_copied
ignored_list_location_no_sub=$HOME/.dotfiles_ignored

# This line will be added as the second line in the hook,
# so that it can be positively identified if remove is called
hook_id_line="#ltd_hook"

#--------------------------------------------------------------------------
# Now declare our functions
#--------------------------------------------------------------------------
function install_files()
{
    local install_type=$1
    shift
    if [ "$install_type" == "link" ]; then
        local from_dir=$dotfiles_dir/link
        local installed_list=$linked_files_list
        local install_confict_action=$option_link_conflict_action
        local install_action="ln -s"
    elif [ "$install_type" == "copy" ]; then
        local from_dir=$dotfiles_dir/copy
        local installed_list=$copied_files_list
        local install_confict_action=$option_copy_conflict_action
        local install_action="cp_helper"
    else
        return 1
    fi

    if test -d $from_dir; then
        echo "[36m${install_type}ing dotfiles:[m"
        for file in $(cd $from_dir && git ls-files); do
            if ! grep "$HOME/$file" $installed_list &> /dev/null; then
                echo "[32m$file[m"

                existing_file_action=$install_confict_action

                # Create parent directories if they don't exist.
                if test ! -d `dirname ~/$file`; then
                    mkdir -p `dirname ~/$file`
                fi

                # If a file with that name already exists, check with the user
                if test -e ~/$file; then
                    if [ "$existing_file_action" != "r" ] && \
                            [ "$existing_file_action" != "i" ]; then
                        echo "[33mFile $HOME/$file already exists.[m"
                        echo "[33mPlease choose action to take:[m"
                    fi

                    while [ "$existing_file_action" != "r" ] && \
                            [ "$existing_file_action" != "ra" ] && \
                            [ "$existing_file_action" != "i" ] && \
                            [ "$existing_file_action" != "ia" ]; do
                        echo "r:  Replace it with the version from dotfiles. The current version will be"
                        echo "    copied to $HOME/.${file}.dotfiles.bak"

                        echo "ra: Same as 'r', but also do so for all subsequent conflicts."

                        echo "i:  Ignore it. The current version will be left in place and you will not"
                        echo "    receive this prompt on subsequent runs."

                        echo "ia: Same as 'i', but also do so for all subsequent conflicts."

                        echo -n "[r/ra/i/ia]: "

                        read existing_file_action
                    done

                    if [ "${existing_file_action:0:1}" == "r" ]; then
                        mv ~/$file ~/$file.dotfiles.bak
                        if [ "${existing_file_action:1:1}" == "a" ]; then
                            install_confict_action="r"
                        fi
                    elif [ "${existing_file_action:0:1}" == "i" ];then
                        if [ "${existing_file_action:1:1}" == "a" ]; then
                            install_confict_action="r"
                        fi
                        echo "$HOME/$file" >> $ignored_files_list
                        continue
                    fi
                fi

                # This is here to remove broken symlinks.
                rm -rf $HOME/$file

                if $install_action $from_dir/$file $HOME/$file; then
                    # Record file as successfully installed.
                    echo "$HOME/$file" >> $installed_list
                fi
            fi
        done
    fi
}

# This is to handle submodules
function cp_helper()
{
    src=$1
    dest=$2

    if test -d $src; then
        # We have a submodule. Time to do some magic.
        # First check to make sure .git is there. Might not be
        # if they tried to run without updating submodules.
        if ! test -e $src/.git; then
            ( cd $dotfiles_dir && git submodule init && \
                git submodule update --recursive ) &> /dev/null
            if ! test -e $src/.git; then
                # Still not there, not sure what's going on. Abort.
                return 1
            fi
        fi
        cp -r $src $dest
        # If it's not a directory, means we're working with
        # the post 1.7.8 spec and need to copy the git data
        # from the parent repository.
        if ! test -d $src/.git; then
            sm_git_path=`cut -d' ' -f2 $src/.git`
            rm -rf $dest/.git
            cp -r $src/$sm_git_path $dest/.git
            sed -i '/worktree = /d' $dest/.git/config
        fi
    else
        # Not a submodule, just copy it.
        cp $src $dest
    fi
}

function check_ltd_args()
{
    for arg in $@; do
        case $arg in
            "--help") print_help $task; exit 0;;
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
    if test -z "$1"; then
        echo "Usage: $0 <command> [<args>]"
        echo
        echo "Valid commands are:"
        echo "install   Install dotfiles into your home directory"
        echo "remove    Remove installed dotfiles"
        echo "update    Pull new changes to your dotfiles from git"
        echo
        echo "Run $0 <command> --help for help with specific commands."
        echo "Go to http://github.com/jmatth/LinkTheDots for additional help or to submit issues."
    elif [ "$1" == "install" ]; then
        echo "Usage: $0 install [<args>]"
        echo "args:"
        echo "    --skip-link:         Don't link files in link/."
        echo "    --skip-copy:         Don't copy files in copy/."
        echo "    --skip-hook:         Don't install post-merge hook."
        echo "    --skip-pre:          Don't source pre scripts."
        echo "    --skip-post:         Don't source post scripts."
        echo "    --copy-replace:      Replace conflicting files during copy."
        echo "    --copy-ignore:       Ignore conflicting files during copy."
        echo "    --help:              Print this message and exit."
    elif [ "$1" == "remove" ]; then
        echo "Usage: $0 remove [<args>]"
        echo "args:"
        echo "    --remove-hook:       Remove post-merge hook."
        echo "    --remove-links:      Remove all linked files."
        echo "    --remove-copies:     Remove all copied files."
        echo "    --remove-all:        Remove copied and linked files, and hook."
        echo "    --help:              Print this message and exit."
    fi
}

function source_scripts()
{
    if ! test -d $1; then
        return 1
    else
        local source_dir=$1
        shift
        for script in $(ls $source_dir)
        do
            source $source_dir/$script
        done
    fi
}

function check_install_hook()
{
    if ! test -e $hook_file; then
        echo -n "Install post-merge hook to install any new dotfiles on each pull [Y/n]: "
        read local install_hook_choice
        if [ "$(echo "$install_hook_choice" | awk '{print tolower($0)}')" != \
            'n' ]; then
            install_hook $@
        else
            touch $hook_file
        fi
    fi
}

function install_hook()
{
    echo "[36mInstalling post merge hook.[m"
    echo "#!/usr/bin/env bash" > $hook_file
    echo $hook_id_line >> $hook_file
    echo "cd $dotfiles_dir" >> $hook_file
    echo "git submodule init && git submodule update --recursive" >> $hook_file
    echo "$script_dir/$(basename $0) install $@" >> $hook_file

    # Make it executable
    chmod 755 $hook_file
}

function update_dotfiles()
{
    cd $dotfiles_dir && git pull
}

function remove_dead_links()
{
    if test -r $linked_files_list; then
        current_line_number=1

        echo "[33mRemoving broken links:[m"
        for file in `cat $linked_files_list`; do
            if test -h $file; then
                if test ! -r $file; then
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

        if test ! -s $linked_files_list; then
            rm $linked_files_list
        fi
    fi
}

function remove_dotfiles()
{
    if [[ "$1" == "copied" ]]; then
        list_file=$copied_files_list
        rm -f $ignored_files_list
    else
        list_file=$linked_files_list
    fi

    if test -s $list_file; then
        echo "[33mRemoving all $1 files:[m"
        for file in `cat $list_file`; do
            echo "[31m$file[m"
            rm -rf $file

            # Restore backup file if it exists.
            if test -e $file.dotfiles.bak; then
                mv $file.dotfiles.bak $file
            fi
        done
        rm $list_file
    fi
}

function remove_hook()
{
    if test -e $hook_file && [ "$(awk 'NR==2' $hook_file)" == "$hook_id_line" ]; then
        echo "[33mRemoving post-merge hook.[m"
        rm -f $hook_file
    fi
}

function is_submodule()
{
    ( cd "$(git rev-parse --show-toplevel 2> /dev/null)/.." &&
    git rev-parse --is-inside-work-tree ) 2> /dev/null | grep true &> /dev/null
}

#--------------------------------------------------------------------------
# Start executing the functions
#--------------------------------------------------------------------------
# Check if we're in a submodule and set directories accordingly.
# Also decide where to keep the list of linked/copied files.
if ( cd $script_dir && is_submodule ); then
    dotfiles_dir=$( cd $( dirname $( cd "$script_dir" && git rev-parse \
        --show-toplevel 2> /dev/null ) ) && git rev-parse --show-toplevel )
    linked_files_list=$linked_list_location_sub
    copied_files_list=$copied_list_location_sub
    ignored_files_list=$ignored_list_location_sub
else
    dotfiles_dir=$( cd $script_dir && git rev-parse --show-toplevel )
    linked_files_list=$linked_list_location_no_sub
    copied_files_list=$copied_list_location_no_sub
    ignored_files_list=$ignored_list_location_no_sub
fi

# Where insall the post-merge hook
# This needs to be here so dotfiles_dir is defined.
hook_file=$dotfiles_dir/.git/hooks/post-merge

# The fist argument should tell us what we're going to do.
task=`echo "$1" | awk '{print tolower($0)}'`
shift

if [ "$task" == "help" ]; then
    print_help
    exit 0
elif test -z "$task"; then
    print_help
    exit 1
fi

check_ltd_args $@

if [ "$task" == "install" ]; then
    if [[ "$option_pre_scripts" == "true" ]]; then
        source_scripts $dotfiles_dir/pre $@
    fi
    if [[ "$option_link_files" == "true" ]]; then
        install_files 'link'
    fi
    if [[ "$option_copy_files" == "true" ]]; then
        install_files 'copy'
    fi
    if [[ "$option_install_hook" == "true" ]]; then
        check_install_hook $@
    fi
    if [[ "$option_post_scripts" == "true" ]]; then
        source_scripts $dotfiles_dir/post $@
    fi
    remove_dead_links
elif [ "$task" == "remove" ]; then
    if [[ "$option_remove_hook" == "true" ]]; then
        remove_hook
    fi
    if [[ "$option_remove_links" == "true" ]]; then
        remove_dotfiles "linked"
    fi
    if [[ "$option_remove_copies" == "true" ]]; then
        remove_dotfiles "copied"
    fi
elif [ "$task" == "update" ]; then
    update_dotfiles
else
    print_help
    exit 1
fi
