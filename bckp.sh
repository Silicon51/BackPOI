#!/bin/bash

config_file="$(dirname "$0")/bckp_conf.txt"
log_file="/var/log/backpoi/bckp_logfile.log"
self_path="$(dirname "$0")/$(basename "$0")"
exec 3>&1
exec > >(tee -a "$log_file") 2>&1  # Redirect both stdout and stderr to the log file
source "$config_file"
# Declare some variables
today=$(date +%s)
now=$(date +%Y-%m-%d_%H-%M-%S)
int=1
jnt=1
knt=1

log_message() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1"
}
echo_console() {
    echo -e "$1" >&3
}
help() {
    echo_console "" && echo_console "" && echo_console "Usage:\t\tbackpoi COMMAND [Parameter]"&& echo_console ""
    echo_console "Commands:"
    echo_console "-m, manual\t\tStart manual backup to folder choosen in configuration file. Required parameter is path for backup"
    echo_console "-l, logs\t\tPrint logfile from location $log_file"
    echo_console "-c, conf\t\tOpen configuration file from location $config_file"
    echo_console "-p, periodical\t\tStart periodical backup fully based on configuration file. No additional parameters needed" && echo_console ""
    echo_console "Example:" && echo_console "backpoi -m /mnt/device_1/backup_folder" && echo_console ""
    echo_console "This will create new folder in choosen directory using today's date as name and then copy all files and folders indicated in configuration file there"
    exit
}
welcome() {
    echo_console ""&& echo_console ""&& echo_console "Welcome to BackPOI - easy and simple backup script for bash console"
    echo_console ""&& echo_console ""&& echo_console "Script path is $self_path"
    help
}
error() {
    echo_console ""&& echo_console ""&& echo_console "Wrong syntax!"&& echo_console ""&& echo_console "Run 'backpoi --help' for more information"
    exit 1
}
edit_conf() {
    nano $config_file >&3
    exit 0
}
logs() {
    cat $log_file >&3
    exit 0
}
backup() {
    jnt=1
    if ! [ -z "$1" ]; then # If an argument to function was given then it's run by manual backup
        local destination=$1
        for filee in "${bckp_fls[@]}"; do
	        log_message "copying files from $filee to $destination [${jnt}/${bck_fls_count}]"
	        cp -R "$filee" "$destination/"\
	        && log_message "files from $filee copied to $destination [${jnt}/${bck_fls_count}]"\
	        || log_message "failed to copy all files from $filee to $destination [${jnt}/${bck_fls_count}]"
           ((jnt++))
	    done
    else # If there is no argument to function then it's run by period backup
        for filee in "${bckp_fls[@]}"; do
            log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: copying files from $filee to $destination [${jnt}/${bck_fls_count}]"
	        cp -R "$filee" "$destination/"\
	        && log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: files from $filee copied to $destination [${jnt}/${bck_fls_count}]"\
	        || log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: failed to copy all files from $filee to $destination [${jnt}/${bck_fls_count}]"
            ((jnt++))
	    done
    fi
}
config_backup() {
    cp  "$config_file" "$self_path" "$1"
    log_message "Script and config files copied to backup folder $1"
}
read_conf_file() {
    echo "--------------------" >> "$log_file" && log_message "Script execution started" && log_message "Script path is $self_path"
    if ! [ -e "$config_file" ]; then
        log_message "Config file not found! Backup not created!"
        exit 1
    fi
    # Dynamically determine backup periods, folders and destinations based on config file
    backup_periods=($(grep -oP 'b\d+_period=\K\d+' "$config_file"))
    bckp_fls=($(grep -oP 'path\d+="[^"]+"' "$config_file" | grep -oP '"\K[^"]+'))
    bckp_dest=($(grep -oP 'dest\d+="[^"]+"' "$config_file" | grep -oP '"\K[^"]+'))
    # Count the number of folders, periods and destinations
    bck_periods_count="${#backup_periods[@]}" && log_message "Number of periods of backup: $bck_periods_count"
    bck_fls_count="${#bckp_fls[@]}" && log_message "Number of folders/paths to backup: $bck_fls_count"
    bck_dest_count="${#bckp_dest[@]}" && log_message "Number of destination backup paths: $bck_dest_count"
}
manual() {
    if [ -z "$1" ]; then
        log_message "Path is missing, backup not created!"
        exit 1
    fi
    log_message "Manual backpu was called to $1"
    read_conf_file

    destination=$1"/"$now
    if ! [ -e "$destination" ]; then
        log_message "$destination folder doesn't exist"
        mkdir -p "$destination" &&  log_message "$destination folder created"
    fi
    backup $destination
    config_backup $destination
}
periodical() {
    log_message "Periodical backup was called"
    read_conf_file

    for period in "${backup_periods[@]}"; do
        days_passed=$(( (today - "d$int") / 86400 ))
        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: days passed since last backup: $days_passed"

        # Check if days passed since last backup excide defined backup period
        if [ "$days_passed" -gt "$period" ]; then
            log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: backup is older than configured period=${period}days"

	        for destn in "${bckp_dest[@]}"; do
                destination="${destn}/${period}d"
                if ! [ -e "$destination" ]; then
                    log_message "$destination folder doesn't exist"
                    mkdir -p "$destination" &&  log_message "$destination folder created"
                fi

   		        # Purge old backup if exist
    	        if [ -z "$(ls -A "$destn/${period}d")" ]; then
	        	    rm -R "$destination"/* && log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: folder purged"
	            else
		        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destn/${period}d folder already empty"
	            fi

                # Copy all files to choosen directory
                backup
		        ((knt++))
	        done
            knt=1

            # Update date of last backup in configuration file, if data do not exist it will be created
	        if grep -q "^d$int=" "$config_file"; then
                sed -i "s/^d$int=.*/d$int=$today/" "$config_file"
		        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: date of backup updated in configuration file"
            else
                echo "d$int=$today" >> "$config_file"
		        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: d$int do not exist in configuration file"
		        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: d$int=$today added to configuration file"
	        fi
            log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: new backup created"
        else
        log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: newer than assign period, nothing to be done"
        fi
	    ((int++))
    done

    # Check for folder structure and if not exist create it. Then create backup in new folder structure
    log_message "Checking if all destination folders from config files exist"
    knt=1
    for destn in "${bckp_dest[@]}"; do

        int=1
        for period in "${backup_periods[@]}"; do
            destination="${destn}/${period}d"
            if ! [ -e "$destination" ]; then
                log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder doesn't exist"
                mkdir -p "$destination" &&  log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder created"\
                || log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder creation failed"
                backup
            else
                log_message "[${knt}/${bck_dest_count}] [${int}/${bck_periods_count}]: $destination folder exist"
            fi
            ((int++))
        done
        ((knt++))
    done

    # Script and config file backup
    for destn in "${bckp_dest[@]}"; do
        config_backup $destn
    done
}



case $1 in
manual) "$@";;
periodical) "$@";;
"-m") manual;;
"-p") periodical;;
"-c") edit_conf;;
"conf") edit_conf;;
"-l") logs;;
"logs") logs;;
"") welcome;;
"--help") help;;
"-h") help;;
help) "$@";;
*) error;;
esac

log_message "Logs are accesible here: $log_file"
log_message "Script execution completed"