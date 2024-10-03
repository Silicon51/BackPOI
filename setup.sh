readonly repo=https://github.com/Silicon51/BackPOI
current_location=$(dirname "$0")
readonly log_file="/var/log/bckp_logfile.log"

check_if_run_as_root() {
    if [ $EUID -ne 0 ]; then
        echo "This script must be run as root" 
        exit 1
    else
        echo "Root access granted" 
    fi
}

download_latest_files() {
    echo "fetching latest version"
    link=$repo/releases/latest
    latest_version=`
        curl $link --verbose 2>&1 |
        grep location |
        sed -e "s|.*/v||" | tr -d '\r\n'
        `
    echo "version: $latest_version"
    download_link="$repo/archive/refs/tags/v$latest_version.zip"
    echo $download_link
    wget -P $current_location $download_link
    unzip -d $current_location "$current_location/v$latest_version.zip"
    rm "$current_location/v$latest_version.zip"
    folder_name=BackPOI-$latest_version
    chmod 777 "$current_location/$folder_name/backpoi"
    chmod 666 "$current_location/$folder_name/bckp_conf.txt"
    ln -sf "$current_location/$folder_name/backpoi" /usr/local/bin
    ln -sf "$current_location/$folder_name/bckp_conf.txt" /usr/local/bin
    touch "$log_file" 
    chmod 666 "$log_file"
}


check_if_run_as_root
download_latest_files
