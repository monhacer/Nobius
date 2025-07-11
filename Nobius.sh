#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    clear
    echo "You should run this script with root!"
    echo "Use sudo -i to change user to root"
    exit 1
fi

function main_menu {
    clear
    echo "------------- Nobius --------------"
    echo "https://github.com/monhacer/Nobius"
    echo "-----------------------------------"
    echo "Choose an option:"
    echo "1-Block Abuse IP-Ranges"
    echo "2-add IP/IP-Ranges to whitelist (manually)"
    echo "3-add IP/IP-Ranges to blocklist (manually)"
    echo "4-View Current Rules"
    echo "5-Clear all Current rules"
    echo "6-Exit"
    read -p "Enter your choice: " choice
    case $choice in
    1) block_ips ;;
    2) whitelist_ips ;;
    3) block_custom_ips ;;
    4) view_rules ;;
    5) clear_chain ;;
    6) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid option"; main_menu ;;
    esac
}

function block_ips {
    clear
    if ! command -v iptables &> /dev/null; then
        apt update
        apt install -y iptables
    fi

    if ! dpkg -s iptables-persistent &> /dev/null; then
        apt update
        apt install -y iptables-persistent
    fi

    if ! iptables -L nobius -n >/dev/null 2>&1; then
        iptables -N nobius
    fi

    if ! iptables -L nobius-custom -n >/dev/null 2>&1; then
        iptables -N nobius-custom
    fi

    if ! iptables -L nobius-whitelist -n >/dev/null 2>&1; then
        iptables -N nobius-whitelist
    fi


    if ! iptables -L OUTPUT -n | awk '{print $1}' | grep -wq "^nobius$"; then
        iptables -I OUTPUT -j nobius
    fi

    if ! iptables -L OUTPUT -n | awk '{print $1}' | grep -wq "^nobius-custom$"; then
        iptables -I OUTPUT -j nobius-custom
    fi

    if ! iptables -L OUTPUT -n | awk '{print $1}' | grep -wq "^nobius-whitelist$"; then
        iptables -I OUTPUT -j nobius-whitelist
    fi

    clear
    read -p "Are you sure about blocking abuse IP-Ranges? [Y/N] : " confirm

    if [[ $confirm == [Yy]* ]]; then
        clear
        read -p "Do you want to delete the previous rules? [Y/N] : " clear_rules
        if [[ $clear_rules == [Yy]* ]]; then
            iptables -F nobius
            iptables -F nobius-custom
            iptables -F nobius-whitelist
        fi

        IP_LIST=$(curl -s 'https://raw.githubusercontent.com/monhacer/Nobius/main/abuse.ipv4')

        if [ $? -ne 0 ] || [ -z "$IP_LIST" ]; then
            echo "Failed to fetch the IP-Ranges list. Please contact @monhacer"
            read -p "Press enter to return to Menu" dummy
            main_menu
        fi

        for IP in $IP_LIST; do
            iptables -A nobius -d $IP -j DROP
        done

        echo '127.0.0.1 appclick.co' | tee -a /etc/hosts >/dev/null
        echo '127.0.0.1 pushnotificationws.com' | tee -a /etc/hosts >/dev/null
        iptables-save > /etc/iptables/rules.v4

        clear
        echo "Abuse IP-Ranges blocked successfully."

        read -p "Do you want to enable Auto-Update every 24 hours? [Y/N] : " enable_update
        if [[ $enable_update == [Yy]* ]]; then
            setup_auto_update
            echo "Auto-Update has been enabled."
        fi

        read -p "Press enter to return to Menu" dummy
        main_menu
    else
        echo "Cancelled."
        read -p "Press enter to return to Menu" dummy
        main_menu
    fi
}

function setup_auto_update {
    cat <<EOF >/root/nobius-update.sh
#!/bin/bash
iptables -F nobius
IP_LIST=\$(curl -s 'https://raw.githubusercontent.com/monhacer/Nobius/main/abuse.ipv4')
for IP in \$IP_LIST; do
    iptables -A nobius -d \$IP -j DROP
done
iptables-save > /etc/iptables/rules.v4
EOF

    chmod +x /root/nobius-update.sh

    crontab -l 2>/dev/null | grep -v "/root/nobius-update.sh" | crontab -
    (crontab -l 2>/dev/null; echo "0 0 * * * /root/nobius-update.sh") | crontab -
}

function whitelist_ips {
    clear
    read -p "Enter IP-Ranges to whitelist (like 192.168.1.0/24): " ip_range

    iptables -I nobius-whitelist -d "$ip_range" -j ACCEPT

    iptables-save > /etc/iptables/rules.v4

    clear
    echo "$ip_range whitelisted successfully."
    read -p "Press enter to return to Menu" dummy
    main_menu
}

function block_custom_ips {
    clear
    read -p "Enter IP-Ranges to block (like 192.168.1.0/24): " ip_range

    iptables -A nobius-custom -d "$ip_range" -j DROP

    iptables-save > /etc/iptables/rules.v4

    clear
    echo "$ip_range blocked successfully."
    read -p "Press enter to return to Menu" dummy
    main_menu
}

function view_rules {
    clear
    echo "===== nobius Rules ====="
    iptables -L nobius -n --line-numbers
    echo ""
    echo "===== nobius-custom Rules ====="
    iptables -L nobius-custom -n --line-numbers
    echo "===== nobius-whitelist Rules ====="
    echo ""
    iptables -L nobius-whitelist -n --line-numbers
    read -p "Press Enter to return to Menu" dummy
    main_menu
}

function clear_chain {
    clear
    iptables -F nobius
    iptables -F nobius-custom
    iptables -F nobius-whitelist
    sed -i '/127.0.0.1 appclick.co/d' /etc/hosts
    sed -i '/127.0.0.1 pushnotificationws.com/d' /etc/hosts
    crontab -l | grep -v "/root/nobius-update.sh" | crontab -
    iptables-save > /etc/iptables/rules.v4
    clear
    echo "All Rules cleared successfully."
    read -p "Press enter to return to Menu" dummy
    main_menu
}

main_menu
