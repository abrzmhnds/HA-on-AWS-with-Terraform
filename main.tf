resource "aws_vpc" "terraformVPC" {
  cidr_block           = "172.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "terraformVPC"
  }
}

resource "aws_internet_gateway" "terraformIGW" {
  vpc_id = aws_vpc.terraformVPC.id

  tags = {
    Name = "terraformIGW"
  }
}

resource "aws_route_table" "terraformRT" {
  vpc_id = aws_vpc.terraformVPC.id

  tags = {
    Name = "terraformRT"
  }
}

resource "aws_route" "terraformRoute" {
  route_table_id         = aws_route_table.terraformRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.terraformIGW.id
}

resource "aws_main_route_table_association" "terraformMainRTAssoc" {
  vpc_id         = aws_vpc.terraformVPC.id
  route_table_id = aws_route_table.terraformRT.id
}

resource "aws_subnet" "terraformPublicSubnetA" {
  vpc_id                  = aws_vpc.terraformVPC.id
  cidr_block              = "172.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraformPublicSubnetA"
  }
}

resource "aws_subnet" "terraformPublicSubnetB" {
  vpc_id                  = aws_vpc.terraformVPC.id
  cidr_block              = "172.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraformPublicSubnetB"
  }
}

resource "aws_subnet" "terraformPublicSubnetC" {
  vpc_id                  = aws_vpc.terraformVPC.id
  cidr_block              = "172.0.2.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraformPublicSubnetC"
  }
}

resource "aws_route_table_association" "terraformRTAssocA" {
  subnet_id      = aws_subnet.terraformPublicSubnetA.id
  route_table_id = aws_route_table.terraformRT.id
}

resource "aws_route_table_association" "terraformRTAssocB" {
  subnet_id      = aws_subnet.terraformPublicSubnetB.id
  route_table_id = aws_route_table.terraformRT.id
}

resource "aws_route_table_association" "terraformRTAssocC" {
  subnet_id      = aws_subnet.terraformPublicSubnetC.id
  route_table_id = aws_route_table.terraformRT.id
}

resource "aws_security_group" "terraformSG" {
  name        = "allow HTTP"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.terraformVPC.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
    ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PING from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}
resource "aws_lb" "terraformALB" {
  name               = "terraformALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraformSG.id]
  subnets            = [aws_subnet.terraformPublicSubnetA.id, aws_subnet.terraformPublicSubnetB.id, aws_subnet.terraformPublicSubnetC.id]
}

resource "aws_lb_target_group" "terraformTG" {
  name     = "terraformTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraformVPC.id

}

resource "aws_alb_listener" "terraformALBListener" {
  load_balancer_arn = aws_lb.terraformALB.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraformTG.arn
  }
}

resource "aws_key_pair" "ec2-example-ssh-key" {
  key_name   = "ec2-example-ssh-key"
  public_key = "${file(var.public_key_file)}"
}

resource "aws_launch_template" "terraformLT" {
  name            = "terraformLT"
  default_version = 1
  description     = "Launch template used for provisioning with Terraform"
  image_id        = data.aws_ami.std_ami.id
  instance_type   = "t2.micro"
  key_name = "${aws_key_pair.ec2-example-ssh-key.key_name}"
  user_data       = filebase64("${path.module}/httpd.sh")
  network_interfaces {
    subnet_id       = aws_subnet.terraformPublicSubnetA.id
    security_groups = [aws_security_group.terraformSG.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "terraformInstance"
    }
  }
}

resource "aws_autoscaling_group" "terraformASG" {
  name                = "terraformASG"
  vpc_zone_identifier = [aws_subnet.terraformPublicSubnetA.id, aws_subnet.terraformPublicSubnetB.id, aws_subnet.terraformPublicSubnetC.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 2

  launch_template {
    id      = aws_launch_template.terraformLT.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.terraformASG.id
  alb_target_group_arn   = aws_lb_target_group.terraformTG.arn
}
