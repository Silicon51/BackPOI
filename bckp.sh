#!/bin/bash

readonly config_file="$(dirname "$0")/bckp_conf.txt"
readonly log_file="/var/log/backpoi/bckp_logfile.log"
readonly self_path="$(dirname "$0")/$(basename "$0")"

exec 3>&1                           # Redirect desired logs only to console 
exec > >(tee -a "$log_file") 2>&1   # Redirect both stdout and stderr to the log file
source "$config_file"               # Read configuration file 

# Declare some variables
log_level=1 # Default value, override by configuration file
# Defined log levels
readonly ERROR=1
readonly INFO=2
readonly DEBUG=3

readonly today=$(date +%s)
readonly now=$(date +%Y-%m-%d_%H-%M-%S)
int=1
jnt=1
knt=1
date_period=date$int
progress=""


log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    if [ "$level" = "$ERROR" ]; then
        echo -e "[ERROR]\t$timestamp - $progress$message"
    elif [ "$level" = "$INFO" ] && [ $level -le $log_level ]; then
        echo -e  "[INFO]\t$timestamp - $progress$message"
    elif [ "$level" = "$DEBUG" ] && [ $level = $log_level ]; then
        echo -e  "[DEBUG]\t$timestamp - $progress$message" >> "$log_file"
    fi
}
echo_console() {
    echo -e "$1" >&3
}
help() {
    echo_console "" && echo_console "Usage:\tbackpoi COMMAND [Parameter]"&& echo_console ""
    echo_console "Commands:"
    echo_console "-c, conf\t\tOpen configuration file from location $config_file"
    echo_console "-l, logs\t\tPrint logfile from location $log_file"
    echo_console "-L, loglevel\t\tIf kept without parameter read logging level. Allowed parameters: '1' or ERROR, '2' or INFO and '3' for DEBUG"
    echo_console "-m, manual\t\tStart manual backup to folder choosen in configuration file. Required parameter is path for backup"
    echo_console "-p, periodical\t\tStart periodical backup fully based on configuration file. No additional parameters needed"
    echo_console "    path\t\tPrint path of script"
    echo_console "-s, schedule\t\tOpen Crontab"
    echo_console "" && echo_console "Example:"
    echo_console "\tbackpoi -m /mnt/device_1/backup_folder"
    echo_console "This will create new folder in choosen directory using today's date as name and then copy all files and folders indicated in configuration file there"
    echo_console "\tbackpoi -L 1" 
    echo_console "This will setup logging level to 1 [ERROR]"
    exit 0
}
welcome() {
    echo_console "\n\nWelcome to BackPOI - easy and simple backup script for bash console\n\n\nScript path is $self_path"
    check_conf_file
    first_usage=$(grep -oP 'first_usage=\K.*' "$config_file")
    #if [ $first_usage=true ]; then
    #
    #first_usage=false
    #sed -i "s/\(first_usage=\).*/\1$first_usage/" "$config_file"
    #else
    #fi
    help
}
path() {
    echo_console ""&& echo_console ""&& echo_console "Script path is $self_path"
}
error() {
    echo_console "\nWrong syntax!\nRun 'backpoi --help' for more information"
    exit 1
}
edit_conf() {
    check_conf_file
    nano $config_file >&3
    exit 0
}
log_level_update() {
    check_conf_file
    if [ -z "$1" ]; then
        echo_console "Log Level is set to $log_level"
        echo_console "1 - ERROR"
        echo_console "2 - INFO"
        echo_console "3 - DEBUG"
        exit 0
    fi
    if [ "$1" -ne $DEBUG ] && [ "$1" -ne $INFO ] && [ "$1" -ne $ERROR ] ; then
        error
        exit 1
    fi
    sed -i "s/\(log_level=\).*/\1$1/" "$config_file"
    exit 0
}
schedule() {
    # Open crontab
    crontab -e >&3\
    || { echo_console "\nCrontab not installed - try >>apt install crontab<<\nfor more check https://man7.org/linux/man-pages/man5/crontab.5.html"; exit 1; } 
}
logs() {
    # Open log file
    check_conf_file
    cat $log_file >&3
    exit 0
}
check_conf_file() {
    touch "$config_file" || { log_message "$ERROR" "Config file not found, backup not created!"; exit 1; }
    touch "$log_file" || { log_message "$ERROR" "Could not create log file"; exit 1; }
    log_level=$(grep -oP 'log_level=\K.*' "$config_file") 
}
read_conf_file() {
    echo "--------------------" >> "$log_file" && log_message "$INFO" "Script execution started. Script path: $self_path"
    # Dynamically determine backup periods, folders and destinations based on config file
    backup_periods=($(grep -oP 'b\d+_period=\K\d+' "$config_file"))
    bckp_fls=($(grep -oP 'path\d+="[^"]+"' "$config_file" | grep -oP '"\K[^"]+'))
    bckp_dest=($(grep -oP 'dest\d+="[^"]+"' "$config_file" | grep -oP '"\K[^"]+'))
    # Count the number of folders, periods and destinations
    bck_periods_count="${#backup_periods[@]}"
    bck_fls_count="${#bckp_fls[@]}" && log_message "$DEBUG" "Number of folders/files to backup: $bck_fls_count"
    bck_dest_count="${#bckp_dest[@]}"
    #next_subperiod=$(grep -oP 'next_subperiod=\K.*' "$config_file")
    subperiods=($(grep -oP 'subperiod_\d+=\K[A-Za-z]+' "$config_file"))
}
check_folder_existance() {
    local destination=$1
    if ! [ -e "$destination" ]; then
        log_message "$DEBUG" "$destination folder doesn't exist"
        mkdir -p "$destination" &&  log_message "$INFO" "$destination folder created"
    fi
}
folder_structure_check() {
    # Check for folder structure and if not exist create it. Then create backup in new folder structure
    local knt=1
    local period=$1
    local subperiods=(A B)
    local subperiod=C
    for destn in "${bckp_dest[@]}"; do
        destination_preriods_progress $knt $int
        log_message "$INFO"  "Checking if all destination folders from config files exist"
        for subperiod in "${subperiods[@]}"; do
            destination_assigment $destn $period $subperiod
            if ! [ -e "$destination" ]; then
                log_message "$DEBUG" "$destination folder doesn't exist"
                mkdir -p "$destination" &&  log_message "$INFO"  "$destination folder created"\
                || log_message "$ERROR" "$destination folder creation failed"
                backup $destination 
                conf_file_update $int $subperiod
            else
                log_message "$DEBUG" "$destination folder exist"
            fi
        done
        ((knt++))
    done
}
conf_file_update() {
    local int=$1
    local subperiod=$2
    local date_period=date$int
    destination_preriods_progress $knt $int
    # Update date of last backup in configuration file, if data do not exist it will be created
    if grep -q "^$date_period=" "$config_file"; then
        sed -i "s/^$date_period=.*/date$int=$today/" "$config_file" \
        && log_message "$DEBUG" "date of backup updated in configuration file" \
        || log_message "$ERROR" "date of backup not updated in configuration file. Something goes wrong"
    else
        log_message "$DEBUG" "$date_period do not exist in configuration file"
        echo "$date_period=$today" >> "$config_file" \
        && log_message "$DEBUG" "$date_period=$today added to configuration file" \
        || log_message "$ERROR" "$date_period=$today not added to configuration file Something goes wrong"
    fi
    
    # Update which subdirectory was used this time
    log_message "$DEBUG" "Current subperiod for $date_period was $subperiod"
    if [ "$subperiod" == "A" ]; then
        subperiod=B
    else
        subperiod=A
    fi
    if grep -q "^subperiod_$int=" "$config_file"; then
        sed -i "s/^subperiod_$int=.*/subperiod_$int=$subperiod/" "$config_file" \
        && log_message "$DEBUG" "New subperiod will be $subperiod" \
        || log_message "$ERROR" "Subperiod not updated in configuration file. Something goes wrong"
    else
        log_message "$DEBUG" "subperiod_$int do not exist in configuration file"
        echo "subperiod_$int=$subperiod" >> "$config_file" \
        && log_message "$DEBUG" "subperiod_$int=$subperiod added to configuration file" \
        || log_message "$ERROR" "subperiod_$int=$subperiod not added to configuration file Something goes wrong"
    fi
}
old_folder_purge() {
    # Purge old backup if exist
    local destination=$1
    destination_preriods_progress $knt $int
    if ! [ -z "$(ls -A "$destination")" ]; then
	    rm -R -f "$destination"/* && log_message "$DEBUG" "folder purged" \
        || log_message "$ERROR" "folder cannot be purged"
	else
	    log_message "$DEBUG" "$destn/${period}d folder already empty"
	fi
}
source_progress() {
    local jnt=$1
    src_progress="[${jnt}/${bck_fls_count}]"
}
destination_preriods_progress() {
    local knt=$1
    local int=$2
    progress="[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: "
}
destination_assigment() {
    local destn=$1
    local period=$2
    local subperiod=$3
    destination="${destn}/${period}d/$subperiod"
}
config_backup() {
    local progress=""
    cp  "$config_file" "$self_path" "$1" \
    && log_message "$INFO"  "Script and config files copied to backup folder $1"\
    || log_message "$ERROR" "Failed to copy script and config files to backup folder $1"
}
backup() {
    local destination=$1
    local jnt=1
    # Copy all files to choosen directory
    if [ -z "$2" ]; then # If run by manual backup procedure then progress field is blank
        destination_preriods_progress $knt $int
    fi
    for filee in "${bckp_fls[@]}"; do
        source_progress $jnt
        log_message "$INFO" "copying files from $filee to $destination $src_progress"
	    cp -R "$filee" "$destination/"\
        && log_message "$DEBUG" "files from $filee copied to $destination $src_progress"\
        || log_message "$ERROR" "failed to copy all files from $filee to $destination $src_progress"
        ((jnt++))
	done
}
manual() {
    progress=""
    check_conf_file
    read_conf_file
    if [ -z "$1" ]; then
        log_message "$ERROR" "Path is missing, backup not created!"
        exit 1
    fi
    log_message "$INFO" "Manual backup was called to $1"
    
    destination=$1"/"$now
    check_folder_existance $destination
    backup $destination "manual"
    config_backup $destination
}
periodical() {
    check_conf_file
    read_conf_file
    log_message "$INFO" "Periodical backup was called"
    log_message "$DEBUG" "Number of periods of backup: $bck_periods_count"
    log_message "$DEBUG" "Number of destination backup paths: $bck_dest_count"
    for period in "${backup_periods[@]}"; do
        destination_preriods_progress $knt $int
        date_period=date$int
        days_passed=$(( (today - date_period) / 86400 ))
        subperiod=${subperiods[($int-1)]}
        log_message "$INFO"  "days passed since last backup: $days_passed"
        # Check if days passed since last backup excide defined backup period
        if [ "$days_passed" -gt "$period" ]; then
            log_message "$INFO"  "backup is older than configured period=${period}days"
	        for destn in "${bckp_dest[@]}"; do
                destination_assigment $destn $period $subperiod
                check_folder_existance $destination
                old_folder_purge $destination
                backup $destination
		        ((knt++))
	        done
            knt=1
            conf_file_update $int $subperiod
        else
            log_message "$INFO" "newer than assign period, nothing to be done"
        fi
        folder_structure_check $period
	    ((int++))
    done
    # Script and config file backup
    for destn in "${bckp_dest[@]}"; do
        config_backup $destn
    done
}


case $1 in
"") welcome;;
"-c") edit_conf;;
"conf") edit_conf;;
help) "$@";;
"-h") help;;
"-l") logs;;
"logs") logs;;
"-L") log_level_update $2;;
"loglevel") log_level_update $2;;
manual) "$@";;
"-m") manual $2;;
periodical) "$@";;
"-p") periodical;;
path) $@;;
schedule) $@;;
"-s") schedule;;
*) error;;
esac

progress=""
log_message "$INFO" "Logs are accesible here: $log_file"
log_message "$INFO" "Script execution completed."