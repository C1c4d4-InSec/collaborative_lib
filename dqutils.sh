#!/bin/bash

dqutil_out="dqutil_out_$(date "+%Y%m%d-%H%M%S")"
owlhome=$(grep "BASE_PATH" $(find / -iname "owl-env.sh" 2>/dev/null) | cut -d "\"" -f2)
pubIPAddress=$(curl -m 5 ifconfig.co)

dq_restart() {

    $owlhome/owl/bin/owlmanage.sh restart >> $dqutil_out 2>&1
    $owlhome/owl/bin/owlmanage.sh start=owlagent >> $dqutil_out 2>&1

}

dq_persistence() {

    echo "" | tee -a $dqutil_out
    echo "  DQ Persistence" | tee -a $dqutil_out
    echo "------------------------------------------------------------------" | tee -a $dqutil_out

    if [ -z "$(sudo crontab -l 2>/dev/null | grep "@reboot sh $owlhome/startup.sh")" ]; then
        echo "| Adding cron job for startup script."
        sudo su<<EOM
            echo "@reboot sh $owlhome/startup.sh") | crontab -
EOM
        echo "|> Done"
    else
        echo "| Cron job already exists."
    fi

    echo "| Creating $owlhome/startup.sh"
    echo "#!/bin/bash" > $owlhome/.startup.sh
    echo "sudo $owlhome/owl/bin/owlmanage.sh start" >> $owlhome/startup.sh
    echo "sudo $owlhome/owl/bin/owlmanage.sh start=owlagent" >> $owlhome/startup.sh
    echo "sudo $owlhome/owl/spark/sbin/start-master.sh" >> $owlhome/startup.sh
    echo "sudo $owlhome/owl/spark/sbin/start-slave.sh spark://$HOSTNAME:7077" >> $owlhome/startup.sh

    chmod +x startup.sh

    echo "------------------------------------------------------------------" | tee -a $dqutil_out

}

dq_tls() {

    # Create self-signed certificate
    #https://www.sslshopper.com/article-how-to-create-a-self-signed-certificate-using-java-keytool.html

    # Set up a keystore
    #https://www.sslshopper.com/article-most-common-java-keytool-keystore-commands.html

    # TLS enable on DQ server
    #https://dq-docs.collibra.com/security/configuration/ssl-setup-https

    oldKeystoreHash=$(cat $owlhome/owl/config/owl-env.sh | grep "#export SERVER_SSL_KEY_PASS" | cut -d '=' -f2-)
    newKeystorePass=""

    echo "" | tee -a $dqutil_out
    echo "  Enable HTTPS" | tee -a $dqutil_out
    echo "------------------------------------------------------------------" | tee -a $dqutil_out

    while true;
    do
        echo "| Enter new keystore password: " | tee -a $dqutil_out
        read -s kspass1
        echo "| Re-enter new keystore password:"  | tee -a $dqutil_out
        read -s kspass2

        if [ $kspass1 == $kspass2 ]; then
            newKeystorePass="$kspass1"
            echo "|> Password accepted."  | tee -a $dqutil_out
            break
        else
            echo "|x Passwords don't match. Please retry." | tee -a $dqutil_out
        fi
    done

    newKeystoreHash=$($owlhome/owl/bin/owlmanage.sh encrypt=$newKeystorePass)
    cd $owlhome
    echo | sudo keytool -genkey -keyalg RSA -alias selfsigned -dname "CN=DQ,OU=SE,O=Collibra,L=NY,S=NY,C=US" -keystore dqkeystore.jks -storepass $newKeystorePass -validity 360 -keysize 2048 >> $dqutil_out 2>&1

    sed -i 's|#export SERVER_HTTP_ENABLED=false|export SERVER_HTTP_ENABLED=false|' $owlhome/owl/config/owl-env.sh
    sed -i 's|#export SERVER_HTTPS_ENABLED=true|export SERVER_HTTPS_ENABLED=true|' $owlhome/owl/config/owl-env.sh
    sed -i 's|#export SERVER_SSL_KEY_TYPE=PKCS12|export SERVER_SSL_KEY_TYPE=JKS|' $owlhome/owl/config/owl-env.sh
    sed -i 's|#export SERVER_SSL_KEY_STORE='$owlhome'/owl/keystoredsktp.p12|export SERVER_SSL_KEY_STORE='$owlhome'/dqkeystore.jks|' $owlhome/owl/config/owl-env.sh
    sed -i 's|#export SERVER_SSL_KEY_PASS='$oldKeystoreHash'|export SERVER_SSL_KEY_PASS='$newKeystoreHash'|' $owlhome/owl/config/owl-env.sh
    sed -i 's|#export SERVER_SSL_KEY_ALIAS=owl|export SERVER_SSL_KEY_ALIAS=selfsigned|' $owlhome/owl/config/owl-env.sh

    echo "export SERVER_REQUIRE_SSL=true" >> $owlhome/owl/config/owl-env.sh

    echo "| You may now access your DQ instance at:" | tee -a $dqutil_out
    echo "|     https://$pubIPAddress:9000" | tee -a $dqutil_out
    echo "------------------------------------------------------------------" | tee -a $dqutil_out

}

dq_postgresPassChange(){

    oldPostgresHash=$(cat $owlhome/owl/config/owl-env.sh | grep "export SPRING_DATASOURCE_PASSWORD" | cut -d "=" -f2-)
    newPostgresPass=""

    echo "" | tee -a $dqutil_out
    echo "  Postgres Default Password Change" | tee -a $dqutil_out
    echo "------------------------------------------------------------------" | tee -a $dqutil_out

    while true;
    do
        echo "| Enter new password: " | tee -a $dqutil_out
        read -s pgpass1
        echo "| Re-enter new password:"  | tee -a $dqutil_out
        read -s pgpass2

        if [ $pgpass1 == $pgpass2 ]; then
            newPostgresPass="$pgpass1"
            echo "|> Password accepted."  | tee -a $dqutil_out
            break
        else
            echo "|x Passwords don't match. Please retry." | tee -a $dqutil_out
        fi
    done

    echo "| Changing postgres password." | tee -a $dqutil_out
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$newPostgresPass';" >> $dqutil_out 2>&1
    echo "|> Done" | tee -a $dqutil_out

    echo "| Hashing new postgres password; editing owl-env.sh and owl.properties files." | tee -a $dqutil_out
    newPostgresHash=$($owlhome/owl/bin/owlmanage.sh encrypt=$newPostgresPass) 
    sed -i 's|export SPRING_DATASOURCE_PASSWORD='$oldPostgresHash'|export SPRING_DATASOURCE_PASSWORD='$newPostgresHash'|' $owlhome/owl/config/owl-env.sh
    sed -i 's|spring.datasource.password='$oldPostgresHash'|spring.datasource.password='$newPostgresHash'|' $owlhome/owl/config/owl.properties
    sed -i 's|spring.agent.datasource.password='$oldPostgresHash'|spring.agent.datasource.password='$newPostgresHash'|' $owlhome/owl/config/owl.properties
    echo "|> Done" | tee -a $dqutil_out

    echo "| Restarting postgres server."  | tee -a $dqutil_out
    $owlhome/owl/bin/owlmanage.sh restart=postgres >> $dqutil_out 2>&1
    echo "|> Done" | tee -a $dqutil_out

    echo "------------------------------------------------------------------" | tee -a $dqutil_out

}

main() {

    dq_persistence
    dq_tls
    dq_postgresPassChange
    dq_restart

}

main