#!/bin/bash

readonly config_file="$(dirname "$0")/bckp_conf.txt"
readonly log_file="/var/log/backpoi/bckp_logfile.log"
readonly self_path="$(dirname "$0")/$(basename "$0")"

exec 3>&1                           # Redirect desired logs only to console 
exec > >(tee -a "$log_file") 2>&1   # Redirect both stdout and stderr to the log file
source "$config_file"               # Read configuration file 

# Declare some variables
log_level=1 # Ddefault value, override by configuration file
# Define log levels
readonly ERROR=1
readonly INFO=2
readonly DEBUG=3

readonly today=$(date +%s)
readonly now=$(date +%Y-%m-%d_%H-%M-%S)
int=1
jnt=1
knt=1



log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    if [ "$level" = "$ERROR" ]; then
        echo -e "[ERROR]\t$timestamp - $message"
    elif [ "$level" = "$INFO" ] && [ $level -le $log_level ]; then
        echo -e  "[INFO]\t$timestamp - $message"
    elif [ "$level" = "$DEBUG" ] && [ $level = $log_level ]; then
        echo -e  "[DEBUG]\t$timestamp - $message" >> "$log_file"
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
    crontab -e >&3\
    || { echo_console "\nCrontab not installed - try >>apt install crontab<<\nfor more check https://man7.org/linux/man-pages/man5/crontab.5.html"; exit 1; } 
}
logs() {
    cat $log_file >&3
    exit 0
}
backup() {
    # Copy all files to choosen directory
    jnt=1
    if ! [ -z "$1" ]; then # If an argument to function was given then it's run by manual backup
        local destination=$1
        for filee in "${bckp_fls[@]}"; do
	        log_message "$INFO"  "copying files from $filee to $destination [${jnt}/${bck_fls_count}]"
	        cp -R "$filee" "$destination/"\
	        && log_message "$DEBUG"  "files from $filee copied to $destination [${jnt}/${bck_fls_count}]"\
	        || log_message "$ERROR"  "failed to copy all files from $filee to $destination [${jnt}/${bck_fls_count}]"
           ((jnt++))
	    done
    else # If there is no argument to function then it's run by period backup
        for filee in "${bckp_fls[@]}"; do
            log_message "$INFO"  "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: copying files from $filee to $destination [${jnt}/${bck_fls_count}]"
	        cp -R "$filee" "$destination/"\
	        && log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: files from $filee copied to $destination [${jnt}/${bck_fls_count}]"\
	        || log_message "$ERROR" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: failed to copy all files from $filee to $destination [${jnt}/${bck_fls_count}]"
            ((jnt++))
	    done
    fi
}
config_backup() {
    cp  "$config_file" "$self_path" "$1" \
    && log_message "$INFO"  "Script and config files copied to backup folder $1"\
    || log_message "$ERROR" "Failed to copy script and config files to backup folder $1"
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
}
folder_structure_check() {
    # Check for folder structure and if not exist create it. Then create backup in new folder structure
    log_message "$INFO"  "Checking if all destination folders from config files exist"
    knt=1
    for destn in "${bckp_dest[@]}"; do
        int=1
        for period in "${backup_periods[@]}"; do
            destination="${destn}/${period}d"
            if ! [ -e "$destination" ]; then
                log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder doesn't exist"
                mkdir -p "$destination" &&  log_message "$INFO"  "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder created"\
                || log_message "$ERROR" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder creation failed"
                backup
                conf_file_update $int
            else
                log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder exist"
            fi
            ((int++))
        done
        ((knt++))
    done
}
conf_file_update() {
    local int=$1
    # Update date of last backup in configuration file, if data do not exist it will be created
    if grep -q "^d$int=" "$config_file"; then
        sed -i "s/^d$int=.*/d$int=$today/" "$config_file" \
        && log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: date of backup updated in configuration file" \
        || log_message "$ERROR" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: date of backup not updated in configuration file. Something goes wrong"
    else
        log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: d$int do not exist in configuration file"
        echo "d$int=$today" >> "$config_file" \
        && log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: d$int=$today added to configuration file" \
        || log_message "$ERROR" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: d$int=$today not added to configuration file Something goes wrong"
    fi
}
check_folder_existance() {
    local destination=$1
    if ! [ -e "$destination" ]; then
        log_message "$DEBUG" "$destination folder doesn't exist"
        mkdir -p "$destination" &&  log_message "$INFO"  "$destination folder created"
    fi
}
old_folder_purge() {
    # Purge old backup if exist
    local destination=$1
    if ! [ -z "$(ls -A "$destination")" ]; then
	    rm -R -f "$destination"/* && log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: folder purged" \
        || log_message "$ERROR" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: folder cannot be purged"
	else
	    log_message "$DEBUG" "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destn/${period}d folder already empty"
	fi
}
manual() {
    check_conf_file
    read_conf_file
    if [ -z "$1" ]; then
        log_message "$ERROR" "Path is missing, backup not created!"
        exit 1
    fi
    log_message "$INFO" "Manual backup was called to $1"
    
    destination=$1"/"$now
    check_folder_existance $destination
    backup $destination
    config_backup $destination
}
periodical() {
    check_conf_file
    read_conf_file
    log_message "$INFO" "Periodical backup was called"
    log_message "$DEBUG" "Number of periods of backup: $bck_periods_count"
    log_message "$DEBUG" "Number of destination backup paths: $bck_dest_count"
    for period in "${backup_periods[@]}"; do
        days_passed=$(( (today - "d$int") / 86400 ))
        log_message "$INFO"  "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: days passed since last backup: $days_passed"
        # Check if days passed since last backup excide defined backup period
        if [ "$days_passed" -gt "$period" ]; then
            log_message "$INFO"  "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: backup is older than configured period=${period}days"
	        for destn in "${bckp_dest[@]}"; do
                destination="${destn}/${period}d"
                check_folder_existance $destination
                old_folder_purge $destination
                backup
		        ((knt++))
	        done
            knt=1
            conf_file_update $int
        else
        log_message "$INFO"  "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: newer than assign period, nothing to be done"
        fi
	    ((int++))
    done
    folder_structure_check
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

log_message "$INFO" "Logs are accesible here: $log_file\nScript execution completed."