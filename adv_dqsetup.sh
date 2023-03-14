#!/bin/bash
# ------------------------------------------------------------------------------------------------
# Edit these variables for your installation.
# The latest version link can be copied from:
# https://engineering-collibra.atlassian.net/wiki/spaces/DQ/pages/15251636954/Product+Download+Links+-+Collibra+DQ
# A new link is released every 7 days due to signing issues with AWS.
url=""
licenseKey=""

# The following will be the postgres username and password used during setup. Change on login with dqUtils.
postgresUsername=""
postgresPassword=""

# This will be the DQ user and location it is created. /home/<username>
# Log in weith username and userpass as necessary for service maintenance. 
# Change on login.
env1="/home/user"
userPass=""
# ------------------------------------------------------------------------------------------------

#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Do not edit these variables. They are calculated based on various inputs.
createUserName=$(echo "$env1" | cut -d "/" -f3)
privIPAddress=$(ip route | awk -F "src " '{ print $2 }' | cut -d " " -f1)
pubIPAddress=$(curl -s ifconfig.co)  

export OWL_BASE="$env1"
export OWL_METASTORE_USER="$postgresUsername"
export OWL_METASTORE_PASS="$postgresPassword"

#echo $OWL_BASE
#echo $OWL_METASTORE_USER
#echo $OWL_METASTORE_PASS
#echo $SPARK_HOME
#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

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

checkAndMakeUser() {

    # Check if the user 'owldq' exists. This user is the recommended user by the devs.
    # This check works by seeing if there is a UID for 'owldq' and checks success or failur of the command.
    id -u $createUserName &>/dev/null

    if [ $? -eq 0 ]; then
        echo "[!] '$createUserName' user already exists. Skipping account creation process."
    else
        echo "[+] Creating user '$createUserName'"
        sudo adduser -d $env1 -s /bin/bash -p $userPass $createUserName
        checkSuccess " |--> Successfully added."  " |--X Failed adding user."
    fi
}

fileHandler() {

    # Change to the owldq home directory to ensure files are unzipped in the proper place.
    echo "[+] Changing to '$createUserName' home directory ($env1)"

    # Testing purposes only. Comment out the next line for demos.
    cp pack05-2022.tar.gz $env1

    cd $env1
    checkSuccess " |--> Change to $env1 successful." " |--X Folder does not exist!"

    # Download the Collibra DQ file from the link provided.
    echo " |--> Downloading the latest version of software from the provided link."
    ##curl "$url" > pack.tar.gz
    ##checkSuccess "   !--> Successfully downloaded the file." "   !--X Download unsuccessful."

    #chmod 755 pack.tar.gz
    tar -xvf pack05-2022.tar.gz --overwrite
    
}

installSoftware() {
    # These are the environment variables that the devs used for creation of their install script.
    # This script gathers all the necessary information and guides the user through what would
    # otherwise be a lengthy and tedious process. Really, how many non-programmers know how to set environment variables??
    ./setup.sh -owlbase=$OWL_BASE -user=$OWL_METASTORE_USER -pgpassword=$OWL_METASTORE_PASS -options=postgres,spark,owlweb,owlagent
    
    # echo "$OWL_BASE"

    # Create the agent.properties file in case the setup script doesn't for some reason. Will be overwritten if it does.

    #!! Add logic to check if file exists and to create and add agent properties if it does not.
    touch $env1/owl/config/agent.properties 
	echo "agentid=2" > $env1/owl/config/agent.properties
}

verifySparkLocal() {
    # For local testing`
    # Check local address for the spark server and displays address, else check public address.
    # Logic: If curl errors out or sparkAddr is empty the server is not running. If it returns an address, spark server is working.

    sparkAddr=$(curl -s --connect-timeout 10 http://$privIPAddress:8080/ | grep URL | cut -d " " -f16 | cut -d "<" -f1)

    if [[ -z $sparkAddr ]]; then
        echo " |--X Spark is not running at a local address; checking public address..."
    else
        echo " |--> Spark is running locally; your master spark address is: $sparkAddr" 
    fi
}

verifySparkCloud() {

    # Same as above but checking at public address
    sparkAddr=$(curl -s --connect-timeout 10 http://$pubIPAddress:8080 | grep URL | cut -d " " -f16 | cut -d "<" -f1)

    if [[ -z $sparkAddr ]]; then
        echo " |--X Spark is not running at a public address; please troubleshoot and try again."
    else
        echo " |--> Spark is running; your master spark address is: $sparkAddr"
    fi
}

verifyWebAppLocal() {
    # For local testing
    # Dump contents of the login page into the variable. If the variable has a length > 0, the page exists, otherwise does not.
    # Check local address for the webapp.
    page=$(curl -s --connect-timeout 10 http://$privIPAddress:9000/login)

    if [[ -z $page ]]; then
        echo " |--X Web app is not running at a local address; checking public address..."
    else
        echo " |--> Web app is running locally at http://$privIPAddress:9000/login"
        echo "    |--> Please login with the credentials admin/admin123"
    fi
}

verifyWebAppCloud() {

    # Same as above but checking at public address.
    page=$(curl -s --connect-timeout 10 http://$pubIPAddress:9000/login)

    if [[ -z $page ]]; then
        echo " |--X Web app is not running at a public address; please troubleshoot and try again."
    else
        echo " |--> Web app is running at http://$pubIPAddress:9000/login"
        echo "    !--> Please login with the credentials admin/admin123"
    fi

}

updateSetupScripts() {

    # Updating the setup script so that it will install the version of Spark that it has.
    # The setup.sh script provided doesn't seem to have much luck finding it.
    awk '{gsub("spark-3.0.1-bin-hadoop3.2.tgz","spark-*-bin-hadoop*.tgz"); print}' $env1/setup.sh > $env1/setup2.sh
    checkSuccess " |--> setup.sh successfully changed." " |--X Could not change the setup script."
    cp $env1/setup2.sh $env1/setup.sh; rm $env1/setup2.sh
}

main() {

    # This is for a local install only. For cloud instances, you will need to allow traffic
    #   in your firewall settings for the instance.
	# Open port 9000 for the DQ web app and 8080 for the Spark server.
	 sudo firewall-cmd --zone=public --add-port=9000/tcp --permanent
	 sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
     sudo firewall-cmd --reload

    # Step 1 is creating the VM to install on in the directions.
    # It is omitted here.

    # Step 2
    echo "[+] Checking for user '$createUserName'..."
    checkAndMakeUser
    echo "[+] Downloading install file. (1.5GB)"
    fileHandler

    echo "[+] Updating setup.sh for latest version of spark..."
	updateSetupScripts

    # Step 3 in install directions.
    # Step 4 is similar, but not relevant to this version of installation.
    echo "[+] Commencing installation of DQ software."
    installSoftware

    # Step 5 is handled at the end of the script after things have had time to start up.
    # Reduces user confusion and requires fewer keystrokes.
	
    chmod 755 $env1/owlmanage.sh
    # Step 6 in install directions
    echo "[+] Entering license key..."
    sudo $env1/owlmanage.sh setlic=$licenseKey

    # Update owlmanage for the proper directories.
    echo "[+] Updating $env1/owlmanage.sh for current environment..."
    sed -i "s|\$binDir|$env1/owl|" $env1/owlmanage.sh
    sed -i "s|\$binDir|$env1/owl|" $env1/owl/bin/owlmanage.sh

    # Step 7 in install directions
	echo "[+] Starting OwlAgent..."
	sudo $env1/owlmanage.sh start=owlagent
    echo "[+] Stopping OwlAgent..."
    sudo $env1/owlmanage.sh stop=owlagent

    # Check for and ensure that the agent.properties file exists. Add the required information.
	echo "[+] Verifying agent.properties file..."
	ls $env1/owl/config/agent.properties
	checkSuccess " |--> File exists. Continuing." " |--X File does not exist. Exiting."
    echo " |--> Adding required lines to agent.properties file..."

    #!! Edit these to check for the occurence of the strings first before adding in the
    #!! event the script is run multiple times.
    echo "sparksubmitmode=native" >> $env1/owl/config/agent.properties
    echo "sparkhome=$env/owl/spark" >> $env1/owl/config/agent.properties

    # Start all the services.
    echo "[+] Starting services..."
    sudo $env1/owlmanage.sh start

    # Step 5, verify that the spark server and web app are operating.
    echo "[+] Checking spark server and webapp..."
    verifySparkCloud
    verifyWebAppCloud
}

main

#EOF
