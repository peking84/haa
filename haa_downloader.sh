#!/bin/bash
#       /-----------------------------------------------------------------------\
#       | HAA Binary File Downloader,                                           |
#       | Useful for downloading HAA Binary files for custom OTA update servers |
#       | Copyright (C) 2020 AJAX                                               |
#       |                                                                       |
#       | This program is free software: you can redistribute it and/or modify  |
#       | it under the terms of the GNU General Public License as published by  |
#       | the Free Software Foundation, either version 3 of the License, or     |
#       | (at your option) any later version.                                   |
#       |                                                                       |
#       | This program is distributed in the hope that it will be useful,       |
#       | but WITHOUT ANY WARRANTY; without even the implied warranty of        |
#       | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
#       | GNU General Public License for more details.                          |
#       |                                                                       |
#       | https://www.gnu.org/licenses/gpl-3.0.html                             |
#       \-----------------------------------------------------------------------/
#
download_haa(){
	echo "--------------------------------------------------------"
	echo
	version_meta=$(curl -s "https://api.github.com/repos/$owner/$repository/releases/tags/$version")
	validation=$(echo "$version_meta" | grep -Po '(?<="message": ")[^"]*')
	files=($(echo "$version_meta" | grep -Po '(?<="browser_download_url": ")[^"]*'))

	if [ -z "$validation" ]
	then
		if [ ! -d "$webroot/haa/$version" ]; then
			mkdir "$webroot/haa/$version"
		fi
		for i in "${files[@]}"
		do
			file_name="$(basename $i)"
			echo -n "Saving $webroot/haa/$version/$file_name ... "
			curl -sLo "$webroot/haa/$version/$file_name" "$i"
			if [ "$?" -ne 0 ]
			then
				echo "Failed to retrieve, check connection or user permissions"
			else
				echo "Done"
			fi
		done
	else
		echo "Incorrect Version?"
	fi
}

haa_downloader_config(){
	echo
	echo "Setting up config for HAA Downloader"
	PS3='Please choose: '
	echo
	wr_options=("/var/www/html (Apache, lighthttpd Default)" "/usr/share/nginx/html (Nginx Default" "Custom")
	select i in "${wr_options[@]}"
	do
		case "$i" in
			"/var/www/html (Apache, lighthttpd Default)")
				webroot="/var/www/html"
				;;
			"/usr/share/nginx/html (Nginx Default")
				webroot="/usr/share/nginx/html"
				;;
			"Custom")
				while [ ! -n "$webroot" ] || [ ! -d "$webroot" ]
				do
					echo -n "Please enter an absolute path to your webroot: "
					read webroot
					webroot="${webroot%/}"
					if [ ! -d "$webroot" ]
					then
						echo "Invalid Directory, try again..."
						echo
					fi
				done
				;;
			*) echo "invalid option $REPLY"
				;;
		esac
		echo '"web_root": "'"$webroot"'"' > haa_downloader.conf
		echo "Setting HAA Folder to: $webroot/haa"
		echo
		break
	done
}

haa_downloader_help(){
	echo
	echo
	echo "Downloading the latest version"
	echo "--------------------------------------------------------"
	echo
	echo "	To download the latest version execute the script with no parameters"
	echo "	'sudo ./haa_downloader.sh'"
	echo "	* Will download latest version (ie. 3.3.3) to <webroot>/haa/3.3.3/"
	echo "	* Will copy latest version to <webroot>/haa/"
	echo
	echo "	Example"
	echo "	sudo ./haa_downloader.sh"
	echo
	echo
	echo "Downloading a specific version"
	echo "--------------------------------------------------------"
	echo
	echo "	To download a specific version execute the script with the version flag -v followed by the desired version."
	echo "	'sudo ./haa_downloader.sh -v <version>'"
	echo
	echo "	* Will download the requested version (ie 3.3.3) to <webroot>/haa/3.3.3/"
	echo "	* Won't overwrite files in the main HAA Folder '<webroot>/haa/' (Reserved for latest version)"
	echo
	echo "	Example"
	echo "	sudo ./haa_downloader.sh -v 3.3.3"
	echo
	echo
	echo "HAA Downloader Setup / Running for the first time"
	echo "--------------------------------------------------------"
	echo
	echo "	To configure the <webroot> folder of your web server you can use the -s flag to enter setup mode"
	echo
	echo "	When running the script for the first time you will automatically enter setup to configure your web servers root file serving path (webroot)"
	echo "	If you have installed Apache or lighthttpd with default settings you can simply select option 1 or you can set a custom path"
	echo
	echo "	Example"
	echo "	sudo ./haa_downloader.sh -s"
	echo
	echo
}

haa_downloader_usage(){
	echo "sudo ./haa_downloader.sh		<---Download Latest Version"
	echo "sudo ./haa_downloader.sh -v <version>	<---Download Specific Version"
	echo "sudo ./haa_downloader.sh -s		<---Run Setup Mode"
	echo "sudo ./haa_downloader.sh -h		<---Help"
	echo
}
###########################################################################################################################################
echo
echo "============================================================="
echo "HAA Binary Downloader Copyright (C) 2020  AJAX
This program comes with ABSOLUTELY NO WARRANTY;
This is free software, and you are welcome to redistribute it
under certain conditions.
See the GNU General Public License for more details."
echo "============================================================="
echo
owner="RavenSystem"
repository="haa"
script_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
while getopts ":hsv:" arg
do
	case "${arg}" in
		h)
			haa_downloader_help
			exit 0
			;;
		s)
			haa_downloader_config
			;;
		v)
			version="$OPTARG"
			;;
		:)
			echo "$0: Must supply an argument to -$OPTARG." >&2
			echo
			haa_downloader_usage
			exit 1
			;;
		?)
			echo "Invalid option: -${OPTARG}."
			echo
			haa_downloader_usage
			exit 2
			;;
	esac
done
webroot=$(cat -s "$script_path/haa_downloader.conf" | grep -Po '(?<="web_root": ")[^"]*')
if [ -z "$webroot" ]
then
	haa_downloader_config
fi
if [ -n "$version" ]
then
	echo "Attempting to download the specified verion: $version"
	download_haa
else
	version=$(curl -s "https://api.github.com/repos/$owner/$repository/releases/latest" | grep -Po '(?<="tag_name": ")[^"]*')
	echo "Attempting to download the latest version: $version"
	download_haa
	echo
	echo -n "Copying latest files to: "
	pwd
	echo "--------------------------------------------------------"
	echo
	cp -v "$webroot"/haa/"$version"/* "$webroot"/haa/
fi
echo
rate_limit=$(curl -s "https://api.github.com/rate_limit" | grep -Pom 1 '(?<="limit": )[^,}]*')
rate_status=$(curl -s "https://api.github.com/rate_limit" | grep -Pom 1 '(?<="remaining": )[^,}]*')
echo "Github ratelimits unauthenticated request to $rate_limit per hour"
echo "this script uses two calls per run and you have $rate_status remaining"
echo
echo "Complete, exiting"
echo
