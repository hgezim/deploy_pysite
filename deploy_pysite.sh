#!/bin/bash

# ensure that exceptions are treated as such and program exists!
set -e

# =================================================
# = deploy_pysite version 0.1.0
# = 
# = Created by Gezim Hoxha
# = License: GPL 2
# =
# = If you're using virtualenv, this script will
# =     install PIP packages and even build 
# =     build packages from source then install
# =     them into your virtual environment.
# = See SETTINGS section for instructions.
# =
# = July, 2010
# =
# = TO DO
# = - 
# =================================================
# = REQUIRES
# = bash >=3.1
# = curl
# = pip
# =================================================

usage="\
USAGE: \n\
Modify nonpip_packages and pip_packages according to your needs. These can be found in the source\
of this script in SETTINGS section.\n\
Once SETTINGS have been modified, activate your virtual environment, then call this script. \n\
If you're not using virtualenvwrapper, set VIRTUAL_ENV environment variable \
to your virtual environemt directory. \n\
\n\
Also, you may want to ensure that the download dir is set to where you want it in SETTINGS section.\
"

# ensure we're in a virtual environment

if [[ "$VIRTUAL_ENV" = "" ]]
then
    echo -e $usage
    exit 5
fi

# =================================================
# ====================SETTINGS=====================
# =================================================

# Directory to store source archives
dg_downloads_dir="$HOME/downloads"

# Add/remove non-pip packages you [don't] want to install here.
# IMPORTANT: Only .tar.gz packages are supported.
#
# You must add a package URL and function pair to nonpip_packages array.
# If no custom install is required (i.e. normal ./config, make, make install will do) leave 
#   function call empty. For example:
#   "http://www.example.com/pack.tar.gz" ""
# If you need custom install calls, create a function that makes those calls in CUSTOM FUNCTIONS
#   area below. The function calls can include arguments.
#   For example:
#   "http://www.example.com/pack02.tar.gz" "install_pack02"
#   Or with a function call argument:
#   "http://www.example.com/pack04.tar.gz" "install_package four"
#
# MAKE SURE YOU USE QUOTES.
#
nonpip_packages=(
    "http://oligarchy.co.uk/xapian/1.0.21/xapian-core-1.0.21.tar.gz"
        ""
    "http://oligarchy.co.uk/xapian/1.0.21/xapian-bindings-1.0.21.tar.gz"
        "function_xapian_bindings"
    )

# Add/remove pip packages you [don't] want to install here.
# Version is included to ensure you get the same packages
#   whenever you install.
# Example:
#   "django" "1.2.1"
#
# MAKE SURE YOU USE QUOTES.
#
pip_packages=(
    "django" "1.2.1"
    "django-haystack" "1.0.1-final"
    "xapian-haystack" "1.1.3beta"
    "MySQL-python" "1.2.3c1"
    )

# =================================================
# =================CUSTOM FUNCTIONS================
# You should use variables such as $VIRTUAL_ENV.
# =================================================
function_xapian_bindings()
{
    ./configure --with-python XAPIAN_CONFIG="$VIRTUAL_ENV/bin/xapian-config" --prefix="$VIRTUAL_ENV"
    make
    make install
}



# =================================================
# ====================REAL CODE====================
# ===Don't touch unless you are sure you need to.==
# =================================================
# =================================================

# Create the downloads dir.
# Nothing will happen if it already exists.
mkdir -p "$dg_downloads_dir"

temp_file="/tmp/$(basename $0).$$.tmp"

# Build and install non-pip packages
build_install()
{
    for ((i=0; i<${#nonpip_packages[@]}; i+=2))
    do
        #pip_install "${pip_packages[i]}" "${pip_packages[i+1]}"
        #get package name
        package_name="${nonpip_packages[i]##*/}"
        package_dir="${package_name%.tar.gz}"
        
        echo "Installing $package_name to $VIRTUAL_ENV with..."
        cd "$dg_downloads_dir"
        
        # Check if directory exists.
        # -d test doesn't work on case insensitive FS's (e.g. OS X)
        if (cd "$package_dir" 2>/dev/null)
        then
            cd "$package_dir"
        elif [ -f "$package_name" ]
        then
            # if package is already downloaded
            tar xzf "$package_name"
            cd "$package_dir"
        else
            curl -sS "${nonpip_packages[i]}" -O > /dev/null
            tar xzf "$package_name"
            cd "$package_dir"
        fi
        
        # if odd array index has no function, do a standard make
        # Otherwise, run custom function.
        custom_function=${nonpip_packages[i+1]}
        if [[ "$custom_function" = "" ]]
        then
            set -x
            ./configure --prefix="$VIRTUAL_ENV" >>"$temp_file" 2>&1
            make >>"$temp_file" 2>&1
            make install >>"$temp_file" 2>&1
            set +x
        else
            set -x
            "$custom_function" >>"$temp_file" 2>&1
            set +x
        fi
        echo "...done."
        
    done
}

# Install pip packages
# param: $1 is the package name
# param: $2 is the package version
# The package version is required
#  to ensure the exact setup is installed everytime.
pip_install()
{
    if (( $# != 2 ))
    then
        echo "pip_install requires 2 arguments."
        return 25
    fi
    
    echo "Installing $1 to $VIRTUAL_ENV with..."
    set -x
    pip install "$1"=="$2" >>"$temp_file" 2>&1
    set +x
    echo "...done."
}

# Now install the packages if they're enabled.
build_install

for ((i=0; i<${#pip_packages[@]}; i+=2))
do
    pip_install "${pip_packages[i]}" "${pip_packages[i+1]}"
done

echo -e "\nInstall was successful. See $temp_file for details."