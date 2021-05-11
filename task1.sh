#!/bin/bash 

date=$(date +"%F")
time=$(date +"%T")
mkdir -p task1logs$date
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"task1logs$date/log$time.out" 2>&1

#variables needed for the execution of statements 
pem="sample_application_1.pem"
mysql="false"
nginx="false"

#run command to ensure the key is not publicly viewable
chmod 400 sample_application_1.pem

#execute mysql statement to register the connection and its timestamp
$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com 'sudo docker exec -i mysql1 mysql -uroot -ppassword sample_application << EOF
INSERT INTO application_tbl (\`result\`, \`timestamp\`) VALUES ("connected", "$(date)");
EOF')

#get the list of running containers
command=$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com 'sudo docker container ls' > SomeFile.txt)
images=$(awk '{if(NR>1) print $2}' SomeFile.txt)

#for loop to check if the required docker images have been setup 
for image in $images
do
    echo -e $image
    if [[ $image = 'sample-application' ]]; then
        let nginx="true"
    elif [[ $image = 'mysql/mysql-server:latest' ]]; then
        let mysql="true"
    fi 
done

command2=$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com 'sudo docker container ls -a' > SomeFile2.txt)
containers=$(awk '{if(NR>1) print $1}' SomeFile2.txt)

#starts the nginx and mysql server if it has been shutdown
if [[ $nginx = 'false' || $mysql = 'false' ]]; then 
    for container in $containers
    do
        echo -e $container
        statement='sudo docker start '"$container"
        echo -e $statement
        execute=$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com $statement)

        register=$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com 'sudo docker exec -i mysql1 mysql -uroot -ppassword sample_application << EOF
        INSERT INTO application_tbl (\`result\`, \`timestamp\`) VALUES ("server started", "$(date)");
        EOF')

        if [[ $register -eq 1 ]]; then
            echo "The mysql statement to register the result has failed"
            #since the statement only works if mailutils is configured properly it has been commented
            #mail -s 'Mysql Failure' username@gmail.com <<< 'The result has not been uploaded to the virtual database'
        fi
    done        
fi

#checks if the web server is up 
http_response=$(curl -s -o response.txt -w "%{http_code}" http://3.142.213.46/)
if [ $http_response != "200" ]; then
    echo "server is not up"

    #since the statement only works if mailutils is configured properly it has been commented
    #mail -s 'Server Failure' username@gmail.com <<< 'The server cannot be identified from the known hosts please check of the server is up'

    register2=$(yes y |ssh -i $pem ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com 'sudo docker exec -i mysql1 mysql -uroot -ppassword sample_application << EOF
        INSERT INTO application_tbl (\`result\`, \`timestamp\`) VALUES ("web server is not active", "$(date)");
        EOF')
    if [[ $register -eq 1 ]]; then
            echo "The mysql statement to register the result has failed"

            #since the statement only works if mailutils is configured properly it has been commented
            #mail -s 'Mysql Failure' username@gmail.com <<< 'The result has not been uploaded to the virtual database'
    fi
else
    echo "Server returned:"
    cat response.txt    
fi

#backs up all the logs to server
scp -r -i $pem "task1logs$date/log$time.out" ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com:/home/ubuntu/logs/task1logs