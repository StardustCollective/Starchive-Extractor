# Starchive-Extractor v2.0 (Built for Tessellation v3)

## Description
Starchive Extractor is a Bash script designed to efficiently download, verify, and extract node snapshots from Starchive files for the Constellation Network. This tool is especially useful for handling large data files from different network clusters, providing a streamlined process for managing data integrity and storage of the node snapshots.

## Features
- Download Starchive files containing node snapshots from specified network clusters (mainnet, integrationnet, testnet).
- Verify file integrity using SHA256 hash checks.
- Extract Starchives with progress visualization.
- Check disk space before downloading to ensure sufficient storage.
- Interactive and non-interactive modes to facilitate automation.
- Customizable paths for data storage.

## Installation
Ensure you have `bash`, `curl`, `wget`, `pv`, `tar`, `sha256sum`, `tmux` and `bc` installed on your system. Most of these tools are typically pre-installed on Linux systems.
If Starchiver detects that any of these dependencies do not exit, it will try to automatically install them.

**1. Download Starchiver and make sure it is executable:**
```
curl -fsSL https://raw.githubusercontent.com/StardustCollective/Starchive-Extractor/main/starchiverT3-ext.sh -o starchiverT3-ext.sh && chmod +x starchiverT3-ext.sh
```

**2. Launch starchiverT3-ext.sh:**
```bash
./starchiverT3-ext.sh
```

* Running without any flags will open the **interactive Main Menu**.
* **Important:** Before you start any download or extraction, **stop your Layer 0 node service** and disable its auto-restart. This ensures the node won’t come back online until Starchiver has finished.

## Usage
Run the script with optional parameters to specify the data path and network cluster.

```
./starchiverT3-ext.sh --data-path [PathToDataFolder] --cluster [Network]
```

- `--data-path`: Sets the path to the folder where Starchive files will be stored (`/var/tessellation/dag-l0/data`).
- `--cluster`: Specifies the network cluster to download Starchive files from (`mainnet`, `integrationnet`, `testnet`).

If no parameters are provided, the script enters an interactive mode, allowing you to choose options via a user-friendly menu.

Optional switches that can also be used:

- `-d`: Will automatically force the deletion of data snapshots before downloading/extracting Starchive's.
- `-o`: Will automatically overwrite the data snapshots when extracting Starchive's.

- `--cleanup`
  Perform download → extract, then immediately scan & purge obsolete hash files (no prompts), then exit.

- `--nocleanup`
  Run download & extract only; leave any obsolete hashes in place, then exit.
  
- `--onlycleanup`
  Skip download & extract entirely—go straight to scanning & purging obsolete hashes, then exit.

- `--upload <starchiver.log|app.log>`
  Upload the specified log file to Gofile.io and print a download URL that can be shared with a Team Lead to help assist and/or troubleshoot. Uploaded files will expire after 7 days.

- `--options`
  Show the interactive **Options** menu (same as choosing “O” interactively in the full main menu).

- `--datetime`: Allows for flexible specification of the date and time or ordinal for which you want to start processing Ordinal Sets. This parameter supports several formats, enabling precise control over the extraction process based on specific or relative timestamps.

#### --datetime Formats Supported

1. **Unix Timestamp**
   Provide a 10-digit Unix epoch to specify the exact moment.

   ```
   --datetime 1617753600
   ```

2. **Standard Date and Hour**
   Use `YYYY-MM-DD.HH` to specify year, month, day and hour (24-hour clock).

   ```
   --datetime 2024-05-01.14
   ```

3. **Date with Hour and Minute Offset**
   Append a space and `z`/`Z` plus HMM or HHMM to include minutes.

   * `YYYY-MM-DD zHMM`: hour (no leading zero) + minute
   * `YYYY-MM-DD ZHHMM`: hour (with leading zero) + minute

   ```
   --datetime "2024-05-01 z145"
   --datetime "2024-05-01 Z1545"
   ```

4. **Ordinal Number**
   Supply a Constellation snapshot ordinal directly; the script will locate which *Ordinal Set* contains it and begin processing from that set.

   ```
   --datetime 2539486
   ```

---

#### How `--datetime` Inputs Are Resolved

* **Date/Time inputs** (formats 1–3):
  Starchive-Extractor queries the Constellation block explorer for the latest snapshot **at or before** the given timestamp. It then maps that result to its corresponding Ordinal Set number and begins processing from that set.

* **Ordinal inputs** (format 4):
  The script examines your parsed Ordinal Sets and identifies which set range contains the provided ordinal. Processing then starts at the beginning of that set.

---

#### Automatic Timestamp Calculation

If you invoke `--datetime` **without** a value, the script will:

1. Scan your data folder for the most recent local snapshot file.
2. Take its filesystem timestamp and subtract one hour.
3. Use that adjusted time as the start point—ensuring you pick up just before your last snapshot.

```
--datetime
```

---

### Example --datetime Usage

* **Direct Unix timestamp**

  ```
  ./starchiverT3-ext.sh --datetime 1617753600 --data-path /var/tessellation/dag-l0/data --cluster mainnet
  ```

* **Standard date/hour**

  ```
  ./starchiverT3-ext.sh --datetime 2024-05-01.14 --data-path /var/tessellation/dag-l0/data --cluster mainnet
  ```

* **Standard date**

  ```
  ./starchiverT3-ext.sh --datetime 2024-05-01 --data-path /var/tessellation/dag-l0/data --cluster mainnet
  ```

* **Hourly + minute offset**

  ```
  ./starchiverT3-ext.sh --datetime "2024-05-01 z2359" --data-path /var/tessellation/dag-l0/data --cluster mainnet
  ```

* **Ordinal-based start with an unattended ordinal hash --cleanup**

  ```
  ./starchiverT3-ext.sh --datetime 2539486 --data-path /var/tessellation/dag-l0/data --cluster testnet --cleanup
  ```

* **Automatic calculation (--datetime with no value) and skip any ordinal hash cleanup with --nocleanup**

  ```
  ./starchiverT3-ext.sh --datetime --data-path /var/tessellation/dag-l0/data --cluster mainnet --nocleanup
  ```

## Starchiver Session (tmux)

When you run `./starchiverT3-ext.sh`, it will automatically start (or attach to) a **tmux** session named `Starchiver`. This lets the process keep running even if you disconnect your SSH session.

### Why use tmux?

* **Survive disconnects:** Long downloads or extractions won’t stop if your network drops.
* **One-step attach:** The script handles session creation and attachment for you.

---

### Detach from the session

To leave it running in the background:

1. Press `Ctrl + b`
2. Release, then press `d`

You’ll see:

```
[detached from Starchiver]
```

---

### Re-attach to the session

**Option 1: Rerun the script**

```bash
./starchiverT3-ext.sh
```

If the `Starchiver` session already exists, the script will attach to it automatically. If the session has ended launching Starchiver will start a new session. 

**Option 2: Direct tmux command**

```bash
tmux attach -t Starchiver
```
or shorthand:
```bash
tmux a -t Starchiver
```

---

### Kill the session manually

If you ever need to terminate it yourself:

```bash
tmux kill-session -t Starchiver
```

---

## Requirements
- Linux Operating System with Bash Shell
- Internet Connectivity for Downloading Starchive Files
- Adequate Disk Space for Starchive Files

## Contributing
Contributions to the Starchive Extractor are welcome. Please follow the standard procedures for contributing to open source projects on GitHub.

## Acknowledgments
This script was written by @Proph151Music for the Constellation Network ecosystem. 
Don't forget to tip the bar tender! 

**DAG Wallet Address for sending tips:**
`DAG0Zyq8XPnDKRB3wZaFcFHjL4seCLSDtHbUcYq3`
