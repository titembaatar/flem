# TODO List

This is the centralized TODO list for tracking improvements and updates to the `lazy_*` scripts.

## TODO List for `lazy_zfs.sh`

### 1. Input Validation Improvements
- [ ] Verify that the entered RAID level is compatible with the number of disks selected.
- [ ] Confirm whether Proxmox excludes disks already in a ZFS pool (verify this behavior).

### 2. Enhanced Error Handling
- [ ] Add more specific error messages for critical failures, such as RAID level issues or disk selection errors.

### 3. Logging Enhancements
- [ ] Add timestamps to log messages for better troubleshooting.
- [ ] Separate logs for errors and standard output for clarity.

### 4. Interactive Usability
- [ ] Provide default values for user inputs where appropriate.
- [ ] Replace `read` prompts with `select` menus for RAID level selection.

### 5. Help and Feedback
- [ ] Add a `--help` flag to explain script usage and options.
- [ ] Display a configuration summary before execution and prompt for confirmation.

### 6. Modularization
- [ ] Break the script into functions (e.g., `validate_inputs`, `create_pool`, `add_to_proxmox`) for better readability and maintainability.

### 7. Aesthetic Improvements
- [ ] Add dynamic width adjustment for the ASCII banner to fit the terminal size.
- [ ] Ensure consistent alignment and style across all output lines.

## TODO List for `tput` Configuration Script

### 1. Interactive Testing
- [ ] Allow users to test and adjust:
  - The number of reserved lines.
  - Borders (e.g., enable/disable, ASCII style).
  - Alignment of messages (e.g., left, center, or right).

### 2. Preview Mode
- [ ] Display a live preview of the reserved space and how messages will appear.
- [ ] Simulate scrolling behavior with test messages.

### 3. Save Configurations
- [ ] Save the tested configuration to a file (e.g., `~/.lazy_tput.conf`).
- [ ] Allow `lazy_*` scripts to load this file for consistent settings.

### 4. Terminal Compatibility Checks
- [ ] Test for `tput` support and ensure features like cursor movement, line clearing, and screen positioning work as expected.

### 5. Predefined Templates
- [ ] Provide a few predefined styles (e.g., minimal, bordered, centered) for quick setup.