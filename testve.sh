#!/bin/bash

# Global constants
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD"
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data"
readonly API_ENDPOINT="https://api.laptopland.ma/serials/check.php"

# Text formatting
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Function to format and center text
center_text() {
    local text="$1"
    local width=70
    local padding=$(( ($width - ${#text}) / 2 ))
    printf "%*s%s%*s\n" $padding '' "$text" $padding ''
}


# Your Mac's serial number
MAC_SERIAL="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"

# Function to check the serial number with your API
checkSerialNumber() {
    local response
    response=$(curl -s "$API_ENDPOINT" -d "serial_number=$MAC_SERIAL")
    echo "$response"
}

# Checks if a volume with the given name exists
checkVolumeExistence() {
    local volumeLabel="$1"
    diskutil info "$volumeLabel" >/dev/null 2>&1
}

# Returns the name of a volume with the given type
getVolumeName() {
    local volumeType="$1"

    # Getting the APFS Container Disk Identifier
    apfsContainer=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
    # Getting the Volume Information
    volumeInfo=$(diskutil apfs list "$apfsContainer" | grep -A 5 "($volumeType)")
    # Extracting the Volume Name from the Volume Information
    volumeNameLine=$(echo "$volumeInfo" | grep 'Name:')
    # Removing unnecessary characters to get the clean Volume Name
    volumeName=$(echo "$volumeNameLine" | cut -d':' -f2 | cut -d'(' -f1 | xargs)

    echo "$volumeName"
}

# Defines the path to a volume with the given default name and volume type
defineVolumePath() {
    local defaultVolume="$1"
    local volumeType="$2"

    if checkVolumeExistence "$defaultVolume"; then
        echo "/Volumes/$defaultVolume"
    else
        local volumeName
        volumeName=$(getVolumeName "$volumeType")
        echo "/Volumes/$volumeName"
    fi
}

# Mounts a volume at the given path
mountVolume() {
    local volumePath="$1"

    if [ ! -d "$volumePath" ]; then
        diskutil mount "$volumePath"
    fi
}

# Check the serial number with the API before proceeding
serialCheckResponse=$(checkSerialNumber)

# Output formatting and activation check
if [[ "$serialCheckResponse" != "Activated" ]]; then
    echo -e "|--------------------------------------------------------------------------|${NC}"
    echo -e "$(center_text "${BLUE}Activation Version Entreprise${NC}")"
    echo -e "$(center_text "${BLUE}RABATTECHSTORE.MA${NC}")"
    echo -e "$(center_text "${BLUE}RABAT TECH STORE${NC}")"
    echo -e "$(center_text "${CYAN}MacBook Serial Number: ${MAC_SERIAL}${NC}")"
    echo -e "|--------------------------------------------------------------------------|${NC}"
    echo -e "$(center_text "${RED}Serial Number Status: ${serialCheckResponse}${NC}")"
    echo -e "$(center_text "${PURPLE}Contact us to activate your MacBook${NC}")"
    echo -e "|--------------------------------------------------------------------------|${NC}"

    exit 1
fi

echo -e "|-----------------------------------------|${NC}"
echo -e "|   $(center_text "Activation Version Entreprise")  |${NC}"
echo -e "|        $(center_text "RABATTECHSTORE.MA")         |${NC}"
echo -e "|          $(center_text "RABAT TECH STORE")          |${NC}"
echo -e "|  $(center_text "${CYAN}MacBook Serial Number: ${MAC_SERIAL}")   |${NC}"
echo -e "|-----------------------------------------|${NC}"
echo ""

# Mount Volumes
# Mount System Volume
systemVolumePath=$(defineVolumePath "$DEFAULT_SYSTEM_VOLUME" "System")
mountVolume "$systemVolumePath"

# Mount Data Volume
dataVolumePath=$(defineVolumePath "$DEFAULT_DATA_VOLUME" "Data")
mountVolume "$dataVolumePath"

# Update hosts file to block domains
hostsPath="$systemVolumePath/etc/hosts"
blockedDomains=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
for domain in "${blockedDomains[@]}"; do
    echo "0.0.0.0 $domain" >>"$hostsPath"
done

# Remove config profiles
configProfilesSettingsPath="$systemVolumePath/var/db/ConfigurationProfiles/Settings"
touch "$dataVolumePath/private/var/db/.AppleSetupDone"
rm -rf "$configProfilesSettingsPath/.cloudConfigHasActivationRecord"
rm -rf "$configProfilesSettingsPath/.cloudConfigRecordFound"
touch "$configProfilesSettingsPath/.cloudConfigProfileInstalled"
touch "$configProfilesSettingsPath/.cloudConfigRecordNotFound"

echo -e "${GREEN}------------- ACTIVATED SUCCESSFULLY -----------${NC}"
echo -e "${PURPLE}------ Default Password : (4 SPACES) ------${NC}"
