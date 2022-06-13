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
    checkSuccess "[+] SELinux config file edit success!." "[-] SELinux config file edit failed. Are you sudo/root?"

    read -p "## SELinux disable requires a restart. Commence restart? (y/n)" yesOrNo
    if [ $yesOrNo = "y" || $yesOrNo = "Y" ]; then
        sudo shutdown -r now
    else
        echo "## Please restart the computer when possible to continue the installation."
        exit 1;
}


checkDriveSizes(){

    # Check that sdb partition/drive exists and is of the correct size.
    echo "[+] Checking that sdb is available..."
    drive1size=$(lsblk | grep "sdb" | cut -d " " -f13 | cut -d "G" -f1)
    if [ $? -eq 1 ]; then
        echo " |--x sdb does not exist. Please connect the correct storage."
        exit 1;
    else
        echo " |--> sdb exists; checking size..." 
        if [ $drive1size -gt 49 ]; then
            echo " |--> Drive size acceptable: $drive1size"
        else
            echo " |--x Please increase the size of the sdb and try again. Exiting."
            exit 1;
        fi
    fi
    
    # Check that sdb partition/drive exists and is of the correct size.
    echo "[+] Checking that sdc is available..."
    drive2size=$(lsblk | grep "sdc" | cut -d " " -f12 | cut -d "G" -f1)
    if [ $? -eq 1 ]; then
        echo " |--x sdc does not exist. Please connect the correct storage."
        exit 1;
    else
        echo " |--> sdc exists; checking size..." 
        if [ $drive2size -gt 499 ]; then
            echo " |--> Drive size acceptable: $drive1size"
        else
            echo " |--x Please increase the size of sdc and try again. Exiting."
            exit 1;
        fi
    fi
    

}

checkLSBLK() {

    echo "[+] Checking for /var/lib/rancher/k3s"
    lsblk | grep "rancher/k3s"
    if [ $? -eq 1 ]; then
        echo " |--> /var/lib/ranger/k3s does not exist. Attempting to create..."
        sudo su
        checkSuccess " |--> Successful change to root user..." " |--x Unsuccessful change to root. Exiting."

        echo " |--> Attempting to mkdir -p /var/lib/rancher/k3s..."
        mkdir -p /var/lib/rancher/k3s
        checkSuccess " |--> Directory successfully created." " |--x Unsuccessful creation of directory."

        mkfs.xfs /dev/sdb
    else 
        lsblk | grep "edge/storage" | cut -d " " -f12 | cut -d "G" -f1

    fi

    lsblk | grep "edge/storage"

}

main() {

    checkSEstatus
    checkDriveSizes


}

main