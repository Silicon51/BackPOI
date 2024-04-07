HI!

Backpoi is easy and simple bash script with shell commands used for backup. Main goal is to made a copy of files which are on one drive (eg. SSD) and copy it to second drive to store as HDD or NAS storage

MANUAL:
1) Both files should be in this same folder eg for ubuntu 22.04 (tested) strongly suggested is /usr/local/bin/ thanks to that it is possoble to access to script by typing $backpoi instead of full path
2) Script allows for 2 types o backup:
  * manual - requires parameter of destination path and there create new folder for backup (name is date_time of script
  * periodical - both source and destination for backup cames from config file. Backup is only made if given time for each backup period is exeed.
