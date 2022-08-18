#!/bin/bash

# GBA Drive
# By Valou Tweak
# 2022 v1.1
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

# =======================================================================================
# ======================================= Helpers =======================================
# =======================================================================================

# Set timestamp
time_update() {
    NOW=$(date +"%Y-%m-%dT%H:%M:%S")
    NOW_FFORMAT=$(date +"%Y-%m-%dT%H%M%S")
}

# Set main parameters
set_var() {
    CONFIG_FILE="assets/conf/gbadrive.conf"

    if [ -f $CONFIG_FILE ] ; then
        source $CONFIG_FILE
    else
        log_error "Config file $CONFIG_FILE not found"
        exit 1
    fi
}

# Log MESSAGE to stdout and output.log
log() {
    time_update
    local file="$LOGFILE";
    printf '%b' "$NOW $1" '\n' | tee -a "$file"
}

# Log error MESSAGE to stderr and output.log
log_error() {
    local file="$LOGFILE"
    local message="ERROR: $1"
    log "$message"
}

# Check privileges and dependencies
check_dependencies() {
    # Purge log fil content
    echo "" > $LOGFILE

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

# List of execution function for playing with wireless protocols
execute_tshark() {
    cmd="tshark -n -i $WLAN1 -T fields -e dns.qry.name '(tcp or udp) and port 53'"
    log "Execute $cmd"
    tshark -n -i $WLAN1 -T fields -e dns.qry.name '(tcp or udp) and port 53'
}

execute_tcp_dump() {
    cmd="tcpdump -n -i $BT0 -w $capture_file"
    log "Execute $cmd"
    tcpdump -n -i $BT0 -w $capture_file
}

execute_dumpcap() {
    cmd="dumpcap -i $WLAN1 -w $capture_file"
    log "Execute $cmd"
    dumpcap -i $WLAN1 -w $capture_file
}

execute_bettercap() {
    cmd="bettercap -iface $WLAN1 -caplet $caplet"
    log "Execute $cmd"
    bettercap -iface $WLAN1 -caplet $caplet
}

execute_fm_rds() {
    cmd="$FM_RDS -freq $frq -ps PiRaDio -rt HackedByAGameBoy -audio $song"
    log "Execute $cmd"
    log "Ctrl-C to abort"
    ssh pi@localhost $FM_RDS -freq $frq -ps PiRaDio -rt HackedByAGameBoy -audio $song
    log "Kill pi_fm_rds"
    sudo killall pi_fm_rds
}

execute_fm_rds_ta() {
    cmd="$FM_RDS -freq 107.7 -ctl $CONF_DIR/rds_ctl -audio $MUSIC_DIR/noise.wav"
    log "Execute $cmd"
    log "Ctrl-C to abort"
    ssh pi@localhost $FM_RDS -freq 107.7 -ctl $CONF_DIR/rds_ctl -audio $MUSIC_DIR/noise.wav
    log "Kill pi_fm_rds"
    sudo killall pi_fm_rds
}

execute_ir_capture(){
    # Test if gpio_ir_recv mod is enabled
    lsmod | grep "gpio_ir_recv"
    if [ $? -eq 0 ] ; then
        cmd="ir-ctl --device=/dev/lirc1 --mode2 --receive=$capture_file -1"
        log "Execute $cmd"
        ir-ctl --device=/dev/lirc1 --mode2 --receive=$capture_file -1
    else
        log_error "IR module does not seem to be enabled"
        dialog --title "Error" --msgbox "\nIR module does not seem to be enabled\nYou can enable it in 'System' menu" \
        $WIN_HEIGHT $WIN_WIDTH
    fi
}

execute_ir_replay(){
    # Test if gpio_ir_tx mod is enabled
    lsmod | grep "gpio_ir_tx"
    if [ $? -eq 0 ] ; then
        cmd="ir-ctl --device=/dev/lirc0 -s $repeat_signal"
        log "Execute $cmd"
        ir-ctl --device=/dev/lirc0 -s $repeat_signal
    else
        log_error "IR module does not seem to be enabled"
        dialog --title "Error" --msgbox "\nIR module does not seem to be enabled\nYou can enable it in 'System' menu" \
        $WIN_HEIGHT $WIN_WIDTH
    fi
}

execute_tt_capture() {
    cmd="python3 $TT_RECEIVE -o $capture_file"
    log "Execute $cmd"
    $TT_RECEIVE -o $capture_file

    if [ $? -ne 0 ] ; then
        log_error "433 RF module does not seem to be enabled"
        dialog --title "Error" --msgbox "\n433 RF module does not seem to be enabled\nYou can enable it in 'System' menu" \
        $WIN_HEIGHT $WIN_WIDTH
    fi
}

execute_tt_replay() {
    code=$(cut -d ";" -f 1 $repeat_signal)
    pulselength=$(cut -d ";" -f 2 $repeat_signal)
    potocol=$(cut -d ";" -f 3 $repeat_signal)

    $TT_SEND -p $pulselength -t $protocol $code

    if [ $? -ne 0 ] ; then
        log_error "433 RF module does not seem to be enabled"
        dialog --title "Error" --msgbox "\n433 RF module does not seem to be enabled\nYou can enable it in 'System' menu" \
        $WIN_HEIGHT $WIN_WIDTH
    fi
}

check_adapter() {
    ifconfig $WLAN1
    return $?
}

# monitor_mode [enable | disable]: manage monitor mode of external interface
monitor_mode() {
    # Check if the required parameter is specified
    if [ $# -ne 1 ] ; then
        log_error "monitor_mode need 1 parameter"
        menu
    fi

    mode=$1
    # Check if the given mode is allowed
    if [ $mode != "enable" ] && [ $mode != "disable" ] ; then
        log_error "monitor_mode can only enable or disable monitor mode"
        menu
    fi

    # Check if wlan1 interface is present
    check_adapter
    if [ $? -eq 1 ] ; then
        log_error "Adapter $WLAN1 is not present"
        dialog --title "Error" --msgbox "\nAdapter $WLAN1 is not present" \
        $WIN_HEIGHT $WIN_WIDTH
        menu
    fi

    # Enable wlan1 monitor mode
    if [ $mode == "enable" ] ; then
        # Log debug information
        log "Debug sys info: \n$(ifconfig)\n"
        # Enable monitor while interface is down
        ifconfig $WLAN1 down
        iwconfig $WLAN1 mode monitor
        ifconfig $WLAN1 up
    fi

    # Disable wlan1 monitor mode
    if [ $mode == "disable" ] ; then
        ifconfig $WLAN1 down
        iwconfig $WLAN1 mode managed
        ifconfig $WLAN1 up
    fi
}

# Check provided action and run it if selected by user
run_action() {
    # Check if the required parameter is specified
    if [ $# -ne 1 ] ; then
        log_error "run_action need 1 parameter"
        menu
    fi

    action="$1"
    # There are the authorized actions which will be accepeted as a parameter
    authorized_actions=("action_wifi","action_bluetooth","action_radio","action_ir","action_rfid","action_rom","action_system","action_wip")
    # If the action is one of the authorized, then proceed
    if [ "$(echo $authorized_actions | grep -w -o $action)" == "$action" ] ; then
        case $return in
        0)
            #echo "'$choice' chosen"
            # Run the specified action
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
    --menu "Select option:" $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
	1 "WiFi" \
    2 "Bluetooth" \
    3 "Radio" \
    4 "Infrared" \
    5 "RFID" \
    6 "Load GBA ROM" \
    7 "Kitty" \
    8 "Stealth mode" \
    9 "Help" \
    10 "System" 2> $tmpfile

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

            dialog --title "WiFi Menu" --menu "Select option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "[$WLAN0] Connect to default AP" \
            2 "[$WLAN1] Create hotspot" \
            3 "[$WLAN1] Deauth attack" \
            4 "[$WLAN1] Capture passwords" \
            5 "[$WLAN1] DNS scan" \
            6 "[$WLAN1] Capture network" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_wifi ;;
		2)
            # Bluetooth Menu
            log "Enter Bluetooth menu"

            dialog --title "Bluetooth Menu" --menu "Select option:" \
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

            dialog --title "Radio Menu" --menu "Select option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "[76-108 MHz] Hijack FM radio" \
            2 "[1-250 MHz] Hijack Gov radio" \
            3 "[107.7 MHz] Hijack FM TA alert" \
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
            dialog --title "Infrared Menu" --menu "Select option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "Capture" \
            2 "Replay" \
            3 "Shutdown TVs" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_ir ;;
		5)
            # RFID Menu
            log "Enter RFID menu"
            dialog --title "RFID Menu" --menu "Select option:" \
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
            action_rom ;;
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
            ifconfig $WLAN0 down
            ifconfig $WLAN1 down
            systemctl stop bluetooth btnap hostapd
            rfkill unblock wlan
            killall dumpcap
            killall tcpdump
            killall bettercap
            killall tshark
            killall pi_fm_rds

            # Display instructions
            dialog --title "$NAME" --msgbox "\nStealth mode enabled: no WiFi, BT or radio broadcast running.\nEach interface will be bring up again as needed when activating the appropriate action." \
            $WIN_HEIGHT $WIN_WIDTH

            menu
            ;;
        9)
            # Help
            log "Enter help menu"

            header="$NAME Script\n[ Version \"$VERSION\" ]\n\n"
            add_wifi="How to connect a new WiFi network?\nEdit the file /etc/wpa_supplicant/wpa_supplicant.conf while using 'wpa_passphrase SSID PASSWORD' command output.\n\n"
            add_bluetooth="How to pair a new bluetooth device?\nRun BT hotspot from your GBA, then connect to it from your computer (SSID: GBA Drive). Use SELECT to select 'Pair' into the popup, then A to validate.\n\n"
            ssh_co="How to SSH into $NAME? Connect to the same network (WiFi connect, WiFi hotspot, Bluetooth hotspot) and ssh to:\npi@gbadrive.local\npassword: gbadrive\n\n"
            radio_music="How to add broadcasted sounds on radio?\nYou can add your .wav files (no MP3) in $MUSIC_DIR\n\n"
            gba_rom="How to add ROM into $NAME?\nYou can add your .mb.gba files (multiboot ROM only) in $ROM_DIR\n\n"
            level_up="How to level up my Kitty?\nYou can explore and run actions in $NAME to gain xp, then level up. Each level will unlock a new picture of Kitty. \n\n"
            dialog --title "$NAME" --msgbox "$header$add_wifi$add_bluetooth$ssh_co$radio_music$gba_rom$level_up" \
            $WIN_HEIGHT $WIN_WIDTH
            menu
            ;;
        10)
            # System menu
            log "Enter system menu"

            dialog --title "Radio Menu" --menu "Select option:" \
            $WIN_HEIGHT $WIN_WIDTH $MENU_HEIGHT \
            1 "Print logs" \
            2 "Enable IR module" \
            3 "Enable RF 433 modules" \
            4 "Reboot" \
            5 "Shutdown" 2> $tmpfile

            return=$?
            choice=`cat $tmpfile`

            run_action action_system ;;
	esac
}

# =======================================================================================
# ================================ Action Menu - Level 3 ================================
# =======================================================================================

# System actions
action_system() {
    case $choice in
    1)
        log "Enter log menu"

        dialog --title "$NAME" --msgbox "$(cat $LOGFILE)" \
        $WIN_HEIGHT $WIN_WIDTH
        menu
        ;;
    2)
        log "Enable IR module"

        # Make sure to disable it in config.txt also, in case of reboot
        sed -i "s/^#dtoverlay=gpio-ir/dtoverlay=gpio-ir/g" /boot/config.txt
        # Enable IR modules
        modprobe gpio_ir_recv
        modprobe gpio_ir_tx
        dialog --title "$NAME" --msgbox "\nIR module enabled" \
        $WIN_HEIGHT $WIN_WIDTH
        menu
        ;;
    3)
        log "Enable RF 433 modules"

        # Enable RF modules means disabling IR mod
        # Make sure to disable it in config.txt also, in case of reboot
        sed -i "s/^dtoverlay=gpio-ir/#dtoverlay=gpio-ir/g" /boot/config.txt
        # Disable related mods
        modprobe -r gpio_ir_recv
        modprobe -r gpio_ir_tx
        dialog --title "$NAME" --msgbox "\nRF 433 modules enabled" \
        $WIN_HEIGHT $WIN_WIDTH
        menu
        ;;
    4)
        # Reboot
        log "Reboot pressed"
        clear;
        dialog --title "$NAME" --msgbox "\n$(cat $ASCII_DIR/kitty_zz.ascii)\n            Bye bye =D" \
        $WIN_HEIGHT $WIN_WIDTH
        clear ; reboot
        ;;
    5)
        # Exit
        log "Shutdown pressed"
        clear;
        dialog --title "$NAME" --msgbox "\n$(cat $ASCII_DIR/kitty_zz.ascii)\n            Bye bye =D" \
        $WIN_HEIGHT $WIN_WIDTH
        clear ; shutdown -h now
        ;;
    esac

    # Return to main menu
    menu
}

# WiFi actions
action_wifi() {
    # Update time
    time_update
    case $choice in
		1)
            log "Connect to default WiFi AP"

            # Turn WiFi on via internal wlan0
            # Reset dns
            systemctl restart wpa_supplicant
            ifconfig $WLAN0 down
            ifconfig $WLAN0 up
            echo "nameserver 9.9.9.9" > /etc/resolv.conf

            dialog --title "Connect WiFi" --msgbox \
            "\nTrying connection to default WiFi AP:\n\n SSID: Mobile_AP\n Password: try to hack me ;)" \
            $WIN_HEIGHT $WIN_WIDTH
            ;;
        2)
            log "Run WiFi hotspot"

            # Check if wlan1 interface is present
            if [ check_adapter -eq 1 ] ; then
                log_error "Adapter $WLAN1 is not present"
                dialog --title "Error" --msgbox "\nAdapter $WLAN1 is not present" \
                $WIN_HEIGHT $WIN_WIDTH
                menu
            fi
            # Turn WiFi hotspot via external adapter wlan1
            ifconfig $WLAN1 down
            ifconfig $WLAN1 up
            # Free up radio transmissions
            rfkill unblock wlan
            # Start hotspot
            systemctl start hostapd

            dialog --title "Hotspot" --msgbox \
            "\nRunning WiFi hotspot:\n\n SSID: GBA Drive\n WPA: gbadrive" \
            $WIN_HEIGHT $WIN_WIDTH
            # Shutdown hotspot and external wlan1 interface
            systemctl stop hostapd
            ifconfig $WLAN1 down
            ;;
		3)
            log "Run WiFi deauth attack"

            # Set external interface wlan1 to monitor mode
            clear ; monitor_mode enable
            # Then run deauth attack via bettercap
            caplet="/usr/local/share/bettercap/caplets/pita.cap"
            cmd="bettercap -iface $WLAN1 -caplet $caplet"
            execute_bettercap

            dialog --title "Deauth" --msgbox \
            "\nDeauth attack stopped\n\nHandshake capture stopped" $WIN_HEIGHT $WIN_WIDTH
            # Disable monitor mode
            monitor_mode disable
            ;;
        4)
            log "Run WiFi password sniffer"

            # Set external interface wlan1 to monitor mode
            clear ; monitor_mode enable
            # Then run deauth attack via bettercap
            caplet="/usr/local/share/bettercap/caplets/simple-passwords-sniffer.cap"
            execute_bettercap

            dialog --title "Password sniffer" --msgbox \
            "\nPassword sniffer stopped" $WIN_HEIGHT $WIN_WIDTH
            # Disable monitor mode
            monitor_mode disable
            ;;

        5)
            log "Run DNS scan"

            # Set external interface wlan1 to monitor mode
            clear ; monitor_mode enable
            clear ; execute_tshark

            dialog --title "Password sniffer" --msgbox \
            "\nDNS scan stopped" $WIN_HEIGHT $WIN_WIDTH
            # Disable monitor mode
            monitor_mode disable
            ;;
        6)
            log "Run WiFi capture"

            # Set external interface wlan1 to monitor mode
            clear ; monitor_mode enable
            # Start capture
            capture_file="$SHARE_DIR/captures/wifi_capture_$NOW_FFORMAT.pcapng"
            # Need to be touch, if not dumpcap has no right (bug ?)
            touch $capture_file
            execute_dumpcap

            dialog --title "Network capture" --msgbox "\nCapture stopped" $WIN_HEIGHT $WIN_WIDTH
            # Disable monitor mode
            monitor_mode disable
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
            "\nRunning Bluetooth network hotspot \nSSID: GBA Drive" $WIN_HEIGHT $WIN_WIDTH
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

            clear ; cmd="$SCRIPT_DIR/recon_bt.sh"
            log "Execute $cmd" ; $cmd
            dialog --title "Bluetooth recon" --msgbox \
            "\nRecon stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        4)
            log "Run BLE recon"

            clear ; cmd="$SCRIPT_DIR/recon_ble.sh"
            log "Execute $cmd" ; $cmd
            dialog --title "Bluetooth LE recon" --msgbox \
            "\nRecon stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        5)
            log "Run BT packet capture"

            capture_file="$SHARE_DIR/captures/bt_capture_$NOW_FFORMAT.pcapng"
            clear ; execute_tcp_dump
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
                execute_fm_rds

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
                execute_fm_rds

                dialog --title "[$frq] Hijack Gov radio" --msgbox \
                " \nHijacking stopped" $WIN_HEIGHT $WIN_WIDTH
            fi ;;
        3)
            clear ; log "[107.7 MHz] Hijack FM TA alerts"

            # Run radio hijack
            execute_fm_rds_ta

            dialog --title "[107.7 MHz] Hijack FM TA alerts" --msgbox \
            "\nHijacking stopped" $WIN_HEIGHT $WIN_WIDTH
            ;;
        4)
            log "[433 MHz] Capture signal"

            # Capture radio signal
            capture_file="$SHARE_DIR/captures/tt_capture_$NOW_FFORMAT.txt"
            clear ; log "Wait for 433 MHz signal or Ctrl-C to abort"
            execute_tt_capture

            dialog --title "[433 MHz] Capture signal" --msgbox \
            "\nCapture stopped" $WIN_HEIGHT $WIN_WIDTH
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
            clear ; execute_tt_replay
            dialog --title "[433 MHz] Replay signal" --msgbox \
            "\nReplay done" $WIN_HEIGHT $WIN_WIDTH
            ;;
        6)
            log "[868 MHz] Capture signal"

            # Capture radio signal
            dialog --title "[868 MHz] Capture signal" --msgbox \
            "\nCapture stopped" $WIN_HEIGHT $WIN_WIDTH
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
            "\nReplay done" $WIN_HEIGHT $WIN_WIDTH
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

            # Start capture
            capture_file="$SHARE_DIR/captures/ir_capture_$NOW_FFORMAT.txt"
            clear ; log "Press any IR key or Ctrl-C to abort"
            execute_ir_capture

            dialog --title "Infrared capture" --msgbox \
            "\nCapture stopped" $WIN_HEIGHT $WIN_WIDTH
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
            clear ; execute_ir_replay

            dialog --title "Infrared replay" --msgbox \
            "\nReplay done" $WIN_HEIGHT $WIN_WIDTH
            ;;
        3)
            log "Shutdown TVs"
            dialog --title "Shutdown TVs" --msgbox \
            "\nReady to shoot them all? \nWork in progress, sorry..." \
            $WIN_HEIGHT $WIN_WIDTH
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
/usr/games/oneko -tora -tofocus -bg green -position 50 50 &
# Run the main menu
menu
