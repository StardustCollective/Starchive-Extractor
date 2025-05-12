#!/bin/bash

path=""
network_choice=""
delete_snapshots=false
overwrite_snapshots=false
dash_0=false
datetime=false
delete_snapshot_ts=""

IS_T3_MODE=false
export IS_T3_MODE

T3_SUCCESS=true
export T3_SUCCESS

T3_EXTRACTED_COUNT=0
T3_SKIPPED_COUNT=0
export T3_EXTRACTED_COUNT
export T3_SKIPPED_COUNT

RED='\033[0;31m'
LRED='\033[0;91m'
PINK='\033[0;95m'
GREEN='\033[0;32m'
LGREEN='\033[0;92m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
LBLUE='\033[0;94m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LCYAN='\033[0;96m'
GRAY='\033[0;90m'
LGRAY='\033[0;97m'
WHITE='\033[0;37m'
BOLD='\033[1m'

BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

UNDERLINE='\033[4m'
NC='\033[0m' # No Color

talk() {
    local message="$1"
    local color="$2"
    local log_file="${HOME}/starchiver.log"

    echo -e "${color}${message}${NC}"

    local plain_message=$(echo -e "$message" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $plain_message" >> "$log_file"
}

install_tools() {
    if ! command -v tar &> /dev/null; then
        talk "tar could not be found, installing..." $GREEN
        sudo apt-get install -y tar
    fi

    if ! command -v sha256sum &> /dev/null; then
        talk "sha256sum could not be found, installing..." $GREEN
        sudo apt-get install -y coreutils
    fi

    if ! command -v pv &> /dev/null; then
        talk "pv could not be found, installing..." $GREEN
        sudo apt-get install -y pv
    fi
}

set_hash_url() {
    local hashurl=""
    case $network_choice in
        mainnet)
            hashurl="http://128.140.33.142:7777/hash.txt"
            ;;
        integrationnet)
            hashurl="http://5.161.243.241:7777/hash.txt"
            ;;
        testnet)
            hashurl="http://65.108.87.84:7777/hash.txt"
            ;;
        *)
            talk "Invalid network choice: $network_choice" $LRED
            exit 1
            ;;
    esac
    echo "$hashurl"
}

T3_map_datetime_to_ordinal() {
    local datetime_str="$1"
    local network="$2"

    local date_part="${datetime_str%%.*}"
    local hour_part="${datetime_str##*.}"
    local formatted_ts="${date_part}T${hour_part}:00:00Z"

    local api_url="https://be-${network}.constellationnetwork.io/global-snapshots"
    talk "Querying block explorer for ordinal before datetime: $formatted_ts" $CYAN

    local query_url="${api_url}?limit=1&endTimestamp=${formatted_ts}&sort=desc"
    talk "Query URL: $query_url" $LGRAY

    local result
    result=$(curl -s "$query_url")

    if [[ -z "$result" || "$result" == "null" || "$result" == "[]" ]]; then
        talk "[FAIL] No data from block explorer for timestamp: $formatted_ts" $LRED
        echo "-1"
        return
    fi

    talk "Block explorer result: $result" $LGRAY

    local ordinal
    ordinal=$(echo "$result" | grep -o '"ordinal":[0-9]*' | head -n1 | cut -d':' -f2)

    if [[ "$ordinal" =~ ^[0-9]+$ ]]; then
        talk "[OK] Mapped datetime $datetime_str to ordinal $ordinal" $GREEN
        echo "$ordinal"
    else
        talk "[FAIL] Could not extract ordinal from block explorer result" $LRED
        echo "-1"
    fi
}

download_verify_extract_tar() {
    > "${HOME}/starchiver.log"
    local hash_url_base=$1
    local extraction_path=$2
    local start_line=${3:-1}
    local hash_file_path="${HOME}/hash_file.txt"
    local extracted_hashes_log="${HOME}/extracted_hashes.log"

    sudo -v

    echo ""
    talk "Downloading the hash file from:" $BOLD
    talk "$hash_url_base" $LGRAY
    if ! wget -q -nv -O "$hash_file_path" "$hash_url_base"; then
        talk "Error downloading the hash file from $hash_url_base" $LRED
        exit 1
    fi

    T3_detect_archive_format "$hash_file_path"

    if [[ "$IS_T3_MODE" == true ]]; then
        T3_parse_hash_entries "$hash_file_path"
        talk "Total Starchiver sets available = ${#parsed_start_ordinals[@]}" $GREEN

        # if [[ "$delete_snapshots" == true && "$snapshot_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.[0-9]{2}$ ]]; then
        #     resolved_ordinal=$(T3_map_datetime_to_ordinal "$snapshot_time" "$network_choice")
        #     if [[ "$resolved_ordinal" =~ ^[0-9]+$ ]]; then
        #         snapshot_time="$resolved_ordinal"
        #         talk "[OK] Mapped --datetime to ordinal $snapshot_time for deletion." $CYAN
        #     else
        #         talk "[FAIL] Could not resolve ordinal from datetime for deletion. Skipping -d." $LRED
        #         delete_snapshots=false
        #     fi
        # fi

        if [[ -s "$extracted_hashes_log" ]]; then
            echo ""
            talk "Unfinished Starchiver run detected:" $YELLOW
            while true; do
                read -p "Do you want to resume where you left off or start fresh? [r/f]: " resume_choice
                case $resume_choice in
                    [Rr]* )
                        talk "Resuming from previous extraction state..." $GREEN
                        break
                        ;;
                    [Ff]* )
                        talk "Starting fresh. Removing previous extraction log..." $CYAN
                        rm -f "$extracted_hashes_log"
                        break
                        ;;
                    * )
                        talk "Please answer 'r' to resume or 'f' to start fresh." $LRED
                        ;;
                esac
            done
        elif [[ -f "$extracted_hashes_log" ]]; then
            rm -f "$extracted_hashes_log"
        fi

        if [[ "$datetime" == "true" && ! "$snapshot_time" =~ ^[0-9]+$ ]]; then
            talk "Detecting latest local snapshot..." $GREEN
            local latest_ord=$(find "$extraction_path/incremental_snapshot/ordinal" -type f -regex '.*/[0-9]+$' -printf '%f\n' | sort -n | tail -n1)
            if [[ -n "$latest_ord" ]]; then
                talk "Latest snapshot detected: $latest_ord" $GREEN
                snapshot_time="$latest_ord"
            else
                talk "[FAIL] Could not detect latest snapshot. Exiting." $LRED
                exit 1
            fi
        fi

        local start_index=0
        if [[ "$datetime" == "true" ]]; then
            if [[ "$snapshot_time" =~ ^[0-9]+$ ]]; then
                # talk "[DEBUG] snapshot_time = $snapshot_time" $YELLOW
                # talk "[DEBUG] parsed_start_ordinals = ${parsed_start_ordinals[*]}" $YELLOW
                # talk "[DEBUG] parsed_counts = ${parsed_counts[*]}" $YELLOW

                local matched=false
                for ((i = 0; i < ${#parsed_start_ordinals[@]}; i++)); do
                    local start=${parsed_start_ordinals[$i]}
                    local count=${parsed_counts[$i]}
                    local end=$((start + count))

                    # talk "[DEBUG] Checking set $i: start=$start, end=$end" $LGRAY

                    if (( start <= snapshot_time && snapshot_time < end )); then
                        start_index=$i
                        talk "[OK] Using provided snapshot $snapshot_time, resolved to start_index $start_index (Ordinal Set: $start)" $GREEN
                        matched=true
                        break
                    fi
                done

                if [[ "$matched" == false ]]; then
                    talk "Ordinal $snapshot_time is newer than the latest set. No need to Starchive at this time." $LCYAN
                    # talk "[SKIP] Exiting early — no archive set contains ordinal $snapshot_time" $LGRAY
                    return
                fi
            else
                # talk "[DEBUG] Resolving start index from datetime string: $snapshot_time" $YELLOW
                start_index=$(T3_resolve_start_index_from_datetime "$snapshot_time" "$extraction_path" "$network_choice" | grep -E '^[0-9]+$' | head -n1)
                if [[ "$start_index" =~ ^[0-9]+$ ]]; then
                    talk "T3 Mode: Starting Starchiver from ordinal set index $start_index (Ordinal: ${parsed_start_ordinals[$start_index]})" $GREEN
                else
                    talk "[FAIL] Invalid start index: $start_index" $LRED
                    return
                fi
            fi
        else
            talk "T3 Mode: Performing a full Starchiver refresh of all snapshots." $GREEN
        fi

        T3_extract_snapshot_sets "$extraction_path" "$hash_file_path" "$hash_url_base" "$start_index" "$snapshot_time"

        if [[ "$T3_SUCCESS" == true ]]; then
            if [[ "$T3_EXTRACTED_COUNT" -eq 0 && "$T3_SKIPPED_COUNT" -gt 0 ]]; then
                talk "All ordinal sets were already complete. No extraction needed." $LGREEN
            fi
            talk "Cleaning up temp files..." $LGRAY
            rm -f "$hash_file_path"
            rm -f "$extracted_hashes_log"
        else
            talk "One or more sets failed. Keeping hash_file.txt and extracted_hashes.log for resume." $YELLOW
        fi

        show_completion_footer
        exit 0
    else
        talk "Using ${BOLD}Tessellation v2${NC} archive extraction logic." $BLUE

        if [[ "$datetime" == "true" ]]; then
            if [[ -z "$snapshot_time" ]]; then
                echo "Find the latest snapshot file"
                latest_snapshot=$(find "${extraction_path}" -type f -regex '.*/[0-9]+$' -printf '%T+ %p\n' | sort -r | head -n1 | cut -d" " -f2)
                if [[ -n "$latest_snapshot" ]]; then
                    snapshot_time=$(date -d "$(stat -c %y "$latest_snapshot")" -1 hour "+%Y-%m-%d.%H")
                    echo "The adjusted snapshot time is $snapshot_time"
                else
                    echo "No valid snapshot found."
                    exit 1
                fi
            fi
            list_starchive_containers "$snapshot_time" "$extraction_path"
            exit 0
        fi
    fi

    if [ -z "$(ls -A "$extraction_path")" ]; then
        talk "No existing snapshots found. Performing full extraction." $LGREEN
        start_line=1
    else
        if find "$extraction_path" -type f -size +0c -print -quit | grep -q .; then
            cleanup_snapshots "$extraction_path"
        fi
    fi

    local total_files=$(wc -l < "$hash_file_path")
    local current_file=$((start_line - 1))
    local file_counter=$start_line

    tail -n +$start_line "$hash_file_path" | while IFS= read -r line; do
        current_file=$((current_file + 1))
        local file_hash=$(echo $line | awk '{print $1}')
        local tar_file_name=$(echo $line | awk '{print $2}')
        local tar_file_path="${HOME}/${tar_file_name}"
        local tar_url="${hash_url_base%/*}/$tar_file_name"
        local download_directory
        download_directory=$(dirname "$tar_file_path")

        echo ""
        if grep -q "$file_hash" "$extracted_hashes_log"; then
            talk "${BOLD}Processing Starchive $file_counter of $total_files:${NC} ${BOLD}${LCYAN}$tar_file_name${NC}"
            talk "Starchive has already been extracted successfully. Skipping." $LGREEN
            echo "$file_hash"
            file_counter=$((file_counter + 1))
            continue
        fi

        talk "${BOLD}Processing Starchive $file_counter of $total_files:${NC} ${BOLD}${LCYAN}$tar_file_name${NC}"

        if [ -f "$tar_file_path" ]; then
            talk "Starchive already exists. Verifying SHA256 Hash..." $LGRAY
            local calculated_hash
            calculated_hash=$(pv "$tar_file_path" | sha256sum | awk '{print $1}')
            if [ "$calculated_hash" = "$file_hash" ]; then
                talk "Hash matches. Using the existing Starchive." $LGREEN
                echo "Calculated hash: $calculated_hash"
            else
                talk "Hash mismatch. Redownloading..." $LRED
                rm -f "$tar_file_path"
                if ! check_space_for_download "$tar_url" "$download_directory"; then
                    talk "Insufficient disk space for downloading $tar_file_name. Exiting script." $LRED
                    exit 1
                fi
                if ! wget -q --show-progress -O "$tar_file_path" "$tar_url"; then
                    talk "Error redownloading $tar_file_name. Aborting." $LRED
                    exit 1
                else
                    talk "Verifying SHA256 Hash..." $LGRAY
                    calculated_hash=$(pv "$tar_file_path" | sha256sum | awk '{print $1}')
                    if [ "$calculated_hash" != "$file_hash" ]; then
                        talk "Hash mismatch. Error downloading $tar_file_name. Aborting." $LRED
                        exit 1
                    else
                        talk "Hash verified successfully" $LGREEN
                    fi
                fi
            fi
        else
            if ! check_space_for_download "$tar_url" "$download_directory"; then
                talk "Insufficient disk space for downloading $tar_file_name. Exiting script." $LRED
                exit 1
            fi
            talk "Downloading $tar_file_name" $GREEN
            if ! wget -q --show-progress -O "$tar_file_path" "$tar_url"; then
                talk "Error downloading $tar_file_name. Aborting." $LRED
                exit 1
            else
                talk "Verifying SHA256 Hash..." $LGRAY
                local calculated_hash
                calculated_hash=$(pv "$tar_file_path" | sha256sum | awk '{print $1}')
                if [ "$calculated_hash" != "$file_hash" ]; then
                    talk "Hash mismatch. Error downloading $tar_file_name. Aborting." $LRED
                    exit 1
                else
                    talk "Hash verified successfully" $LGREEN
                fi
            fi
        fi

        talk "Extracting Starchive:" $BOLD
        sudo pv "$tar_file_path" | sudo tar --overwrite -xzf - -C "$extraction_path"
        echo -e "\n${BOLD}$file_counter of $total_files Starchives extracted successfully.${NC}"

        echo "$file_hash" >> "$extracted_hashes_log"
        rm -f "$tar_file_path"
        file_counter=$((file_counter + 1))
    done
}

list_starchive_containers() {
    local snapshot_time="$1"  # Format: YYYY-MM-DD.HH
    local data_path="$2"
    local hash_url_base=$(set_hash_url)
    local hash_file_path="${HOME}/hash_file.txt"

    echo "Downloading the hash file from: $hash_url_base"
    if ! wget -q -O "$hash_file_path" "$hash_url_base"; then
        echo "Failed to download or found empty hash file. Exiting."
        return 1
    fi

    local year=$(echo $snapshot_time | cut -d'-' -f1)
    local month=$(echo $snapshot_time | cut -d'-' -f2 | sed 's/^0*//')
    local day=$(echo $snapshot_time | cut -d'-' -f3 | cut -d'.' -f1 | sed 's/^0*//')
    local hour=$(echo $snapshot_time | cut -d'.' -f2 | sed 's/^0*//')
    local found=false
    local start_line_number=0
    local patterns=()

    echo "Searching archives starting from: $snapshot_time"

    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day).$(printf "%02d" $hour).tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day).$(printf "%02d" $hour)_part_1.tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day).00.tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day).00_part_1.tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day).tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)-$(printf "%02d" $day)_part_1.tar.gz")
    patterns+=("${year}-$(printf "%02d" $month).tar.gz")
    patterns+=("${year}-$(printf "%02d" $month)_part_1.tar.gz")
    patterns+=("${year}.tar.gz")
    patterns+=("${year}_part_1.tar.gz")

    for pattern in "${patterns[@]}"; do
        local result=$(grep -n "$pattern" "$hash_file_path")
        if [[ ! -z "$result" ]]; then
            start_line_number=$(echo "$result" | cut -d: -f1 | head -n 1)
            local archive_name=$(echo "$result" | awk '{print $2}')
            found=true
            echo "Matched Found: $archive_name on line $start_line_number"

            formatted_month=$(printf "%02d" "$month")
            formatted_day=$(printf "%02d" "$day")
            if [ -z "$hour" ]; then
                hour="00"
            fi
            formatted_hour=$(printf "%02d" "$hour")
            delete_snapshot_ts=$(date -d "$year-$formatted_month-$formatted_day $formatted_hour:00:00" '+%s')

            break
        fi
    done

    if [ "$found" == true ]; then
        if [ "$dash_o" == true ]; then
            delete_snapshots=false
            overwrite_snapshots=true
        else
            delete_snapshots=true
            overwrite_snapshots=false
        fi
        download_verify_extract_tar "$hash_url_base" "$data_path" "$start_line_number"
    else
        echo "No matching Starchive containers found for time: $snapshot_time"
    fi
}

convert_to_human_readable() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes} bytes"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(bc <<< "scale=3; $bytes/1024") KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(bc <<< "scale=3; $bytes/1048576") MB"
    else
        echo "$(bc <<< "scale=3; $bytes/1073741824") GB"
    fi
}

check_space_for_download() {
    local url=$1
    local download_path=$2

    local file_size=$(curl -sI "$url" | grep -i "Content-Length" | awk '{print $2}' | tr -d '\r')
    local human_readable_file_size=$(convert_to_human_readable $file_size)
    echo "File size to download: $human_readable_file_size"

    local avail_space=$(df --output=avail -B1 "$download_path" | tail -n1)
    local human_readable_avail_space=$(convert_to_human_readable $avail_space)
    echo "Available space in $download_path: $human_readable_avail_space"

    if [[ $avail_space -lt $file_size ]]; then
        echo "Insufficient disk space."
        return 1
    else
        return 0
    fi
}

search_data_folders() {
    local temp_file="/tmp/data_folders_with_snapshot.txt"
    echo "Searching for snapshot data folders..." >&2
    find / -maxdepth 5 -type d -name "snapshot" -path "*/data/snapshot" -printf '%h\n' 2>/dev/null > "$temp_file"

    if [ ! -s "$temp_file" ]; then
        echo "No 'data' folders with 'snapshot' found." >&2
        rm -f "$temp_file"
        return 1
    else
        echo "" >&2
        echo "Select a snapshot data folder path:" >&2
        cat "$temp_file" | nl -w2 -s') ' >&2
        echo "  0) Enter path manually" >&2
        echo ""
        echo "Make a selection:" >&2

        read -r selection >&2

        if [[ $selection =~ ^[0-9]+$ ]]; then
            if [ "$selection" -eq 0 ]; then
                read -r -p "Enter the path of the data folder: " directory >&2
                directory=$(echo "$directory" | xargs)
                echo "$directory"
            elif [ -s "$temp_file" ] && [ "$selection" -gt 0 ] && [ "$selection" -le $(wc -l < "$temp_file") ]; then
                local selected_folder=$(sed "${selection}q;d" "$temp_file" | tr -d '\n')
                echo "$selected_folder"
            else
                echo "Invalid selection." >&2
                return 1
            fi
        else
            echo "No selection made or invalid input." >&2
            return 1
        fi

        rm -f "$temp_file"
    fi
}

cleanup_snapshots() {
    local data_path=$1
    local confirmation
    local final_confirmation
    local extracted_hashes_log="${HOME}/extracted_hashes.log"

    if [[ $delete_snapshots == true && -n "$delete_snapshot_ts" ]]; then
        talk "Deleting snapshots from $(date -d "@$delete_snapshot_ts") and newer in $data_path" $CYAN

        tmpfile=$(mktemp)
        sudo find "$data_path" -type f -printf '%T@ %p\n' | \
        awk -v ts="$delete_snapshot_ts" '$1 >= ts {print $2}' > "$tmpfile"
        total=$(wc -l < "$tmpfile")
        talk "Found $total files to delete." $CYAN

        cat "$tmpfile" | pv -l -s "$total" | sudo xargs -r rm 2>/dev/null
        rm "$tmpfile"

        talk "Snapshot deletion based on timestamp completed." $GREEN$BOLD
        return
    elif [[ $delete_snapshots == true ]]; then
        talk "Deleting all snapshots in ${data_path}" $CYAN

        tmpfile=$(mktemp)
        sudo find "$data_path" -type f > "$tmpfile"
        total=$(wc -l < "$tmpfile")
        talk "Found $total files to delete." $CYAN
        cat "$tmpfile" | pv -l -s "$total" | sudo xargs -r rm
        rm "$tmpfile"

        talk "Snapshot deletion completed." $GREEN$BOLD
        return
    fi

    if [[ $delete_snapshots == true ]]; then
        if [ -f "$hash_file_path" ]; then
            if [ -f "$extracted_hashes_log" ]; then
                talk "Removing extracted_hashes.log file."
                rm -f "$extracted_hashes_log"
            fi
        fi
        talk "Snapshot deletion completed." $GREEN
        return
    fi

    if [[ $overwrite_snapshots == true ]]; then
        talk "Overwriting snapshots in ${data_path}" $GREEN$BOLD
        return
    fi

    while true; do
        echo ""
        talk "Do you want to clean up and delete existing snapshots? (d/o/c)" $CYAN$BOLD
        talk "  (${data_path})" $BOLD
        echo ""
        talk "    Answering 'D' will delete all snapshots."
        talk "    Answering 'O' will overwrite all snapshots."
        talk "    Answering 'C' will cancel and exit."
        read -r confirmation

        case $confirmation in
            [Dd])
                while true; do
                    echo ""
                    talk "Type '${CYAN}YES${NC}' (in all CAPS) to confirm deletion, or type 'C' to cancel:" $BOLD
                    talk "   (${data_path})" $BOLD
                    read -r final_confirmation
                    case $final_confirmation in
                        YES)
                            talk "Deleting snapshots, Please wait..." $GREEN
                            for folder in "${data_path}"/*; do
                                if [ -d "$folder" ]; then
                                    owner=$(stat -c %U "$folder")
                                    group=$(stat -c %G "$folder")
                                    perms=$(stat -c %a "$folder")
                                    talk "Processing folder: $folder" $CYAN
                                    sudo rm -rf "$folder"
                                    mkdir -p "$folder"
                                    sudo chown "$owner:$group" "$folder"
                                    sudo chmod "$perms" "$folder"
                                fi
                            done
                            talk "Snapshot folder cleanup completed." $GREEN
                            if [ -f "$extracted_hashes_log" ]; then
                                talk "Obsolete extracted_hashes.log deleted." $GREEN
                                rm -f "$extracted_hashes_log"
                            fi
                            break 2
                            ;;
                        [Cc])
                            talk "Operation cancelled." $RED
                            break 2
                            ;;
                        *)
                            talk "Invalid option. Please type 'YES' to confirm or 'C' to cancel." $RED
                            ;;
                    esac
                done
                ;;
            [Oo])
                while true; do
                    echo ""
                    talk "Type '${CYAN}YES${NC}' (in all CAPS) to confirm overwriting, or type 'C' to cancel:" $BOLD
                    talk "   (${data_path})" $BOLD
                    read -r final_confirmation
                    case $final_confirmation in
                        YES)
                            talk "Proceeding to overwrite snapshots." $GREEN
                            break 2
                            ;;
                        [Cc])
                            talk "Operation cancelled." $RED
                            break 2
                            ;;
                        *)
                            talk "Invalid option. Please type 'YES' to confirm or 'C' to cancel." $RED
                            ;;
                    esac
                done
                ;;
            [Cc])
                talk "Operation cancelled. Exiting." $RED
                exit 0
                ;;
            *)
                talk "Incorrect choice. Please try again." $RED
                ;;
        esac
    done
}

show_completion_footer() {
    echo ""
    talk "---==[ STARCHIVER ]==---" $BOLD$LGREEN
    talk "Create and Restore Starchive files." $LGREEN
    echo ""
    talk "Don't forget to tip the bar tender!" $BOLD$YELLOW
    talk "  ${BOLD}This script was written by:${NC} ${BOLD}${LGREEN}@Proph151Music${NC}"
    talk "     ${BOLD}for the ${LBLUE}Constellation Network${NC} ${BOLD}ecosystem.${NC}"
    echo ""
    talk "  DAG Wallet Address for sending tips can be found here..." $YELLOW
    talk "     ${BOLD}DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3${NC}"
    echo ""
}

main_menu() {
    while true; do
        clear
        echo ""
        echo ""
        talk "Don't forget to tip the bar tender!" $BOLD$YELLOW
        talk "  ${BOLD}This script was written by:${NC} ${BOLD}${LGREEN}@Proph151Music${NC}"
        talk "     ${BOLD}for the ${LBLUE}Constellation Network${NC} ${BOLD}ecosystem.${NC}"
        echo ""
        talk "  DAG Wallet Address for sending tips can be found here..." $YELLOW
        talk "     ${BOLD}DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3${NC}"
        echo ""
        talk "---==[ STARCHIVER ]==---" $BOLD$LGREEN
        talk "Create and Restore Starchive files." $LGREEN
        echo ""
        talk "Select a network:"
        talk "${BOLD}M)${NC} ${BOLD}${LCYAN}MainNet${NC}"
        talk "${BOLD}I)${NC} ${BOLD}${LCYAN}IntegrationNet${NC}"
        talk "${BOLD}T)${NC} ${BOLD}${LCYAN}TestNet${NC}"
        talk "${BOLD}C)${NC} ${BOLD}${LCYAN}Custom${NC}"
        talk "${BOLD}Q)${NC} ${BOLD}${LCYAN}Quit${NC}"
        echo ""
        read -p "$(echo -e ${BOLD}Choose your adventure${NC} [M, I, T, C, Q]:) " network_choice
        echo ""

        case $network_choice in
            [Mm])
                path=$(search_data_folders | xargs)
                if [ $? -eq 1 ] || [ -z "$path" ]; then
                    talk "No valid data folder with snapshot selected. Exiting." $LRED
                    exit 1
                fi
                hashurl="http://128.140.33.142:7777/hash.txt"
                download_verify_extract_tar "$hashurl" "$path"
                ;;
            [Ii])
                path=$(search_data_folders | xargs)
                if [ $? -eq 1 ] || [ -z "$path" ]; then
                    talk "No valid data folder with snapshot selected. Exiting." $LRED
                    exit 1
                fi
                hashurl="http://5.161.243.241:7777/hash.txt"
                download_verify_extract_tar "$hashurl" "$path"
                ;;
            [Tt])
                path=$(search_data_folders | xargs)
                if [ $? -eq 1 ] || [ -z "$path" ]; then
                    talk "No valid data folder with snapshot selected. Exiting." $LRED
                    exit 1
                fi
                hashurl="http://65.108.87.84:7777/hash.txt"
                download_verify_extract_tar "$hashurl" "$path"
                ;;
            [Cc])
                path=$(search_data_folders | xargs)
                if [ $? -eq 1 ] || [ -z "$path" ]; then
                    talk "No valid data folder with snapshot selected. Exiting." $LRED
                    exit 1
                fi
                read -p "Enter the URL of the Hash file: " hashurl
                download_verify_extract_tar "$hashurl" "$path"
                ;;
            [Qq])
                exit 0
                ;;
            *)
                talk "Invalid choice, please choose again." $LRED
                ;;
        esac
    done
}

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --datetime)
                datetime=true
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "No specific time given for --datetime, will calculate based on latest snapshot."
                else
                    shift
                    echo "Processing --datetime with value: $1"
                    local input="$1"

                    if [[ "$input" =~ ^[0-9]+$ ]]; then
                        snapshot_time="$input"
                    elif [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.[0-9]{2}$ ]]; then
                        snapshot_time="$input"
                        if [[ "$delete_snapshots" == true || "$overwrite_snapshots" == true ]]; then
                            resolved_ordinal=$(T3_map_datetime_to_ordinal "$snapshot_time" "$network_choice")
                            if [[ "$resolved_ordinal" =~ ^[0-9]+$ ]]; then
                                snapshot_time="$resolved_ordinal"
                                talk "[OK] Mapped --datetime to ordinal $snapshot_time for deletion." $CYAN
                            else
                                talk "[FAIL] Could not resolve ordinal from datetime for deletion. Skipping -d." $LRED
                                delete_snapshots=false
                            fi
                        fi
                    elif [[ "$input" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]?[zZ]([0-9]{1,2})([0-9]{2})$ ]]; then
                        local date_part="${BASH_REMATCH[1]}"
                        local hour=$(printf "%02d" "${BASH_REMATCH[2]}")
                        snapshot_time="${date_part}.${hour}"
                    else
                        echo "Invalid --datetime value: $1. Use an ordinal number or format YYYY-MM-DD.HH"
                        exit 1
                    fi
                fi
                ;;
            --data-path|--data_path)
                shift
                path="$1"
                ;;
            --cluster)
                shift
                network_choice="${1,,}"
                ;;
            -d)
                delete_snapshots=true
                ;;
            -o)
                overwrite_snapshots=true
                dash_o=true
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done
}

T3_detect_archive_format() {
    local hash_file_path="$1"
    IS_T3_MODE=false

    if grep -qE -- '-s[0-9]+-c[0-9]+(\.tar\.gz)?' "$hash_file_path"; then
        IS_T3_MODE=true
        talk "Detected Tessellation v3 archive format in hash file." $GREEN
    else
        talk "Detected Tessellation v2 archive format in hash file." $BLUE
    fi
}

T3_parse_hash_entries() {
    local hash_file_path="$1"
    parsed_start_ordinals=()
    parsed_counts=()
    parsed_filenames=()

    while IFS= read -r line; do
        local hash=$(echo "$line" | awk '{print $1}')
        local fname=$(echo "$line" | awk '{print $2}')
        if [[ "$fname" =~ -s([0-9]+)-c([0-9]+)(-e([0-9]+))?\.tar\.gz$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local count="${BASH_REMATCH[2]}"
            local end="${BASH_REMATCH[4]}"
            if [ -z "$end" ]; then
                end=$((start + count - 1))
            fi
            parsed_start_ordinals+=("$start")
            parsed_counts+=("$count")
            parsed_filenames+=("$fname")
        fi
    done < "$hash_file_path"
}

T3_resolve_start_index_from_datetime() {
    local snapshot_time="$1"
    local snapshot_dir="$2"
    local network="$3"

    local formatted_input_ts=""
    local api_url="https://be-${network}.constellationnetwork.io/global-snapshots"
    local total_sets="${#parsed_start_ordinals[@]}"

    if [[ "$snapshot_time" =~ ^[0-9]+$ ]]; then
        formatted_input_ts=$(date -u -d "@$snapshot_time" "+%Y-%m-%dT%H:%M:%SZ")
    elif [[ "$snapshot_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.[0-9]{2}$ ]]; then
        formatted_input_ts="${snapshot_time/./T}:00:00Z"
    elif [[ "$snapshot_time" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
        formatted_input_ts="${snapshot_time}-01T00:00:00Z"
    else
        talk "[FAIL] Invalid --datetime format: $snapshot_time" $LRED
        echo 0
        return
    fi

    talk "Looking for ordinal set with timestamp ≤ $formatted_input_ts" $CYAN

    for ((i = total_sets - 1; i >= 0; i--)); do
        local start_ord="${parsed_start_ordinals[$i]}"
        local test_ord="$start_ord"
        if (( i == 0 )); then
            test_ord=$((start_ord + 1))
        fi

        local response
        response=$(curl -s --max-time 4 "${api_url}/${test_ord}")

        if [[ -z "$response" || "$response" == "null" || "$response" =~ "504 Gateway" ]]; then
            talk "[WARN] No response for ordinal $test_ord — skipping" $YELLOW
            continue
        fi

        local ts
        ts=$(echo "$response" | sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p')

        if [[ -z "$ts" ]]; then
            talk "[WARN] No timestamp in response for ordinal $test_ord — skipping" $YELLOW
            continue
        fi

        local input_epoch
        input_epoch=$(date -u -d "$formatted_input_ts" +%s 2>/dev/null)
        local ts_epoch
        ts_epoch=$(date -u -d "$ts" +%s 2>/dev/null)

        if [[ -z "$input_epoch" || -z "$ts_epoch" ]]; then
            talk "[FAIL] Could not parse timestamp values: input=$formatted_input_ts, found=$ts" $LRED
            continue
        fi

        if (( ts_epoch <= input_epoch )); then
            talk "[OK] Found ordinal set starting at $start_ord (index $i) with timestamp $ts" $GREEN
            echo "$i"
            return
        else
            printf "\r[SKIP] Ordinal %-10s (ts: %s) > %s\n" "$test_ord" "$ts" "$formatted_input_ts"
        fi
    done

    talk "[WARN] No ordinal set found with timestamp ≤ $formatted_input_ts. Starting from beginning." $YELLOW
    echo 0
}

T3_delete_ordinals_from_ordinal() {
    local snapshot_dir="$1"
    local delete_from_ordinal="$2"

    local base_path="${snapshot_dir}/incremental_snapshot/ordinal"
    local total_sets="${#parsed_start_ordinals[@]}"
    local any_deleted=false

    talk "Deleting snapshots from ordinal $delete_from_ordinal and later..." $YELLOW

    for ((i = 0; i < total_sets; i++)); do
        local start="${parsed_start_ordinals[$i]}"
        local count="${parsed_counts[$i]}"
        local end=$((start + count - 1))

        if (( delete_from_ordinal >= start && delete_from_ordinal <= end )); then
            local target_dir="${base_path}/${start}"
            if [[ -d "$target_dir" ]]; then
                talk "Deleting ordinal set folder: $target_dir" $CYAN
                sudo rm -rf "$target_dir"
                any_deleted=true
            fi
        elif (( start > delete_from_ordinal )); then
            local dir="${base_path}/${start}"
            if [[ -d "$dir" ]]; then
                talk "Deleting ordinal set folder: $dir" $CYAN
                sudo rm -rf "$dir"
                any_deleted=true
            fi
        fi
    done

    if [[ "$any_deleted" == true ]]; then
        talk "Snapshot deletion complete for ordinals ≥ $delete_from_ordinal." $LGREEN
    else
        talk "No matching ordinal files or sets found to delete from $delete_from_ordinal." $LGRAY
    fi
}

T3_extract_snapshot_sets() {
    local extraction_path="$1"
    local hash_file_path="$2"
    local hash_url_base="$3"
    local start_index="$4"
    local snapshot_time="$5"

    T3_SUCCESS=true
    T3_SKIPPED_COUNT=0
    T3_EXTRACTED_COUNT=0

    if [[ "$delete_snapshots" == true && "$start_index" =~ ^[0-9]+$ ]]; then
        local delete_ordinal="${parsed_start_ordinals[$start_index]}"
        # talk "[DEBUG] Deleting from resolved start ordinal $delete_ordinal (index $start_index)" $YELLOW
        T3_delete_ordinals_from_ordinal "$extraction_path" "$delete_ordinal"
    fi

    local extracted_hashes_log="${HOME}/extracted_hashes.log"
    [ ! -f "$extracted_hashes_log" ] && touch "$extracted_hashes_log"

    local total_sets="${#parsed_filenames[@]}"
    local skipped_count=0
    local extracted_count=0

    for ((i = start_index; i < total_sets; i++)); do
        local fname="${parsed_filenames[$i]}"
        local start="${parsed_start_ordinals[$i]}"
        local count="${parsed_counts[$i]}"
        local tar_file_path="${HOME}/${fname}"
        local tar_url="${hash_url_base%/*}/$fname"

        local local_ordinal_dir="${extraction_path}/incremental_snapshot/ordinal/${start}"
        local existing_count=0
        if [[ -d "$local_ordinal_dir" ]]; then
            existing_count=$(find "$local_ordinal_dir" -type f | wc -l)
        fi

        echo ""
        local relative_index=$((i - start_index + 1))
        talk "${BOLD}${BG_GREEN}Processing Ordinal Set $start ($relative_index of $((total_sets - start_index)))${NC}" $WHITE

        if (( existing_count >= count )); then
            talk "[OK] Set already complete (${existing_count}/${count}). Skipping." $GREEN
             T3_SKIPPED_COUNT=$((T3_SKIPPED_COUNT + 1))
            continue
        fi

        local expected_hash=$(grep " $fname" "$hash_file_path" | awk '{print $1}')
        if grep -q "$expected_hash" "$extracted_hashes_log"; then
            talk "[OK] Archive already logged as extracted. Skipping: $fname" $GREEN
             T3_SKIPPED_COUNT=$((T3_SKIPPED_COUNT + 1))
            continue
        fi

        if [ ! -f "$tar_file_path" ]; then
            # talk "Checking storage before downloading $fname..." $LGRAY
            if ! check_space_for_download "$tar_url" "$(dirname "$tar_file_path")"; then
                talk "${BOLD}[FAIL]${NC} Insufficient disk space for $fname. Aborting extraction." $LRED
                T3_SUCCESS=false
                return 1
            fi

            talk "Downloading $fname..." $GREEN
            if ! wget -q --show-progress -O "$tar_file_path" "$tar_url"; then
                talk "[FAIL] Failed to download $fname" $LRED
                T3_SUCCESS=false
                return 1
            fi
        fi

        talk "Validating SHA256 hash..." $LGRAY
        local actual_hash=$(sha256sum "$tar_file_path" | awk '{print $1}')
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            talk "[FAIL] Hash mismatch. Removing bad file and retrying..." $LRED
            rm -f "$tar_file_path"

            talk "Re-downloading $fname..." $GREEN
            if ! check_space_for_download "$tar_url" "$(dirname "$tar_file_path")"; then
                talk "${BOLD}[FAIL]${NC} Insufficient disk space for retry of $fname. Aborting extraction." $LRED
                T3_SUCCESS=false
                return 1
            fi
            if ! wget -q --show-progress -O "$tar_file_path" "$tar_url"; then
                talk "${BOLD}[FAIL]${NC} Retry download failed: $fname" $LRED
                T3_SUCCESS=false
                return 1
            fi

            talk "Re-validating SHA256 hash..." $LGRAY
            actual_hash=$(sha256sum "$tar_file_path" | awk '{print $1}')
            if [[ "$actual_hash" != "$expected_hash" ]]; then
                talk "${BOLD}[CRITICAL ERROR]${NC} Retry failed: hash still mismatched for $fname" $LRED
                talk "${BOLD}[ACTION REQUIRED]${NC} Alert a Team Lead. Snapshots are incomplete." $LRED
                T3_SUCCESS=false
                return 1
            else
                talk "${BOLD}Hash verified.${NC}" $GREEN
            fi
        else
            talk "${BOLD}Hash verified.${NC}" $GREEN
        fi

        talk "Extracting $fname..." $BLUE
        sudo pv "$tar_file_path" | sudo tar --overwrite -xzf - -C "$extraction_path"
        if [ $? -eq 0 ]; then
            if [[ ! -f "$extracted_hashes_log" ]]; then
                touch "$extracted_hashes_log"
            fi
            echo "$expected_hash" >> "$extracted_hashes_log"
            talk "[OK] Extracted successfully: $fname" $GREEN
            rm -f "$tar_file_path"
            T3_EXTRACTED_COUNT=$((T3_EXTRACTED_COUNT + 1))
        else
            talk "[FAIL] Extraction failed for $fname" $LRED
            T3_SUCCESS=false
        fi
    done

    echo ""
    talk "Summary: [OK] $T3_SKIPPED_COUNT sets skipped | $T3_EXTRACTED_COUNT sets extracted." $LGREEN
}

install_tools

parse_arguments "$@"

if [[ -n "$path" && -n "$network_choice" ]]; then
    if [[ "$network_choice" == "custom" ]]; then
        read -p "Enter the custom URL to your hash.txt file: " hashurl
        read -p "Enter the network name (e.g. mainnet, integrationnet, testnet): " network_input
        network_choice=$(echo "$network_input" | xargs)
    else
        hashurl=$(set_hash_url)
    fi
    download_verify_extract_tar "$hashurl" "$path"
else
    main_menu
fi

