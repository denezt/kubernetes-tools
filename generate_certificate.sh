#!/bin/bash

# Includes
source "./util.conf"

# Global date for archives
generate_date="$(date '+%s')"

# Define the Certification and Key path
cert_dir="/var/snap/microk8s/current/certs"

# Define the backup directory
bkup_dir="${certs_path}/backups"

error(){
	printf "\033[35mError:\t\033[31m${1}!\033[0m\n"
	exit 1
}

# Automatically updating the template
add_new_ip(){
	ip_addr=${1}
	template="csr.conf.template"
	# Copy Source Template to current directory
	cp -a -v ${cert_dir}/${template} ./${template}
	# Ensure that the template was copied locally
	if [ -f "${template}" ];
	then
		# Extract the last ip address name
		last_ip_entry=$(egrep 'IP.[0-9]' ${template} | tail -n 1 | cut -d'=' -f1 | cut -d'.' -f2)
		# Now increase 'IP' name
		next_ip_entry=$((${last_ip_entry}+1))
		# Unique update for configuration file
		if [ -z "$(egrep ${ip_addr} ${cert_dir}/${template})" ];
		then
			# Append new ip address to CSR configuration template
			sudo sed -i "s|#MOREIPS|IP.${next_ip_entry}\ =\ ${ip_addr}\n#MOREIPS|g" ${template}
			sudo mv -v ${template} ${cert_dir}/${template}
		fi
	fi
}

generate_new_crsfile(){
	# This will create the new crs file
	# after the current template has been
	# updated.
	sudo microk8s stop
	sudo microk8s start
}

# [PURPOSE]: Execute this step first to remove older files.
# Remove all of the previous session files
flush_older_resources(){
	resource=( 'new_apiserver.csr' 'new_apiserver.crt' 'new_apiserver.key' 'ca.crt' 'ca.key' 'csr.*' )
	for res in ${resource[@]}
	do
		if [ -f "${res}" ];
		then
			printf "Remove, local instance of ${res}\n"
			rm -v ${res}
		fi
	done
	unset $resource
}

extract_resources(){
	flush_older_resources
	resource=( 'csr.conf' 'ca.crt' 'ca.key' )
	for res in ${resource[@]};
	do
		if [ ! -f "./${res}" ];
		then
			cp -a -v ${cert_dir}/${res} ./${res}
		fi
	done
}

generate_files(){
	# Extract any required resources
	extract_resources

	# Create the new API Server key
	openssl genpkey -algorithm RSA -out new_apiserver.key -pkeyopt rsa_keygen_bits:2048

	# Create the new API Server key
	openssl req -new -key new_apiserver.key -out new_apiserver.csr -config csr.conf

	# Sign the CSR with your CA certificate and key to generate the new certificate
	openssl x509 -req -in new_apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
	-out new_apiserver.crt -days 365 -extensions req_ext -extfile csr.conf
}

copy_key_and_cert(){
	# Create a backup directory for current key if not exists, and ensure
	[ ! -d "${bkup_dir}" ] && \
	sudo mkdir -v ${bkup_dir} && \
	sudo chown -R ${file_owner} ${bkup_dir}
	# Ensure that the backup
	if [ -d "${bkup_dir}" ];
	then
		# Copy current in the certificate path to backup directory
		for ext in 'crt' 'key';
		do
			sudo cp -a -v ${certs_path}/server.${ext} ${bkup_dir}/server-${generate_date}.${ext}
			if [ ! -e "${bkup_dir}/server-${generate_date}.${ext}" ];
			then
				error "Unable to run script, backup ${bkup_dir}/server-${generate_date}.${ext} was not created"
			fi
		done
	else
		error "Unable to continue backup directory was not created"
	fi
	for ext in 'crt' 'key';
	do
		# Copy resource to target path
		sudo cp new_apiserver.${ext} ${certs_path}/server.${ext}
		# Change ownership of resource
		sudo chown ${file_owner} ${certs_path}/server.${ext}
	done
}

# [PURPOSE]: Parameter parser
extract_value(){
	arg=${1}
	if [ -n "${arg}" ];
	then
		result=$(echo $arg | cut -d':' -f2 | cut -d'=' -f2 )
	else
		error "Missing or misformed command was given"
	fi
	echo "${result}"
}

usages(){
	printf "\033[36mUSAGES:\033[0m\n"
	printf "\033[35m$0 \033[32m--action=update\033[0m\n"
}

commands(){
	printf "\033[36mCOMMANDS:\033[0m\n"
	printf "\033[35mFlush Older Resources\t\033[32m[ cleanup, flush, remove ]\033[0m\n"
	printf "\033[35mUpdate Certificate\t\033[32m[ update ]\033[0m\n"
}

help_menu(){
	printf "\033[36mExpand and Generate Certificate tool\033[0m\n"
	printf "\033[35mExtract Configuration\t\033[32m[ action:{COMMAND}, --action={COMMAND} ]\033[0m\n"
	echo;
	commands
	echo;
	usages
	exit 1
}

for argv in $@
do
	case $argv in
		action:*|--action=*)
		# Exsure that the utilites configuration file exists before action execution
		[ ! -f "./util.conf" ] && error "Missing or unable to locate './util.conf' configuration file"
		_action=$(extract_value $argv);;
		-h|-help|--help) help_menu;;
	esac
done

case $_action in
	update)
	extract_resources
	generate_new_crsfile
	add_new_ip ${new_ip_address}
	generate_files
	case $update_active in
		'true') copy_key_and_cert;;
	esac
	;;
	cleanup|flush|remove) flush_older_resources;;
esac
