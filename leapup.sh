#!/bin/bash
# leapup.sh
# (c) 2018 Mathias.Homann@openSUSE.org
#
# Prepares your repositories in openSUSE for a distribution upgrade by changing the URLs
#
# Prerequisites:
# 1. System needs to have the latest updates installed for the current distribution
# 2. All repositories need to have prioritiey set that makes it 100% clear in which order you want them to be used
# 3. All repositories that are enabled have to have a version for the target release
# 4. All repositories should have the release numbers in the URL.
#    (4. is usually true for Packman, and all Repos from the suse build service)

# This script does NOT come with any warranty of any sorts.
# If you break your system you get to keep the pieces.


. /etc/os-release

while getopts ":ht:f:" opt; do
    case $opt in
        h)
            echo -e "\nSyntax: $0 -t <target version> -f <source version>, -h for this help\n\n"
            cat <<EOF
leapup.sh (c) 2018 Mathias.Homann@openSUSE.org

Prepares your repositories in openSUSE for a distribution upgrade by changing the URLs
Prerequisites:
1. System needs to have the latest updates installed for the current distribution
2. All repositories need to have prioritiey set that makes it 100% clear in which order you want them to be used
3. All repositories that are enabled have to have a version for the target release
4. All repositories should have the release numbers in the URL.
   (4. is usually true for Packman, and all Repos from the suse build service)

This script does NOT come with any warranty of any sorts.
If you break your system you get to keep the pieces.
EOF
	exit 0
        ;;

        t)
            new=$OPTARG
            ;;

        f)
            old=$OPTARG
            ;;
            
        \?)
            echo "Unknown option: -$OPTARG" >&2;
            exit 1
            ;;
        
        :)  echo "Missing option argument for -$OPTARG" >&2;
            exit 1
            ;;
        
        *)  echo "Unimplemented option: -$OPTARG" >&2;
            exit 1
            ;;
        
    esac
done

[ -z "${old}" ] && old=${VERSION}
repodir=/etc/zypp/repos.d
oldrepodir=/etc/zypp/repos.d_${old}
newrepodir=/etc/zypp/repos.d_${new}


echo "Preparing your upgrade from ${NAME} ${old} to ${NAME} ${new}. Please lean back and relax."

#
# Step 1: modifying repositories for new URLs
#

[ -d ${repodir}_${old} ] && {
    echo "backup of repositories already exists in ${oldrepodir}" >&2
    exit 1
}
[ -d ${newrepodir} ] && {
    echo "New repository folder already exists in ${newrepodir}" >&2
    exit 1
}


mkdir -p ${newrepodir}
cd ${repodir}

for repofile in *repo; do
{
	echo -n converting ${repofile} to ${newrepodir}/$(echo ${repofile}|sed -e "s/${old}/${new}/g") ... ;
	cat "${repofile}" | sed -e "s/${old}/${new}/g" > "${newrepodir}/$(echo ${repofile}|sed -e "s/${old}/${new}/g")" ;
	echo done.
}
done;

echo "Repositories for a seamless upgrade from ${NAME} ${old} to ${NAME} ${new} have been prepared in ${newrepodir}."

#
# Step 2: renaming old repository directory, linking to the new one
#
    
mv ${repodir} ${oldrepodir}
ln -s ${newrepodir} ${repodir}

#
# Step 3: clearing the zypper cache
#

zypper cc --all

#
# Step 4: refreshing zypper. This is where you will notice things goeing berserk if there are missing repositories
#
zypper ref || {
	echo "Something has gone horribly wrong."
	echo "Rolling back the repository changes (but keeping a backup of the new structure in ${newrepodir})"
    
	rm ${repodir}
	mv ${repodir}_${old} ${repodir}
	zypper cc --all
	zypper ref
	exit 1;
}

#
# Done.
#

echo "Congratulations. If you got this far without errors you should be fine with doing a seamless upgrade now."
echo "Run the following commands:"
echo "zypper up --download only zypper libzypp rpm; zypper up zypper libzypp rpm"
echo "zypper dup -l --download only --allow-vendor-change --allow-arch-change --recommends; zypper dup -l --allow-vendor-change --allow-arch-change --recommends"

exit 0

