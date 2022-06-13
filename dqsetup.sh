#!/bin/bash

# ------------------------------------------------------------------------------------------------
# Edit these variables for your installation.
# The latest version link can be copied from:
# https://engineering-collibra.atlassian.net/wiki/spaces/DQ/pages/15251636954/Product+Download+Links+-+Collibra+DQ
# A new link is released every 7 days due to signing issues with AWS.
#url="https://owl-packages.s3.amazonaws.com/owl-2022.04-SPARK301-package-full.tar.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAQM6KV6N26JCTUC77%2F20220502%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20220502T135634Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=cbd83c8ccea3519361b28f6fa763afeff0cdd56c191d0df0687175e8e4fd6c1b"
licenseKey="HKHZYKTKY18QKVDJAW9MDPJXZI9KKKAZFNNXOO8C90ZVP8GD:92F30DHC40NP3NJVC8XBFEHEXN4YSRHOIYFRDAXU4426HAOT:65536"

# The following will be the postgres username and password used during setup.
postgresUsername="pguser"
postgresPassword="dataQuality12!"

# This will be the DQ user and location it is created. /home/<username> 
env1="/home/collibradq"
userPass="Collibra123!"
# ------------------------------------------------------------------------------------------------

# Do not edit these variables. They are calculated based on various inputs.
createUserName=$(echo "$env1" | cut -d "/" -f3)
privIPAddress=""#$(ip route | awk -F "src " '{ print $2 }' | cut -d " " -f1)
pubIPAddress=""#$(curl -s ifconfig.co)  


export OWL_BASE="$env1"
export OWL_METASTORE_USER="$postgresUsername"
export OWL_METASTORE_PASS="$postgresPassword"

#echo $OWL_BASE
#echo $OWL_METASTORE_USER
#echo $OWL_METASTORE_PASS
#echo $SPARK_HOME

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

checkAndMakeUser() {
    # Check if the user 'owldq' exists. This user is the recommended user by the devs.
    # This check works by seeing if there is a UID for 'owldq' and checks success or failur of the command.

    echo "[!] Checking for user '$createUserName'..."
    id -u $createUserName &>/dev/null

    if [ $? -eq 0 ]; then
        echo "[!] '$createUserName' user already exists. Skipping account creation process."
    else
        echo "[+] Creating user '$createUserName'"
        sudo adduser -d $env1 -s /bin/bash -p $userPass $createUserName
        checkSuccess "[+] Successfully added."  "[-] Failed adding user."
    fi
}

fileHandler() {

    # Change to the owldq home directory to ensure files are unzipped in the proper place.
    echo "[+] Changing to '$createUserName' home directory ($env1)"

    # Testing purposes only. Comment out the next line for demos.
    cp owl-2022.06-SPARK301-package-full.tar.gz $env1

    cd $env1
    checkSuccess "[+] Change to $env1 successful." "[-] Folder does not exist!"

    # Download the Collibra DQ file from the link provided.
    ##echo "[+] Downloading the latest version of software from the provided link."
    #########curl "$url" > pack.tar.gz
    #########checkSuccess "[+] Successfully downloaded the file." "[-] Download unsuccessful."

    #chmod 755 pack.tar.gz
    tar -xvf owl-2022.06-SPARK301-package-full.tar.gz --overwrite
    
}

installSoftware() {
    # These are the environment variables that the devs used for creation of their install script.
    # This script gathers all the necessary information and guides the user through what would
    # otherwise be a lengthy and tedious process. Really, how many non-programmers know how to set environment variables??
    ./setup.sh -owlbase=$OWL_BASE -user=$OWL_METASTORE_USER -pgpassword=$OWL_METASTORE_PASS -options=postgres,spark,owlweb,owlagent
    
    # echo "$OWL_BASE"

    touch $env1/owl/config/agent.properties 
	echo "agentid=2" > $env1/owl/config/agent.properties
}

verifySpark() {

    # Check local address then public address for the spark server then displays address.
    # Success indicates server is running.
    echo "[!] Checking spark..."
    sparkAddr=$(curl -s --connect-timeout 10 http://$privIPAddress:8080/ | grep URL | cut -d " " -f16 | cut -d "<" -f1)
    checkSuccessNoExit "[+] Spark is running locally; your master spark address is: $sparkAddr" "[-] Spark is not running at a local address."
    sparkAddr=$(curl -s --connect-timeout 10 http://$pubIPAddress:8080/ | grep URL | cut -d " " -f16 | cut -d "<" -f1)
    checkSuccessNoExit "[+] Spark is running in the cloud; your master spark address is: $sparkAddr" "[-] Spark is not running at a public address."

}

verifyWebApp() {

    echo "[!] Wait 1-2 minutes for the webserver to start."
	echo " |-- If this is a local install go to"$privIPAddress":9000"
	echo " |-- If this is a remote install go to "$pubIPAddress":9000"
	echo " |-- Enter the credentials: admin/admin123 and click OK if prompted."
}

updateSetupScripts() {

    echo "[+] Updating setup.sh for latest version of spark..."
    awk '{gsub("spark-3.0.1-bin-hadoop3.2.tgz","spark-*-bin-hadoop*.tgz"); print}' $env1/setup.sh > $env1/setup2.sh
    checkSuccess "[+] setup.sh successfully changed." "Failure!"
    cp $env1/setup2.sh $env1/setup.sh; rm $env1/setup2.sh
}

main() {

    #echo $1

    # This is for a local install only. For cloud instances, you will need to allow traffic
    #   in your firewall settings for the instance.
	# Open port 9000 for the DQ web app and 8080 for the Spark server.
	 sudo firewall-cmd --zone=public --add-port=9000/tcp --permanent
	 sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
     sudo firewall-cmd --reload

    # Step 1 is creating the VM to install on in the directions.
    # It is omitted here.

    # Step 2
    checkAndMakeUser
    fileHandler
	updateSetupScripts

    # Step 3 in install directions.
    # Step 4 is similar, but not relevant to this version of installation.
    installSoftware

    # Step 5 is handled at the end of the script after things have had time to start up.
    
    # Step 6 in install directions
	echo "[+] Entering license key..."
	$env1/owl/bin/owlmanage.sh setlic=$licenseKey

    # Step 7 in install directions
	echo "[+] Starting OwlAgent."
	$env1/owl/bin/owlmanage.sh start=owlagent
    $env1/owl/bin/owlmanage.sh stop=owlagent


	echo "[+] Verifying agent.properties file."
	ls $env1/owl/config/agent.properties
	checkSuccess "[+] File exists. Continuing." "[-] File does not exist. Exiting."
    echo "sparksubmitmode=native" >> $env1/owl/config/agent.properties
    echo "sparkhome=$env/owl/spark" >> $env1/owl/config/agent.properties

    $env1/owl/bin/owlmanage.sh start

    verifySpark
}

main

#EOF
