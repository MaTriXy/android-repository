#!/bin/bash

basedir=$(dirname "$0")

DL_HOST=${DL_HOST:-https://dl.google.com}
DL_PATH=android/repository

# TODO auto detect latest version, e.g. 2-1 and 3
# How to discover these files? Option 1, proxy and logging; Option 2,
GENERAL_SITE=repository2-1
ADDON_SITE_INDEX=addons_list-3

echo synchronizing indices

wget -N "${DL_HOST}/${DL_PATH}/${ADDON_SITE_INDEX}.xml" -P ${DL_PATH}

sites=("${GENERAL_SITE}")
while read -r addon_site; do
	sites+=("${addon_site}")
done <<< "$(perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' ${DL_PATH}/${ADDON_SITE_INDEX}.xml | sed s/.xml//g)"

for site in "${sites[@]}"; do
	sub_path=$(perl -nle 'print $& if m{.*/|}' "${site}")
	wget -N "${DL_HOST}/${DL_PATH}/${site}.xml" -P "${DL_PATH}/${sub_path}"
done

echo downloading packages

for site in "${sites[@]}"; do
	echo "${site}"
	sub_path=$(echo "${site}" | perl -nle 'print $& if m{.*/|}')
	perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' "${DL_PATH}/${site}.xml" | sed "s~^~${DL_HOST}/${DL_PATH}/${sub_path}~g" | wget -N -P "${DL_PATH}/${sub_path}" -c -i -
done

echo removing obsolete files
echo ${DL_PATH}/${ADDON_SITE_INDEX}.xml > ${DL_PATH}/downloaded
for site in "${sites[@]}"; do
	sub_path=$(echo "${site}" | perl -nle 'print $& if m{.*/|}')
	echo "${DL_PATH}/${site}.xml" >> ${DL_PATH}/downloaded
	perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' "${DL_PATH}/${site}.xml" | sed "s~^~${DL_PATH}/${sub_path}~g" >> ${DL_PATH}/downloaded
done
downloaded=$(cat ${DL_PATH}/downloaded)
while read -r file; do
	if ! echo "${downloaded}" | grep -q "${file}"; then
		echo "${file}"
		rm "${file}"
	fi
done <<< "$(find ${DL_PATH} -type f -not -path android/repository/downloaded)"

echo
echo httpd conf
echo 'include the following lines in your apache httpd.conf file (or a file included by it, e.g. httpd-vhosts.conf)'
sed "s/ROOT/$(pwd | sed 's/\\//\\\\\\//g')/g" "${basedir}/apache2.conf"
