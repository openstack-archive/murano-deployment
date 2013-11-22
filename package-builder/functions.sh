
function die() {
    cat << EOF

***** ***** ***** *****

$@

***** ***** ***** *****

EOF
    exit 1
}


################################################################################
#
# Functions below are taken from devstack repo
# https://github.com/openstack-dev/devstack
#
################################################################################


# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
# Set global RECLONE=yes to simulate a clone when dest-dir exists
# Set global ERROR_ON_CLONE=True to abort execution with an error if the git repo
# does not exist (default is False, meaning the repo will be cloned).
# Uses global ``OFFLINE``
# git_clone remote dest-dir branch
function git_clone {
    [[ "$OFFLINE" = "True" ]] && return

    GIT_REMOTE=$1
    GIT_DEST=$2
    GIT_REF=$3

    if echo $GIT_REF | egrep -q "^refs"; then
        # If our branch name is a gerrit style refs/changes/...
        if [[ ! -d $GIT_DEST ]]; then
            [[ "$ERROR_ON_CLONE" = "True" ]] && exit 1
            git clone $GIT_REMOTE $GIT_DEST
        fi
        cd $GIT_DEST
        git fetch $GIT_REMOTE $GIT_REF && git checkout FETCH_HEAD
    else
        # do a full clone only if the directory doesn't exist
        if [[ ! -d $GIT_DEST ]]; then
            [[ "$ERROR_ON_CLONE" = "True" ]] && exit 1
            git clone $GIT_REMOTE $GIT_DEST
            cd $GIT_DEST
            # This checkout syntax works for both branches and tags
            git checkout $GIT_REF
        elif [[ "$RECLONE" == "yes" ]]; then
            # if it does exist then simulate what clone does if asked to RECLONE
            cd $GIT_DEST
            # set the url to pull from and fetch
            git remote set-url origin $GIT_REMOTE
            git fetch origin
            # remove the existing ignored files (like pyc) as they cause breakage
            # (due to the py files having older timestamps than our pyc, so python
            # thinks the pyc files are correct using them)
            find $GIT_DEST -name '*.pyc' -delete

            # handle GIT_REF accordingly to type (tag, branch)
            if [[ -n "`git show-ref refs/tags/$GIT_REF`" ]]; then
                git_update_tag $GIT_REF
            elif [[ -n "`git show-ref refs/heads/$GIT_REF`" ]]; then
                git_update_branch $GIT_REF
            elif [[ -n "`git show-ref refs/remotes/origin/$GIT_REF`" ]]; then
                git_update_remote_branch $GIT_REF
            else
                echo $GIT_REF is neither branch nor tag
                exit 1
            fi

        fi
    fi
}


# git update using reference as a branch.
# git_update_branch ref
function git_update_branch() {

    GIT_BRANCH=$1

    git checkout -f origin/$GIT_BRANCH
    # a local branch might not exist
    git branch -D $GIT_BRANCH || true
    git checkout -b $GIT_BRANCH
}


# git update using reference as a branch.
# git_update_remote_branch ref
function git_update_remote_branch() {

    GIT_BRANCH=$1

    git checkout -b $GIT_BRANCH -t origin/$GIT_BRANCH
}


# git update using reference as a tag. Be careful editing source at that repo
# as working copy will be in a detached mode
# git_update_tag ref
function git_update_tag() {

    GIT_TAG=$1

    git tag -d $GIT_TAG
    # fetching given tag only
    git fetch origin tag $GIT_TAG
    git checkout -f $GIT_TAG
}
