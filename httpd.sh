#!/bin/bash
sudo yum update -y
sudo yum install httpd -y
echo "hello world from $(hostname -f)" > /var/www/html/index.html
sudo systemctl enable httpd
sudo systemctl start httpd