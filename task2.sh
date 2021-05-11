#!/bin/bash 

date=$(date +"%F")
time=$(date +"%T")
mkdir -p task2logs$date
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"task2logs$date/log$time.out" 2>&1

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )


pem="sample_application_1.pem"

#get the compressed file from the server to the location of the executed script 
command=sudo scp -r -i $pem  ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com:/home/ubuntu/backup.zip "$parent_path/backup"

if [[ $command -eq 1 ]]; then
    echo "remote file has not been copied to the local folder"
    #since the statement only works if mailutils is configured properly it has been commented
    #mail -s 'Critical failure' username@gmail.com <<< 'There was a problem copying the file from the server to the local machine'
fi

#upload file to s3 bucket
aws s3 cp "$parent_path/backup/backup.zip" s3://sample-application-assignment/

#check whether the statement executed successfully 
if [[ $? -eq 0 ]]; then
    #remove file after successful upload
    echo -e "upload successful"
    rm "$parent_path/backup/backup.zip"
else
    echo -e "The upload was a failure"
    #mail -s 'Upload Fail' username@gmail.com <<< 'The file was not uploaded to s3'
fi

#backs up all the logs to server
scp -r -i $pem "task2logs$date/log$time.out" ubuntu@ec2-3-142-213-46.us-east-2.compute.amazonaws.com:/home/ubuntu/logs/task2logs
