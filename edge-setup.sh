#!/bin/bash

sestatus=$(sestatus | grep "SELinux status" | cut -d ":" -f2)

checkSuccess() {
    # General function to check whether the previous command succeeded or failed.
    # Will exit gracefully upon failure.
    if [ $? -eq 0 ]; then
            echo "$1"

    else
            echo "$2"
            exit 1;
    fi
}

checkSuccessNoExit() {

    # General function to check whether the previous command succeeded or failed.
    if [ $? -eq 0 ]; then
            echo "$1"

    else
            echo "$2"
    fi
}

checkSEstatus() {

    echo "## SESTATUS is $sestatus ##"
    
    if [ $sestatus = "enabled" ]; then
        disableSELinux
    fi

}

disableSELinux(){

    echo "### Disabling SEStatus. Please run this script again once reboot is complete."
    sudo sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
    checkSuccess "[+] SELinux config file edit success!." "[-] SELinux config file edit failed. Are you sudo?"

    read -i "## SELinux disable requires a restart. Commence restart? (y/n)"
    sudo shutdown -r now
}

checkLSBLK(){

}

main() {

    checkSEstatus


}

main