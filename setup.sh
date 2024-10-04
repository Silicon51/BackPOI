readonly repo=https://github.com/Silicon51/BackPOI
readonly current_location=$(dirname "$0")
readonly log_file="/var/log/bckp_logfile.log"

check_if_run_as_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This instalation script must be run as root" >&2
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
}

handle_command() {
    download_latest_files
    touch "$log_file" 
    chmod 666 "$log_file"
    case $1 in
    "y") link;;
    "n") copy;;
    esac
    exit 0
    
}

copy() {
    echo "you choose copy"
    cp "$current_location/$folder_name/backpoi" /usr/local/bin
    cp "$current_location/$folder_name/bckp_conf.txt" /usr/local/bin
}

link() {
    echo "you choose link"
    ln -sf "$current_location/$folder_name/backpoi" /usr/local/bin
    ln -sf "$current_location/$folder_name/bckp_conf.txt" /usr/local/bin
}

main() {
    check_if_run_as_root
    echo "Now script will download, unpack and setup BackPOI on you linux machine."
    echo "Script will be download to your current folder"
    echo "Do you want to keep it here and then linked to /usr/local/bin?"
    echo "Otherwise it will be coiped directly to /usr/local/bin."
    echo "[y/n]"
    echo "yes - keep it here and link"
    echo "no - copy to /usr/local/bin"
    read answer
    handle_command "$answer"
    
}

main