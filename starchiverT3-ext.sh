#!/bin/bash

# exec 2>>"$HOME/starchiver.debug.log"
# set -x
# trap 'echo "ERROR at ${BASH_SOURCE[0]}:${LINENO} — `$BASH_COMMAND`" >>"$HOME/starchiver.debug.log"' ERR

RED='\033[0;31m'
LRED='\033[0;91m'
PINK='\033[0;95m'
GREEN='\033[0;32m'
LGREEN='\033[0;92m'
YELLOW='\033[0;33m'
LYELLOW='\033[1;33m'
BLUE='\033[0;34m'
LBLUE='\033[0;94m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LCYAN='\033[0;96m'
GRAY='\033[0;90m'
LGRAY='\033[0;97m'
WHITE='\033[0;37m'
BOLD='\033[1m'

BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_LGRAY='\033[100m'
BG_WHITE='\033[47m'

# 256 Color foregrounds
FG256_BLACK='\033[38;5;0m'
FG256_MAROON='\033[38;5;1m'
FG256_DARK_GREEN='\033[38;5;22m'
FG256_OLIVE='\033[38;5;58m'
FG256_NAVY='\033[38;5;17m'
FG256_BLUE='\033[38;5;21m'
FG256_SKY_BLUE='\033[38;5;39m'
FG256_TEAL='\033[38;5;30m'
FG256_CYAN='\033[38;5;51m'
FG256_SPRING_GREEN='\033[38;5;82m'
FG256_LIME='\033[38;5;118m'
FG256_YELLOW='\033[38;5;226m'
FG256_ORANGE='\033[38;5;208m'
FG256_RED='\033[38;5;196m'
FG256_DARK_RED='\033[38;5;88m'
FG256_MAGENTA='\033[38;5;201m'
FG256_PURPLE='\033[38;5;93m'
FG256_PINK='\033[38;5;200m'
FG256_GRAY_DARK='\033[38;5;239m'
FG256_GRAY='\033[38;5;245m'
FG256_WHITE='\033[38;5;15m'

# 256-color backgrounds
BG256_BLACK='\033[48;5;0m'
BG256_MAROON='\033[48;5;1m'
BG256_DARK_GREEN='\033[48;5;22m'
BG256_DARK_PURPLE='\033[48;5;54m'
BG256_OLIVE='\033[48;5;58m'
BG256_NAVY='\033[48;5;17m'
BG256_BLUE='\033[48;5;21m'
BG256_SKY_BLUE='\033[48;5;39m'
BG256_TEAL='\033[48;5;30m'
BG256_CYAN='\033[48;5;51m'
BG256_SPRING_GREEN='\033[48;5;82m'
BG256_LIME='\033[48;5;118m'
BG256_YELLOW='\033[48;5;226m'
BG256_ORANGE='\033[48;5;208m'
BG256_RED='\033[48;5;196m'
BG256_DARK_RED='\033[48;5;88m'
BG256_MAGENTA='\033[48;5;201m'
BG256_PURPLE='\033[48;5;93m'
BG256_PINK='\033[48;5;200m'
BG256_GRAY_DARK='\033[48;5;239m'
BG256_GRAY='\033[48;5;245m'
BG256_WHITE='\033[48;5;15m'

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
    if ! command -v tmux &> /dev/null; then
        talk "tmux could not be found, installing..." $GREEN
        sudo apt-get update
        sudo apt-get install -y tmux
    fi
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

    if ! command -v bc &> /dev/null; then
        talk "bc could not be found, installing..." $GREEN
        sudo apt-get install -y bc
    fi
}

install_tools

SCRIPT_REALPATH="$(realpath "$0" 2>/dev/null || echo "$0")"
SCRIPT_SHA256="$(sha256sum "$SCRIPT_REALPATH" 2>/dev/null | awk '{print $1}')"
talk "RUN STAMP: file=$SCRIPT_REALPATH sha256=${SCRIPT_SHA256:-unknown} pid=$$ tty=$(tty 2>/dev/null || echo 'none') tmux=${TMUX:-''}" $LGRAY

SESSION_NAME="Starchiver"

ARGS=("$@")

SOCKET_DIR="$HOME/.tmux"
mkdir -p "$SOCKET_DIR"
SOCKET_PATH="$SOCKET_DIR/${SESSION_NAME}.sock"

TMUX_CMD="tmux -S $SOCKET_PATH"

if [ -z "$TMUX" ] && [[ -t 0 && -t 1 && -t 2 ]]; then
  if $TMUX_CMD has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux set-environment -t "$SESSION_NAME" STARCHIVER_ARGS "${ARGS[*]}"
    exec $TMUX_CMD attach -t "$SESSION_NAME"
  else
    exec $TMUX_CMD new-session \
      -s "$SESSION_NAME" \
      -n starchiver \
      -e STARCHIVER_ARGS="${ARGS[*]}" \
      "$0" "${ARGS[@]}"
  fi
fi

if [[ -t 1 ]]; then
  tmux set -g mouse off
  tmux set-option -g history-limit 1000000

  tmux set-option -g status-style bg=colour17,fg=colour250

  tmux set-window-option -g window-status-format ""
  tmux set-window-option -g window-status-current-format ""

  tmux set-option -g status-left-length  50
  tmux set-option -g status-left        \
    '#[fg=colour118,bold]Starchiver #[fg=colour250]| Detach: CTRL+b then d'

  tmux set-option -g status-right-length  80
  tmux set-option -g status-right         \
    '#[fg=colour118,bold]Proph151Music'"'"'s Tip Jar: #[fg=white,bold]DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3'
fi

CORES=$(nproc)
MAX_CONCURRENT_JOBS=$((CORES * 2))
job_semaphore=0

wait_for_slot() {
  while (( job_semaphore >= MAX_CONCURRENT_JOBS )); do
    wait -n
    (( job_semaphore-- ))
  done
}

script_dir=$(dirname "$(realpath "$0")")

declare MAX_UPLOAD_SIZE_MB=100
HELPER_ARCHIVES_CREATED=0
export HELPER_ARCHIVES_CREATED
declare -A missing_ordinals_by_set=()
CLEANUP_MODE=false
REVERSE_MODE=false
OBSOLETE_DIR="${script_dir}/obsolete_hashes"

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

UPLOAD_TARGET=""

set_hash_url() {
  case $network_choice in
    mainnet)
      echo "http://128.140.33.142:7777/hash.txt"
      ;;
    integrationnet)
      echo "http://5.161.243.241:7777/hash.txt"
      ;;
    testnet)
      echo "http://65.108.87.84:7777/hash.txt"
      ;;
    *)
      talk "Invalid network choice: $network_choice" $LRED
      exit 1
      ;;
  esac
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

    if [[ ! -d "$extraction_path" ]]; then
        talk "Target data path not found: $extraction_path — creating it now..." $YELLOW
        if ! sudo mkdir -p "$extraction_path"; then
            talk "[FAIL] Unable to create $extraction_path" $LRED
            exit 1
        fi
    fi

    export DATA_FOLDER_PATH="$extraction_path"

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
        local __last_idx=$(( ${#parsed_start_ordinals[@]} - 1 ))
        if (( __last_idx >= 0 )); then
            talk "Latest set: file=${parsed_filenames[$__last_idx]} | range=${parsed_start_ordinals[$__last_idx]}..${parsed_end_ordinals[$__last_idx]} | count=${parsed_counts[$__last_idx]}" $LGRAY
        fi

        if [[ -s "$extracted_hashes_log" ]]; then
            echo ""
            talk "Unfinished Starchiver run detected:" $YELLOW
            while true; do
                read -p "Do you want to resume where you left off or start fresh? [r/f]: " resume_choice
                case $resume_choice in
                    [Rr]* )
                        talk "Resuming from previous extraction state..." $GREEN
                        delete_snapshots=false
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
                echo ""
                talk "${YELLOW}No previous snapshot files were found at:${NC}" $BOLD
                talk "  $extraction_path" $LGRAY
                echo ""
                talk "${CYAN}Proceed with a ${BOLD}FULL extraction from the beginning (ordinal set 0)${NC}${CYAN}?${NC}" $CYAN
                read -p "$(echo -e ${BOLD}[y/N]: ${NC}) " confirm_full
                if [[ "$confirm_full" =~ ^[Yy]$ ]]; then
                    talk "Starting a full extraction from the beginning…" $GREEN
                    datetime=false
                    start_index=0
                else
                    talk "User declined. Exiting without changes." $RED
                    exit 0
                fi
            fi
        fi

        local start_index=0
        if [[ "$datetime" == "true" ]]; then
            if [[ "$snapshot_time" =~ ^[0-9]+$ ]]; then
                local matched=false
                for ((i = 0; i < ${#parsed_start_ordinals[@]}; i++)); do
                    local start=${parsed_start_ordinals[$i]}
                    local end_incl=${parsed_end_ordinals[$i]}

                    if (( start <= snapshot_time && snapshot_time <= end_incl )); then
                        start_index=$i
                        local __file="${parsed_filenames[$i]}"
                        talk "--> Using provided snapshot $snapshot_time, resolved to start_index $start_index (file=${__file}, range=${start}..${end_incl})" $GREEN
                        if [[ "$delete_snapshots" == true ]]; then
                            talk "Deleting snapshots from ordinal set $start and later" $CYAN
                            T3_delete_ordinals_from_ordinal "$extraction_path" "$start"
                        fi
                        matched=true
                        break
                    fi
                done

                if [[ "$matched" == false ]]; then
                    if [[ "$delete_snapshots" == true ]]; then
                        talk "delete_snapshots = true"
                        local actual_start=""
                        for ((j = 0; j < ${#parsed_start_ordinals[@]}; j++)); do
                            local s=${parsed_start_ordinals[$j]}
                            local e_incl=${parsed_end_ordinals[$j]}
                            if (( s <= snapshot_time && snapshot_time <= e_incl )); then
                                actual_start=$s
                                break
                            fi
                        done
                        if [[ -n "$actual_start" ]]; then
                            talk "Deleting snapshots from ordinal set $actual_start and later" $CYAN
                            T3_delete_ordinals_from_ordinal "$extraction_path" "$actual_start"
                        else
                            talk "Deleting snapshots from ordinal $snapshot_time and later" $CYAN
                            T3_delete_ordinals_from_ordinal "$extraction_path" "$snapshot_time"
                        fi
                        show_completion_footer
                        return
                    elif [[ "$overwrite_snapshots" == true ]]; then
                        local last_index=$(( ${#parsed_start_ordinals[@]} - 1 ))
                        start_index=$last_index
                        talk "Overwrite mode: will re-extract set index $start_index (file=${parsed_filenames[$start_index]}, range=${parsed_start_ordinals[$start_index]}..${parsed_end_ordinals[$start_index]})" $CYAN
                    else
                        local last_end="${parsed_end_ordinals[$(( ${#parsed_end_ordinals[@]} - 1 ))]}"
                        local __last_idx=$(( ${#parsed_end_ordinals[@]} - 1 ))
                        local __last_file="${parsed_filenames[$__last_idx]}"
                        local __last_start="${parsed_start_ordinals[$__last_idx]}"
                        local __last_end="${parsed_end_ordinals[$__last_idx]}"
                        talk "Ordinal $snapshot_time is newer than the latest set (last=${__last_start}..${__last_end}, file=${__last_file}). No need to Starchive at this time." $LCYAN
                        show_completion_footer
                        return
                    fi
                fi
            else
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
            if [[ "$T3_EXTRACTED_COUNT" -eq 0 && "$T3_SKIPPED_COUNT" -gt 0 && "$HELPER_ARCHIVES_CREATED" -eq 0 ]]; then
                talk "All ordinal sets were already complete. No extraction needed." $LGREEN
            fi
            talk ""
            rm -f "$hash_file_path"
            rm -f "$extracted_hashes_log"
        else
            talk "One or more sets failed. Keeping hash_file.txt and extracted_hashes.log for resume." $YELLOW
        fi

        show_completion_footer
        return
    else
        talk "Using ${BOLD}Tessellation v2${NC} archive extraction logic..." $BLUE

        if [[ -s "$extracted_hashes_log" ]]; then
            echo ""
            talk "Unfinished Starchiver run detected:" $YELLOW
            while true; do
                read -p "Do you want to resume where you left off or start fresh? [r/f]: " resume_choice
                case $resume_choice in
                    [Rr]* )
                        talk "Resuming from previous extraction state..." $GREEN
                        delete_snapshots=false
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
        touch "$extracted_hashes_log"

        if [[ "$datetime" == "true" ]]; then
            if [[ -z "$snapshot_time" ]]; then
                echo "Find the latest snapshot file"
                latest_snapshot=$(find "${extraction_path}" -type f -regex '.*/[0-9]+$' -printf '%T+ %p\n' | sort -r | head -n1 | cut -d" " -f2)
                if [[ -n "$latest_snapshot" ]]; then
                    snapshot_time=$(date -d "$(stat -c %y "$latest_snapshot")" -1 hour "+%Y-%m-%d.%H")
                    echo "The adjusted snapshot time is $snapshot_time"
                else
                    echo ""
                    echo "No previous snapshot files were found at:"
                    echo "  ${extraction_path}"
                    echo ""
                    echo "Proceed with a FULL extraction from the beginning to this path?"
                    read -p "[y/N]: " confirm_full_v2
                    if [[ "$confirm_full_v2" =~ ^[Yy]$ ]]; then
                        echo "Starting a full extraction from the beginning…"
                        datetime=false
                    else
                        echo "User declined. Exiting without changes."
                        exit 0
                    fi
                fi
            fi

            if [[ "$datetime" == "true" ]]; then
                list_starchive_containers "$snapshot_time" "$extraction_path"
                exit 0
            fi
        fi
    fi

    if [ -z "$(ls -A "$extraction_path")" ]; then
        talk "No existing snapshots found. Performing full extraction." $LGREEN
        start_line=1
    else
        if [[ "$delete_snapshots" == true ]] && find "$extraction_path" -type f -size +0c -print -quit | grep -q .; then
            cleanup_snapshots "$extraction_path"
        fi
    fi

    local total_files=$(wc -l < "$hash_file_path")
    local current_file=$((start_line - 1))
    local file_counter=$start_line

    if [[ "$REVERSE_MODE" == true ]]; then
        seq_args="$(seq $(wc -l < "$hash_file_path") -1 $start_line)"
    else
        seq_args="$(seq $start_line $(wc -l < "$hash_file_path"))"
    fi

    for line_num in $seq_args; do
        line=$(sed -n "${line_num}p" "$hash_file_path")
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
        
        talk "Extracting Starchive to: $extraction_path" $BOLD
        sudo pv "$tar_file_path" | sudo tar --overwrite -xzf - -C "$extraction_path"
        echo -e "\n${BOLD}$file_counter of $total_files Starchives extracted successfully.${NC}"

        echo "$file_hash" >> "$extracted_hashes_log"
        rm -f "$tar_file_path"
        file_counter=$((file_counter + 1))
    done
    rm -f "$hash_file_path"
    rm -f "$extracted_hashes_log"
    show_completion_footer
    return
}

list_starchive_containers() {
    local snapshot_time="$1"  # Format: YYYY-MM-DD.HH
    local data_path="$2"

    echo ">>>> Entered list_starchive_containers with:" \
         "snapshot_time='$snapshot_time'" \
         "data_path='$data_path'" >> "$HOME/starchiver.debug.log"

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
        if [[ -s "${HOME}/extracted_hashes.log" ]]; then
            talk "Resume mode detected: skipping snapshot-deletion setup" $CYAN
            delete_snapshots=false
            overwrite_snapshots=false
        elif [ "$dash_o" == true ]; then
            delete_snapshots=false
            overwrite_snapshots=true
        else
            delete_snapshots=true
            overwrite_snapshots=false
        fi

        if [[ "$delete_snapshots" == true ]]; then
            talk "Deleting snapshots starting from set ordinal $snapshot_time (matched on line $start_line_number)" $CYAN
            cleanup_snapshots "$data_path"
            show_completion_footer
            return
        fi

        download_verify_extract_tar "$hash_url_base" "$data_path" "$start_line_number"
    else
        echo "No matching Starchive containers found for time: $snapshot_time"
    fi
}

convert_to_human_readable() {
    local bytes="${1:-0}"
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        bytes=0
    fi

    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} bytes"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(bc <<< "scale=3; $bytes/1024") KB"
    elif [ "$bytes" -lt 1073741824 ]; then
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
    talk "  File size to download: $human_readable_file_size"

    local avail_space=$(df --output=avail -B1 "$download_path" | tail -n1)
    local human_readable_avail_space=$(convert_to_human_readable $avail_space)
    talk "  Available space in $download_path: $human_readable_avail_space"

    if [[ $avail_space -lt $file_size ]]; then
        talk "Insufficient disk space!" $RED
        return 1
    else
        return 0
    fi
}

search_data_folders() {
    local temp_file="/tmp/data_folders_with_snapshot.txt"
    find / -maxdepth 5 -type d -name "snapshot" -path "*/data/snapshot" -printf '%h\n' 2>/dev/null > "$temp_file"

    if [ ! -s "$temp_file" ]; then
        echo "'snapshot' folders not found in default locations." >&2
        read -p "Enter the path of your data folder: " directory >&2
        directory=$(echo "$directory" | xargs)
        if [[ ! -d "$directory" ]]; then
            read -p "Path does not exist. Create it now? [y/N]: " mkdir_ans >&2
            if [[ "$mkdir_ans" =~ ^[Yy]$ ]]; then
                if ! sudo mkdir -p "$directory"; then
                    echo "Failed to create directory." >&2
                    rm -f "$temp_file"; return 1
                fi
            else
                rm -f "$temp_file"; return 1
            fi
        fi
        echo "$directory"
        rm -f "$temp_file"
        return 0
    else
        echo "" >&2
        echo "Select a snapshot data folder path:" >&2
        echo "" >&2
        cat "$temp_file" | nl -w2 -s') ' >&2
        echo "  0) Enter path manually" >&2
        echo ""
        echo "Make a selection:" >&2

        read -r selection >&2

        if [[ $selection =~ ^[0-9]+$ ]]; then
            if [ "$selection" -eq 0 ]; then
                read -r -p "Enter the path of the data folder: " directory >&2
                directory=$(echo "$directory" | xargs)
                if [[ ! -d "$directory" ]]; then
                    read -p "Path does not exist. Create it now? [y/N]: " mkdir_ans >&2
                    if [[ "$mkdir_ans" =~ ^[Yy]$ ]]; then
                        if ! sudo mkdir -p "$directory"; then
                            echo "Failed to create directory." >&2
                            return 1
                        fi
                    else
                        return 1
                    fi
                fi
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
    echo -e ""
    echo -e "${LYELLOW}Don't forget to tip the bar tender!${NC}"
    echo -e "  ${BOLD}This script was written by:${NC} ${BOLD}${LGREEN}@Proph151Music${NC}"
    echo -e "     ${BOLD}for the ${LBLUE}Constellation Network${NC} ${BOLD}ecosystem.${NC}"
    echo -e ""
    echo -e "${LYELLOW}DAG Wallet Address for sending tips can be found here...${NC}"
    echo -e "${LGRAY}${BOLD}${BG256_TEAL}DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3${NC}"
    echo -e ""
    echo -e "${LYELLOW}If you'd like to show your appreciation, consider sending a tip to ${BOLD}${LGREEN}@Proph151Music ${LYELLOW}at the Wallet address above.${NC}"
    echo -e "${LYELLOW}You can also Delegate some DAG by searching Proph151Music on DAG Explorer. A win, win for both of us!${NC}"
    echo -e ""
}

upload_log() {
    if [[ -z "$path" ]]; then
        path=$(search_data_folders | xargs)
        if [[ $? -ne 0 || -z "$path" ]]; then
            echo -e "${LRED}No valid data folder with snapshot selected. Exiting.${NC}"
            exit 1
        fi
    fi
    local log_dir="${path}/../logs"
    local log_file="$log_dir/app.log"
    if [[ ! -f "$log_file" ]]; then
        talk "No app.log file found at $log_file" $LRED
        return
    fi

    local timestamp
    timestamp=$(date +%F)
    local ip_addr
    ip_addr=$(curl -s https://api.ipify.org)
    if [[ -z "$ip_addr" ]]; then
        ip_addr="unknown_ip"
    fi

    local new_log_name="${timestamp}_${ip_addr}_app.log"
    local tmp_copy="${script_dir}/${new_log_name}"
    cp "$log_file" "$tmp_copy" || {
        talk "[FAIL] Could not copy log file to $tmp_copy" $LRED
        return
    }

    talk "Uploading $new_log_name to Gofile" $CYAN
    local servers_resp server
    servers_resp=$(curl -sSL https://api.gofile.io/servers)
    server=$(echo "$servers_resp" | grep -Po '"servers":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    [[ -z "$server" ]] && \
      server=$(echo "$servers_resp" | grep -Po '"serversAllZone":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    if [[ -z "$server" ]]; then
        talk "[FAIL] Could not determine Gofile server" $LRED
        rm -f "$tmp_copy"
        return
    fi

    local upload_resp status_str download_url
    upload_resp=$(curl -sSL \
        -F "file=@${tmp_copy}" \
        -F "expireDate=$(date -d '+7 days' +%Y-%m-%d)" \
        "https://${server}.gofile.io/uploadFile")
    status_str=$(echo "$upload_resp" | grep -Po '"status"\s*:\s*"\K[^"]+')
    download_url=$(echo "$upload_resp" | grep -Po '"downloadPage"\s*:\s*"\K[^"]+')
    if [[ "$status_str" == "ok" && -n "$download_url" ]]; then
        echo -e ""
        echo -e "${BG256_BLUE}${WHITE}${BOLD}==========================================${NC}"
        echo -e "${BG256_BLUE}${WHITE}${BOLD}      Log Upload Complete      ${NC}"
        echo -e "${BG256_BLUE}${WHITE}${BOLD}==========================================${NC}"
        talk ""
        talk "Forward this url to a Team Lead who can have this app.log analyzed..." $YELLOW
        talk ""
        talk "${BG256_DARK_GREEN}    --->  $download_url${NC}" $WHITE$BOLD
        talk ""
        echo -e ""
        echo -e "${CYAN}Note: This link expires in 7 days.${NC}"
        echo -e ""
    else
        talk "[FAIL] Gofile upload failed for $new_log_name" $LRED
    fi

    rm -f "$tmp_copy"
}

upload_starchiver_log() {
    local src_log="${HOME}/starchiver.log"
    if [[ ! -f "$src_log" ]]; then
        talk "No starchiver.log found at $src_log" $LRED
        return
    fi

    local timestamp
    timestamp=$(date +%F)
    local ip_addr
    ip_addr=$(curl -s https://api.ipify.org)
    if [[ -z "$ip_addr" ]]; then
        ip_addr="unknown_ip"
    fi

    local new_name="starchiver_${timestamp}_${ip_addr}.log"
    local tmp_copy="${script_dir}/${new_name}"
    cp "$src_log" "$tmp_copy" || {
        talk "[FAIL] Could not copy starchiver.log to $tmp_copy" $LRED
        return
    }

    talk "Uploading $new_name to Gofile…" $CYAN
    local servers_resp server
    servers_resp=$(curl -sSL https://api.gofile.io/servers)
    server=$(echo "$servers_resp" | grep -Po '"servers":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    [[ -z "$server" ]] && \
      server=$(echo "$servers_resp" | grep -Po '"serversAllZone":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    if [[ -z "$server" ]]; then
        talk "[FAIL] Could not determine Gofile server" $LRED
        rm -f "$tmp_copy"
        return
    fi

    local upload_resp status_str download_url
    upload_resp=$(curl -sSL \
        -F "file=@${tmp_copy}" \
        -F "expireDate=$(date -d '+7 days' +%Y-%m-%d)" \
        "https://${server}.gofile.io/uploadFile")
    status_str=$(echo "$upload_resp" | grep -Po '"status"\s*:\s*"\K[^"]+')
    download_url=$(echo "$upload_resp" | grep -Po '"downloadPage"\s*:\s*"\K[^"]+')
    if [[ "$status_str" == "ok" && -n "$download_url" ]]; then
        talk "[SUCCESS]" $LGREEN
    else
        talk "[FAIL] Gofile upload failed for $new_name" $LRED
        rm -f "$tmp_copy"
        return
    fi

    rm -f "$tmp_copy"

    echo -e ""
    echo -e "${BG256_CYAN}${WHITE}${BOLD}==============================================${NC}"
    echo -e "${BG256_CYAN}${WHITE}${BOLD}         STARCHIVER.LOG UPLOAD COMPLETE         ${NC}"
    echo -e "${BG256_CYAN}${WHITE}${BOLD}==============================================${NC}"
    talk ""
    talk "${LGREEN}Share this URL with your Team Lead, so they can download your starchiver.log:${NC}"
    talk ""
    talk "${BG256_DARK_GREEN}    --->  $download_url${NC}" $WHITE$BOLD
    echo -e ""
    echo -e "${CYAN}Note: This link expires in 7 days.${NC}"
    echo -e ""
}

do_upload() {
    local target="$1"

    case "$target" in
        starchiver.log)
            if [[ ! -f "$HOME/starchiver.log" ]]; then
                echo "ERROR: $HOME/starchiver.log not found."
                exit 1
            fi
            upload_starchiver_log
            ;;
        app.log)
            if [[ -z "$path" ]]; then
                echo "No data-path set. Please select your snapshot folder so we can find app.log:"
                path=$(search_data_folders | xargs) || exit 1
            fi

            upload_log
            ;;
        *)
            echo "ERROR: Unsupported upload target: $target"
            echo "Valid options are: starchiver.log or app.log"
            exit 1
            ;;
    esac

    echo
    read -p "Press ENTER to exit…" _
    exit 0
}

logs_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${BOLD}${LGREEN}---==[ Logs Menu]==---${NC}"
        echo -e ""
        echo -e "S) starchiver.log"
        echo -e "A) app.log"
        echo -e ""
        echo -e "B) Back to Options Menu"
        echo -e "X) Exit Starchiver"
        echo -e ""
        read -p "$(echo -e ${BOLD}Choose an option [S, A, B, X]:${NC}) " choice_log

        case "$choice_log" in
            [Ss])
                while true; do
                    clear
                    echo -e ""
                    echo -e "${BOLD}${LGREEN}---==[ starchiver.log MENU ]==---${NC}"
                    echo -e ""
                    echo -e "V) View starchiver.log"
                    echo -e "U) Upload starchiver.log"
                    echo -e ""
                    echo -e "B) Back to LOGS Menu"
                    echo -e "X) Exit Starchiver"
                    echo -e ""
                    read -p "$(echo -e ${BOLD}Choose an option [V, U, B, X]:${NC}) " sv_choice

                    case "$sv_choice" in
                        [Vv])
                            clear
                            local logfile="${HOME}/starchiver.log"
                            if [[ -f "$logfile" ]]; then
                                local total_lines
                                total_lines=$(wc -l < "$logfile")
                                local start=1
                                local chunk=40
                                while (( start <= total_lines )); do
                                    sed -n "${start},$((start+chunk-1))p" "$logfile"
                                    echo
                                    echo -e "${CYAN}Viewing starchiver.log (40 lines at a time). Press ENTER to advance, 'x' then ENTER to Exit Starchiver.${NC}"
                                    read -r resp
                                    if [[ $resp == "x" ]]; then
                                        break
                                    fi
                                    start=$(( start + chunk ))
                                done
                                echo -e "${CYAN}End of starchiver.log.${NC}"
                                sleep 1
                            else
                                echo -e "${LRED}No starchiver.log found.${NC}"
                                sleep 1
                            fi
                            ;;
                        [Uu])
                            upload_starchiver_log
                            echo -e ""
                            while true; do
                                read -p "$(echo -e ${BOLD}Press 'B' to return to STARCHIVER.LOG Menu or 'X' to Exit Starchiver${NC}): " return_s
                                case "$return_s" in
                                    [Bb]) 
                                        clear
                                        break 
                                        ;;
                                    [Xx]) 
                                        exit 0 
                                        ;;
                                    *) 
                                        echo -e "${YELLOW}Invalid input. Please press 'B' or 'X'.${NC}" 
                                        ;;
                                esac
                            done
                            ;;
                        [Bb])
                            clear
                            options_menu
                            return
                            ;;
                        [Xx]) 
                            exit 0
                            ;;
                        *)
                            echo -e "${YELLOW}Invalid choice. Please choose again.${NC}"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            [Aa])
                upload_log
                echo -e ""
                while true; do
                    read -p "$(echo -e ${BOLD}Press 'B' to return to LOGS Menu or 'X' to Exit Starchiver${NC}): " return_a
                    case "$return_a" in
                        [Bb]) 
                            clear
                            break 
                            ;;
                        [Xx]) 
                            exit 0 
                            ;;
                        *) 
                            echo -e "${YELLOW}Invalid input. Please press 'B' or 'X'.${NC}" 
                            ;;
                    esac
                done
                ;;
            [Bb])
                clear
                break
                ;;
            [Xx]) 
                exit 0
                ;;
            *)
                echo -e "${YELLOW}Invalid choice. Please choose again.${NC}"
                sleep 1
                ;;
        esac
    done
}

options_menu() {
    while true; do
        echo -e ""
        echo -e "${BOLD}${LGREEN}---==[ Options Menu ]==---${NC}"

        if [[ -f "${HOME}/starchiver.log" || -f "${path}/../logs/app.log" ]]; then
            echo -e "${BOLD}L)${NC} ${BOLD}${LCYAN}Logs${NC}"
        else
            echo -e "${GRAY}L) Logs (not available)${NC}"
        fi
        echo -e "${BOLD}S)${NC} ${BOLD}${LCYAN}Scan for Obsolete Hashes${NC}"
        echo -e ""
        echo -e "${BOLD}X)${NC} ${BOLD}${LCYAN}Exit Starchiver${NC}"

        read -p "Choose an option [L, S, X]: " choice

        case "$choice" in
            [Ll])
                logs_menu
                ;;
            [Ss])
                scan_menu
                ;;
            [Xx])
                exit 0
                ;;
            *)
                talk "Invalid choice. Exiting." "$LRED"
                exit 1
                ;;
        esac
    done
}

scan_menu() {
    echo -e ""
    echo -e "${BOLD}${LGREEN}---==[ Scan Menu ]==---${NC}"

    if [[ -d "$OBSOLETE_DIR" && $(ls -A "$OBSOLETE_DIR") ]]; then
        echo -e "S) Scan for Obsolete Hashes"
        echo -e "R) Reclaim Disk Space"
        echo -e ""
        echo -e "X) Exit Starchiver"
        echo -e ""
        read -p "Choose an option [S, R, X]: " choice
    else
        echo -e "S) Scan for Obsolete Hashes"
        echo -e "${GRAY}R) Reclaim Disk Space (not available)${NC}"
        echo -e ""
        echo -e "X) Exit Starchiver"
        echo -e ""
        read -p "Choose an option [S, X]: " choice
    fi

    case "$choice" in
        [Ss])
            if [[ -z "$path" ]]; then
                path=$(search_data_folders | xargs)
                if [[ $? -ne 0 || -z "$path" ]]; then
                    echo -e "${LRED}No valid data folder with snapshot selected. Exiting.${NC}"
                    exit 1
                fi
            fi
            gather_obsolete_hashes_parallel
            move_obsolete_hashes
            exit 0
            ;;
        [Rr])
            if [[ -d "$OBSOLETE_DIR" && $(ls -A "$OBSOLETE_DIR") ]]; then
                sudo rm -rf "$OBSOLETE_DIR"
                talk "Obsolete hashes directory removed. Disk space reclaimed." $GREEN
            else
                talk "No obsolete hashes to reclaim." $YELLOW
            fi
            exit 0
            ;;
        [Xx])
            exit 0
            ;;
        *)
            talk "Invalid choice. Exiting." "$LRED"
            exit 1
            ;;
    esac
}

main_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${LYELLOW}Don't forget to tip the bar tender!${NC}"
        echo -e "  ${BOLD}This script was written by:${NC} ${BOLD}${LGREEN}@Proph151Music${NC}"
        echo -e "     ${BOLD}for the ${LBLUE}Constellation Network${NC} ${BOLD}ecosystem.${NC}"
        echo -e ""
        echo -e "${LYELLOW}DAG Wallet Address for sending tips can be found here...${NC}"
        echo -e "${LGRAY}${BOLD}${BG256_TEAL}DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3${NC}"
        echo -e ""
        echo -e "${BG_WHITE}${BOLD}${LGREEN}     ---==[ STARCHIVER ]==---      ${NC}"
        echo -e "${LGREEN}Create and Restore Starchive files.${NC}"
        echo -e ""
        echo -e "Select a network or options:"
        echo -e "${BOLD}M)${NC} ${BOLD}${LCYAN}MainNet${NC}"
        echo -e "${BOLD}I)${NC} ${BOLD}${LCYAN}IntegrationNet${NC}"
        echo -e "${BOLD}T)${NC} ${BOLD}${LCYAN}TestNet${NC}"
        echo -e "${BOLD}C)${NC} ${BOLD}${LCYAN}Custom${NC}"
        echo -e ""
        if [[ -f "${HOME}/starchiver.log" || -f "${path}/../logs/app.log" ]]; then
            echo -e "${BOLD}L)${NC} ${BOLD}${LCYAN}Logs${NC}"
        else
            echo -e "${GRAY}L) Logs (not available)${NC}"
        fi

        echo -e ""
        echo -e "${BOLD}O)${NC} ${BOLD}${LCYAN}Options${NC}"
        echo -e "${BOLD}X)${NC} ${BOLD}${LCYAN}Exit Starchiver${NC}"
        echo -e ""
        read -p "$(echo -e ${BOLD}Choose your adventure${NC} [M, I, T, C, L, O, X]:) " choice
        echo -e ""

        case $choice in
            [Mm])
                network_choice="mainnet"
                network="mainnet"
                ;;
            [Ii])
                network_choice="integrationnet"
                network="integrationnet"
                ;;
            [Tt])
                network_choice="testnet"
                network="testnet"
                ;;
            [Cc])
                read -p "Enter the URL of the hash file: " hashurl
                read -p "Enter the network name (mainnet/integrationnet/testnet): " network_choice
                network="$network_choice"
                ;;
            [Ll])
                logs_menu
                continue
                ;;
            [Oo])
                scan_menu
                exit 0
                ;;
            [Xx])
                exit 0
                ;;
            *)
                echo -e "${LRED}Invalid choice, please choose again.${NC}"
                sleep 1
                continue
                ;;
        esac
        break
    done

    if [[ -z "$path" ]]; then
        path=$(search_data_folders | xargs) || { talk "No valid data folder Exiting." $LRED; exit 1; }
    fi

    if [[ -z "$hashurl" ]]; then
        hashurl=$(set_hash_url)
    fi

    missingOrdinalsurl="${hashurl%/*}/${network}_missing_ordinals.txt"

    download_verify_extract_tar "$hashurl" "$path"

    if [[ "$NO_CLEANUP" == true ]]; then
        exit 0
    fi

    if [[ "$CLEANUP_ONLY" == true ]]; then
        gather_obsolete_hashes_parallel
        move_obsolete_hashes
        exit 0
    fi

    scan_menu
    exit 0
}

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --upload)
                shift
                if [[ -z "$1" ]]; then
                    echo "ERROR: --upload requires an argument (starchiver.log or app.log)"
                    exit 1
                fi
                UPLOAD_TARGET="$1"
                ;;
            --options)
                options_menu
                exit 0
                ;;
            --cleanup)
                CLEANUP_MODE=true
                CLEANUP_ONLY=true
                ;;
            --onlycleanup)
                ONLY_CLEANUP=true
                ;;
            --nocleanup)
                NO_CLEANUP=true
                ;;
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
            --reverse)
                REVERSE_MODE=true
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done

    if [[ -n "$UPLOAD_TARGET" ]]; then
        do_upload "$UPLOAD_TARGET"
    fi
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
    parsed_end_ordinals=()
    parsed_filenames=()

    while IFS= read -r line; do
        local hash=$(echo "$line" | awk '{print $1}')
        local fname=$(echo "$line" | awk '{print $2}')
        if [[ "$fname" =~ -s([0-9]+)-c([0-9]+)(-e([0-9]+))?\.tar\.gz$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local count="${BASH_REMATCH[2]}"
            local end_incl="${BASH_REMATCH[4]}"
            if [[ -z "$end_incl" ]]; then
                end_incl=$((start + count - 1))
            fi
            parsed_start_ordinals+=("$start")
            parsed_counts+=("$count")
            parsed_end_ordinals+=("$end_incl")
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

    talk "Looking for ordinal set with timestamp - $formatted_input_ts" $CYAN

    for ((i = total_sets - 1; i >= 0; i--)); do
        local start_ord="${parsed_start_ordinals[$i]}"
        local test_ord="$start_ord"
        if (( i == 0 )); then
            test_ord=$((start_ord + 1))
        fi

        local response
        response=$(curl -s --max-time 4 "${api_url}/${test_ord}")

        if [[ -z "$response" || "$response" == "null" || "$response" =~ "504 Gateway" ]]; then
            talk "[WARN] No response for ordinal $test_ord --> skipping" $YELLOW
            continue
        fi

        local ts
        ts=$(echo "$response" | sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p')

        if [[ -z "$ts" ]]; then
            talk "[WARN] No timestamp in response for ordinal $test_ord --> skipping" $YELLOW
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

    talk "[WARN] No ordinal set found with timestamp $formatted_input_ts. Starting from beginning." $YELLOW
    echo 0
}

T3_delete_snapshot_info_in_range() {
    local info_dir="$1"
    local from="$2"
    local to="$3"
    local force_full_range="$4"

    if [[ ! -d "$info_dir" ]]; then
        talk "[SKIP] snapshot_info folder not found: $info_dir" $LGRAY
        return
    fi

    if [[ "$force_full_range" == "true" ]]; then
        to=$((from + 20000 - 1))
    fi

    local deleted_count=0

    while read -r fname; do
        [[ "$fname" =~ ^[0-9]{7,8}$ ]] || continue
        if (( fname >= from && fname <= to )); then
            local fullpath="$info_dir/$fname"
            if sudo rm -f "$fullpath"; then
                ((deleted_count++))
            else
                talk "[ERROR] Could not delete snapshot_info/$fname (code $?)" $LRED
            fi
        fi
    done < <(find "$info_dir" -maxdepth 1 -type f -printf "%f\n")

    if (( deleted_count > 0 )); then
        talk "    Deleted $deleted_count snapshot_info file(s) in range $from to $to" $CYAN
    fi
}

T3_delete_ordinals_from_ordinal() {
    local snapshot_dir="$1"
    local delete_from_ordinal="$2"

    if [[ ! -d "$snapshot_dir" ]]; then
        talk "[ERROR] snapshot_dir does not exist: $snapshot_dir" $LRED
        while true; do
            read -r -p "Press 'X' to exit Starchiver: " choice
            case "$choice" in
                [Xx]) exit 1 ;;
                *) talk "Invalid input. Please press 'X' to exit." $LRED ;;
            esac
        done
    fi

    if [[ "$IS_T3_MODE" == true && "$delete_snapshots" == true && "$datetime" != true ]]; then
        talk "Deleting entire snapshot data..." $GREEN

        trap 'talk "Full cleanup cancelled by user." $YELLOW; trap - SIGINT; return 1' SIGINT

        sudo stdbuf -oL rm -rfv \
            "$snapshot_dir/incremental_snapshot" \
            "$snapshot_dir/incremental_snapshot_tmp" \
            "$snapshot_dir/snapshot_info" \
        | pv -l -N "Removed items" > /dev/null

        trap - SIGINT

        talk "Full cleanup complete." $GREEN
        return
    fi

    local base_path="$snapshot_dir/incremental_snapshot/ordinal"
    local info_dir="$snapshot_dir/snapshot_info"
    local tmp_base_path="$snapshot_dir/incremental_snapshot_tmp/ordinal"
    local total_sets="${#parsed_start_ordinals[@]}"
    local any_deleted=false

    talk "Deleting snapshots from ordinal $delete_from_ordinal and later" $YELLOW

    for (( i=0; i<total_sets; i++ )); do
        local start="${parsed_start_ordinals[$i]}"
        local end="${parsed_end_ordinals[$i]}"
        local is_final_set=$([[ $i -eq $((total_sets - 1)) ]] && echo "true" || echo "false")

        if (( delete_from_ordinal >= start && delete_from_ordinal <= end )); then
            local dir="$base_path/$start"
            if [[ -d "$dir" ]]; then
                talk "  - Deleting ordinal set folder: $dir" $CYAN
                sudo rm -rf "$dir"
                any_deleted=true
            fi
            local tmp_dir="$tmp_base_path/$start"
            if [[ -d "$tmp_dir" ]]; then
                talk "  - Deleting tmp ordinal set folder: $tmp_dir" $CYAN
                sudo rm -rf "$tmp_dir"
                any_deleted=true
            fi
            T3_delete_snapshot_info_in_range "$info_dir" "$delete_from_ordinal" "$end" "$is_final_set"
        elif (( start > delete_from_ordinal )); then
            local dir="$base_path/$start"
            if [[ -d "$dir" ]]; then
                talk "  - Deleting ordinal set folder: $dir" $CYAN
                sudo rm -rf "$dir"
                any_deleted=true
            fi
            local tmp_dir="$tmp_base_path/$start"
            if [[ -d "$tmp_dir" ]]; then
                talk "  - Deleting tmp ordinal set folder: $tmp_dir" $CYAN
                sudo rm -rf "$tmp_dir"
                any_deleted=true
            fi
            T3_delete_snapshot_info_in_range "$info_dir" "$start" "$end" "$is_final_set"
        fi
    done

    if [[ "$any_deleted" == true ]]; then
        talk "Snapshot deletion complete." $CYAN
    else
        talk " - No matching ordinal files or sets found to delete from $delete_from_ordinal." $LGRAY
    fi
}

T3_extract_snapshot_sets() {
    declare -a ordinal_sets_with_extra=()
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
        T3_delete_ordinals_from_ordinal "$extraction_path" "$delete_ordinal"
    fi

    local extracted_hashes_log="${HOME}/extracted_hashes.log"
    [ ! -f "$extracted_hashes_log" ] && touch "$extracted_hashes_log"

    local total_sets="${#parsed_filenames[@]}"

    if [[ "$REVERSE_MODE" == true ]]; then
        seq_args="$(seq $((total_sets - 1)) -1 $start_index)"
    else
        seq_args="$(seq $start_index $((total_sets - 1)))"
    fi

    for i in $seq_args; do
            if (( i == total_sets - 1 )); then
            talk ""
            talk "Checking for updated hash.txt before final set" $CYAN
            local tmp_hash="${HOME}/hash_file_new.txt"
            if wget -q -O "$tmp_hash" "$hash_url_base" && ! cmp -s "$tmp_hash" "$hash_file_path"; then
                mv "$tmp_hash" "$hash_file_path"
                T3_parse_hash_entries "$hash_file_path"
                total_sets="${#parsed_filenames[@]}"
                talk "  - Detected new entries in hash.txt: now $total_sets sets total." $GREEN
            else
                rm -f "$tmp_hash"
            fi
        fi

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

        if (( existing_count > count )); then
            if (( i != total_sets - 1 )); then
                ordinal_sets_with_extra+=("${start}:${existing_count}:${count}")
            fi
        fi

        echo ""
        local relative_index=$((i - start_index + 1))
        talk "${BOLD}${BG256_DARK_PURPLE}     Processing Ordinal Set $start ($relative_index of $((total_sets - start_index)))${NC}     " $WHITE

        if (( existing_count >= count )) && [ "$overwrite_snapshots" != true ]; then
            talk "[OK] Set already complete (${existing_count}/${count}). Skipping." $GREEN
            T3_SKIPPED_COUNT=$((T3_SKIPPED_COUNT + 1))
            continue
        fi

        local expected_hash
        expected_hash=$(grep " $fname" "$hash_file_path" | awk '{print $1}')
        if [[ -f "$extracted_hashes_log" ]] && grep -q "$expected_hash" "$extracted_hashes_log"; then
            talk "[OK] Archive already logged as extracted. Skipping: $fname" $GREEN
            T3_SKIPPED_COUNT=$((T3_SKIPPED_COUNT + 1))
            continue
        fi

        if [ ! -f "$tar_file_path" ]; then
            if ! check_space_for_download "$tar_url" "$(dirname "$tar_file_path")"; then
                talk "${BOLD}[FAIL]${NC} Insufficient disk space for $fname. Aborting extraction." $LRED
                T3_SUCCESS=false
                return 1
            fi

            talk "Downloading $fname..." $LGRAY
            if ! wget -q --show-progress -O "$tar_file_path" "$tar_url"; then
                talk "[FAIL] Failed to download $fname" $LRED
                T3_SUCCESS=false
                return 1
            fi
        fi

        talk "Validating SHA256 hash..." $LGRAY
        local actual_hash
        actual_hash=$(pv "$tar_file_path" | sha256sum | awk '{print $1}')
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            talk "[FAIL] Hash mismatch. Removing bad file and retrying..." $LRED
            rm -f "$tar_file_path"

            talk "Re-downloading $fname..." $LGRAY
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
            actual_hash=$(pv "$tar_file_path" | sha256sum | awk '{print $1}')
            if [[ "$actual_hash" != "$expected_hash" ]]; then
                talk "${BOLD}[CRITICAL ERROR]${NC} Retry failed: hash still mismatched for $fname" $LRED
                talk "${BOLD}[ACTION REQUIRED]${NC} Alert a Team Lead. Snapshots are incomplete." $LRED
                T3_SUCCESS=false
                return 1
            else
                talk "${BOLD}${BG256_DARK_GREEN}    + Hash verified +${NC}    " $FG256_SPRING_GREEN
            fi
        else
            talk "${BOLD}${BG256_DARK_GREEN}    + Hash verified +    ${NC}" $FG256_SPRING_GREEN
        fi

        talk "Extracting $fname to: $extraction_path..." $LGRAY
        sudo pv --force "$tar_file_path" | sudo tar --overwrite -xzf - -C "$extraction_path"
        if [ $? -eq 0 ]; then
            echo "$expected_hash" >> "$extracted_hashes_log"
            talk "    + Extracted successfully: $fname" $LGREEN
            rm -f "$tar_file_path"
            T3_EXTRACTED_COUNT=$((T3_EXTRACTED_COUNT + 1))
        else
            talk "    X Extraction failed for $fname" $LRED$BOLD
            T3_SUCCESS=false
        fi
    done

    talk ""
    talk "Summary: $T3_SKIPPED_COUNT sets skipped | $T3_EXTRACTED_COUNT sets extracted." $GREEN

    if (( ${#ordinal_sets_with_extra[@]} )); then
        local missing_url="${hash_url_base%/*}/${network}_missing_ordinals.txt"
        talk "Fetching list of potentially missing ordinals for ${network}" $LGRAY

        local tmpf
        tmpf=$(mktemp)
        if ! curl -sSL "$missing_url" -o "$tmpf"; then
            talk "[WARN] Could not download missing ordinals list; skipping helper step." $YELLOW
            rm -f "$tmpf"
            return
        fi

        declare -A missing_ordinals_by_set=()
        local current_set=""
        while read -r line; do
            if [[ "$line" =~ \[([0-9]+)\] ]]; then
                current_set="${BASH_REMATCH[1]}"
            elif [[ -n "$current_set" ]]; then
                missing_ordinals_by_set["$current_set"]+="$line "
            fi
        done < "$tmpf"

        rm -f "$tmpf"

        declare -a sets_to_offer=()
        for entry in "${ordinal_sets_with_extra[@]}"; do
            IFS=':' read -r set num_local num_expected <<< "$entry"
            declare -a matches=()
            find_matching_missing_ordinals "$set" matches
            if (( ${#matches[@]} > 0 )); then
                sets_to_offer+=("$set")
            fi
        done

        if (( ${#sets_to_offer[@]} )); then
            talk ""
            talk "${BOLD}${CYAN}You May Have Needed Local Snapshot Files${NC}"
            talk ""
            talk "Your node has ordinal files that aren't yet in the official Starchiver archives."
            talk "By sharing these missing ordinals you'll help fill gaps and improve availability for everyone."
            talk ""
            talk "${BOLD}Sets with files you can contribute:${NC}"
            for set in "${sets_to_offer[@]}"; do
                talk "  --> Set ${set}" $CYAN
            done
            talk ""
            talk "${YELLOW}This is optional, but your contributions make Starchiver more complete and reliable.${NC}"
            talk "${YELLOW}If you choose to help, Starchiver will package these ordinal files, upload the packages${NC}"
            talk "${YELLOW}and provide you with URLs you can share with Proph151Music.${NC}"
            talk ""
            read -p "$(echo -e ${BOLD}Would you like to create & upload helper archives now?${NC} [y/N]: )" build_helper

            if [[ "$build_helper" =~ ^[Yy] ]]; then
                helper_hash_index="${script_dir}/hash_index_helper.txt"
                talk "Building helper hash index" $LCYAN
                rebuild_hash_index_parallel \
                    "${DATA_FOLDER_PATH}/incremental_snapshot/hash" \
                    "$helper_hash_index"

                for set in "${sets_to_offer[@]}"; do
                    declare -a matches=()
                    find_matching_missing_ordinals "$set" matches
                    if (( ${#matches[@]} > 0 )); then
                        build_helper_archive_for_set "$set" "${matches[@]}"
                    fi
                done

                rm -f "$helper_hash_index"
            fi
        fi
    fi
}

parse_missing_ordinals_file() {
    local url="$missingOrdinalsurl"
    local tmpf
    tmpf=$(mktemp)

    if ! curl -sS "$url" -o "$tmpf"; then
        rm -f "$tmpf"
        return 1
    fi

    missing_ordinals_by_set=()

    local current_set=""
    while IFS= read -r line; do
        if [[ "$line" =~ \[([0-9]+)\] ]]; then
            current_set="${BASH_REMATCH[1]}"
        elif [[ -n "$current_set" ]]; then
            missing_ordinals_by_set["$current_set"]+=" $line"
        fi
    done < "$tmpf"

    rm -f "$tmpf"
}

find_matching_missing_ordinals() {
    local set=$1; local -n out=$2
    local dir="${DATA_FOLDER_PATH}/incremental_snapshot/ordinal/${set}"
    for range in ${missing_ordinals_by_set[$set]}; do
        if [[ "$range" == *-* ]]; then
            IFS='-' read -r a b <<< "$range"
            for f in "$dir"/*; do
                local ord=$(basename "$f")
                if (( ord>=a && ord<=b )); then out+=("$ord"); fi
            done
        else
            [[ -f "$dir/$range" ]] && out+=("$range")
        fi
    done
}

rebuild_hash_index_parallel() {
    local hash_dir="$1"
    local index_file="$2"
    job_semaphore=0
    talk "Building helper hash index..."
    local FIRST_CHARS=(0 1 2 3 4 5 6 7 8 9 a b c d e f)
    > "$index_file"
    for c in "${FIRST_CHARS[@]}"; do
        wait_for_slot
        (( job_semaphore++ ))
        {
            local tmpf="${index_file}.part_${c}"
            > "$tmpf"
            for folder in "$hash_dir/${c}"*; do
                [ -d "$folder" ] || continue
                local prefix
                prefix=$(basename "$folder")
                find "$folder" -type f -links +1 \
                    -printf "%i:hash/${prefix}/%P\n" >> "$tmpf"
            done
            cat "$tmpf" >> "$index_file"
            rm -f "$tmpf"
        } &
    done
    wait
    talk "Helper hash index built: $(wc -l < "$index_file") entries."
}

build_helper_archive_for_set() {
    local set=$1; shift
    local ords=( "$@" )
    local tmpd="${script_dir}/starchiver/helper_${set}"
    local sl="${tmpd}/setlist_${set}_helper.txt"
    local tf="${script_dir}/starchiver/${network}-s${set}_helper.tar.gz"

    if [[ ! -f "$helper_hash_index" ]]; then
        talk "[FAIL] helper_hash_index not found at $helper_hash_index" $LRED
        return 1
    fi

    mkdir -p "$tmpd"
    >"$sl"

    for o in "${ords[@]}"; do
        printf "incremental_snapshot/ordinal/%s/%s\n" "$set" "$o" >>"$sl"
        local inode hash_rel
        inode=$(stat -c %i "${DATA_FOLDER_PATH}/incremental_snapshot/ordinal/${set}/${o}") || continue
        hash_rel=$(grep "^${inode}:" "$helper_hash_index" | cut -d':' -f2-)
        printf "incremental_snapshot/%s\n" "$hash_rel" >>"$sl"
    done

    local snap_dir="${DATA_FOLDER_PATH}/snapshot_info"
    local range_start=$set
    local range_end=$(( set + 20000 - 1 ))
    if [[ -d "$snap_dir" ]]; then
        for info_file in "$snap_dir"/*; do
            local fname=$(basename "$info_file")
            if [[ "$fname" =~ ^[0-9]+$ ]] && (( fname >= range_start && fname <= range_end )); then
                printf "snapshot_info/%s\n" "$fname" >>"$sl"
            fi
        done
    fi

    talk "Running tar for helper archive $tf" $LCYAN
    if ! tar --acls --xattrs --selinux --sparse --ignore-failed-read \
             -czf "$tf" -C "$DATA_FOLDER_PATH" -T "$sl"; then
        talk "[FAIL] Failed to create helper archive: $tf" $LRED
        return 1
    fi
    talk "Helper archive for set $set created: ${#ords[@]} ordinals + snapshot_info files in $tf" $LCYAN
    HELPER_ARCHIVES_CREATED=$((HELPER_ARCHIVES_CREATED+1))

    talk "Fetching Gofile server" $CYAN
    local servers_resp server
    servers_resp=$(curl -sSL https://api.gofile.io/servers)
    server=$(echo "$servers_resp" | grep -Po '"servers":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    [[ -z "$server" ]] && \
      server=$(echo "$servers_resp" | grep -Po '"serversAllZone":\s*\[\s*\{\s*"name"\s*:\s*"\K[^"]+')
    if [[ -z "$server" ]]; then
        talk "[FAIL] Could not determine Gofile server" $LRED
        return 1
    fi

    for file in "$tf" "$sl"; do
        talk "Uploading $(basename "$file") to Gofile" $CYAN
        local upload_resp status_str download_url
        upload_resp=$(curl -sSL \
            -F "file=@${file}" \
            -F "expireDate=$(date -d '+7 days' +%Y-%m-%d)" \
            "https://${server}.gofile.io/uploadFile")
        status_str=$(echo "$upload_resp" | grep -Po '"status"\s*:\s*"\K[^"]+')
        download_url=$(echo "$upload_resp" | grep -Po '"downloadPage"\s*:\s*"\K[^"]+')
        if [[ "$status_str" == "ok" && -n "$download_url" ]]; then
            talk "Uploaded $(basename "$file"): $download_url" $LGREEN
        else
            talk "[FAIL] Gofile upload failed for $(basename "$file")" $LRED
        fi
    done

    talk "Please share these URLs with Proph151Music for further processing." $BG256_DARK_GREEN$FG256_LIME
}

gather_obsolete_hashes_parallel() {
    talk ""
    talk "Please wait, while Starchiver performs the hash cleanup tasks." $LCYAN
    talk "This step can take several minutes to sort through millions of files..." $LCYAN
    talk ""
    local FIRST_CHARS=(0 1 2 3 4 5 6 7 8 9 a b c d e f)
    job_semaphore=0

    rm -f "$script_dir"/obsolete_part_*.tmp

    for c in "${FIRST_CHARS[@]}"; do
        wait_for_slot
        (( job_semaphore++ ))
        {
            find "$path/incremental_snapshot/hash/${c}"* -type f -links 1 -printf '%p\n' \
                >> "$script_dir"/obsolete_part_${c}.tmp
        } &
    done
    wait

    local tmp_all="$script_dir/hash_obsolete.tmp"
    rm -f "$tmp_all"
    cat "$script_dir"/obsolete_part_*.tmp > "$tmp_all" 2>/dev/null
    rm -f "$script_dir"/obsolete_part_*.tmp

    if [[ -s "$tmp_all" ]]; then
        mv "$tmp_all" "$script_dir/hash_obsolete.txt"
        local count
        count=$(wc -l < "$script_dir/hash_obsolete.txt")
        talk "Found $count obsolete hashes." "$LGRAY"
    else
        rm -f "$tmp_all"
        talk "Found 0 obsolete hashes." "$LGRAY"
    fi
}

move_obsolete_hashes() {
    mkdir -p "$OBSOLETE_DIR"
    local obsolete_file="$script_dir/hash_obsolete.txt"

    if [[ ! -f "$obsolete_file" ]]; then
        talk "No obsolete hash list found; nothing to move." "$LGRAY"
        return
    fi

    local total
    total=$(wc -l < "$obsolete_file")

    if (( total == 0 )); then
        talk "No obsolete hashes to move." "$LGRAY"
        return
    fi

    talk "Found $total obsolete hashes to move." "$LGRAY"

    if (( total == 0 )); then
        talk "No obsolete hashes to move." "$LGRAY"
        return
    fi

    pv -l -N "Moving obsolete hashes" -s "$total" "$obsolete_file" | \
      xargs -P $MAX_CONCURRENT_JOBS -I {} bash -c '
        src="{}"
        rel="${src#'"$path"'/incremental_snapshot/hash/}"
        dst="'"$OBSOLETE_DIR"'/$rel"
        sudo mkdir -p "$(dirname "$dst")"
        sudo mv "$src" "$dst"
      '

    printf '\r\033[K'
    if [[ -t 1 ]]; then
        stty sane
        tput cnorm
    fi

    local moved
    moved=$(find "$OBSOLETE_DIR" -type f | wc -l)
    talk "Moved $moved obsolete hashes to $OBSOLETE_DIR" "$LGRAY"

    if (( moved > 0 )); then
        local dir_size
        dir_size=$(du -sh "$OBSOLETE_DIR" | cut -f1)
        talk "Obsolete hashes directory size: $dir_size" "$LGRAY"

        if [[ "$ONLY_CLEANUP" == true || "$CLEANUP_ONLY" == true ]]; then
            sudo rm -rf "$OBSOLETE_DIR"
            talk "Obsolete hashes directory removed. Disk space reclaimed (auto cleanup)." $GREEN
        else
            talk "Would you like to permanently remove the obsolete hashes and reclaim disk space? (y/N)" "$CYAN"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                sudo rm -rf "$OBSOLETE_DIR"
                talk "Obsolete hashes directory removed. Disk space reclaimed." "$GREEN"
            else
                talk "Obsolete hashes directory retained at $OBSOLETE_DIR." "$YELLOW"
            fi
        fi
    else
        talk "Obsolete hashes directory is empty." "$LGRAY"
    fi
    rm -f "$obsolete_file"
}

parse_arguments "$@"

if [[ "$ONLY_CLEANUP" == true ]]; then
    if [[ -z "$path" ]]; then
        talk "No data path supplied for --onlycleanup. Please select one:" $CYAN
        path=$(search_data_folders | xargs) \
            || { talk "No valid data folder selected. Exiting." $LRED; exit 1; }
    fi
    gather_obsolete_hashes_parallel
    move_obsolete_hashes
    exit 0
fi

if [[ -n "$network_choice" ]]; then
  if [[ -z "$path" ]]; then
    path=$(search_data_folders | xargs) || exit 1
  fi

  if [[ "$network_choice" == "custom" ]]; then
    read -p "Enter the URL of the hash file: " hashurl
    read -p "Enter the network name (mainnet/integrationnet/testnet): " network_input
    network_choice=$(echo "$network_input" | xargs)
  else
    hashurl=$(set_hash_url)
  fi

  download_verify_extract_tar "$hashurl" "$path"

  if [[ "$NO_CLEANUP" == true ]]; then
    exit 0
  fi

  if [[ "$CLEANUP_ONLY" == true || "$CLEANUP_MODE" == true ]]; then
    gather_obsolete_hashes_parallel
    move_obsolete_hashes
    exit 0
  fi

  scan_menu
  exit 0
fi

main_menu
exit 0
