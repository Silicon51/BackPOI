check_if_run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 
        exit 1
    else
        echo "Root access granted" 
    fi
}


echo "fetching latest version"
latest_version=`
    curl https://github.com/Silicon51/BackPOI/releases/latest --verbose 2>&1 |
    grep Location |
    sed -e "s|.*/v||"`

echo "version: $latest_version"