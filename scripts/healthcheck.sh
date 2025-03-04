#!/bin/sh
#This health-check script is sponsored by PMGA TECH LLP
#Licensing Terms:
#This code is free to use, distribute, use as a derivative for another code or do any such activity as allowed by M.I.T License as long as the recognition stays intact.
#The recognition may be moved to the CONTRIBUTERS.md file in case the same is being maintained in the projects in which the code is being used.
#Removing the recognition text shall construe revocation of usage rights and thus would be deemed as a copyright infringement.
#The intent of this license is ONLY to give due recognition to the contributers and there is no other intent whatsoever.
# Contributers:
# PMGA Tech LLP
# gb-123-git
 
#Exit Codes
# 0= Success
# 1= Failure

#Environment Variables
# ZT_CHK_SPECIFIC_NETWORKS=         <Enter Networks to check with space in between each entry; All networks entered here would be matched; ZT_CHK_MIN_ROUTES_FOR_HEALTH is ignored if this is used.>
# ZT_CHK_MIN_ROUTES_FOR_HEALTH=     <Should be a Number greater than 0>

# Check if specified Networks are all Connected
if [[ -n "${ZT_CHK_SPECIFIC_NETWORKS}" ]] ; then
    for network in $ZT_CHK_SPECIFIC_NETWORKS; do
        #If Network is OK, continue, else exit
        if [[ "$(zerotier-cli get ${network} status)" = "OK" ]]; then
            #Check for Routes
            interface=$(zerotier-cli get ${network} portDeviceName)
            routes=$(ip r | grep "dev ${interface}" | grep -cv "via")
            #Exit if No routes
            if [[ ${routes} -lt 1 ]]; then 
                exit 1
            else
                continue
                #echo "${network} Connected."
            fi
        #Network Status Not = OK
        else
            exit 1
        fi
    done
    exit 0
# Check for Minimum Networks
elif [[ -n "${ZT_CHK_MIN_ROUTES_FOR_HEALTH}" ]] ; then 
    # Validate the MIN value for Health Checks
    ZT_CHK_MIN_ROUTES_FOR_HEALTH=$(( ${ZT_CHK_MIN_ROUTES_FOR_HEALTH} < 1 ? 1 : ${ZT_CHK_MIN_ROUTES_FOR_HEALTH} ))
    #echo "No. Of Networks to Check: ${ZT_CHK_MIN_ROUTES_FOR_HEALTH}"
    network_count=0
    #Get List of Joined networks
    joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    for network in $joined_networks; do
        if [[ "$(zerotier-cli get ${network} status)" = "OK" ]] ; then
            #Check for Routes
            interface=$(zerotier-cli get ${network} portDeviceName)
            routes=$(ip r | grep "dev ${interface}" | grep -cv "via")
            if [[ ${routes} -lt 1 ]]; then 
                exit 1
            else
                network_count=$(expr $network_count + 1)
                #echo "${network} Connected."
            fi
            if [[ ${network_count} -ge ${ZT_CHK_MIN_ROUTES_FOR_HEALTH} ]] ; then
                #echo "${network_count} Networks Connected. Exit Success"
                exit 0
            fi
        fi
    done
    #Exit if the above count was not reached
    exit 1
#Check if ALL Networks are connected (Default - ZeroTier)
else
    #echo "Checking All Networks"
    joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    #If there are no Networks, exit Failure
    [[ -n "${joined_networks}" ]] || exit 1
    for network in $joined_networks; do
        #[[ "$(zerotier-cli get ${network} status)" = "OK" ]] || exit 1
        if [[ "$(zerotier-cli get ${network} status)" = "OK" ]]; then
            #Check for Routes
            interface=$(zerotier-cli get ${network} portDeviceName)
            routes=$(ip r | grep "dev ${interface}" | grep -cv "via")
            #Exit if No routes
            if [[ ${routes} -lt 1 ]]; then 
                exit 1
            else
                continue
                #echo "${network} Connected."
            fi
        fi
    done
fi
