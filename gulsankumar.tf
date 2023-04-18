First we have to launch an linux ec2 instance in AWS.
Next step is to log in by using terminal or putty tool.
Then Download Terraform using webget command.
Then move Terraform file in the path of /usr/local/bin by using command of mv Terraform /usr/local/bin
After that we have to create a file in the name of main.tf by using vim editor and copy the below script & paste.
After paste the script,the following commands are used to perform the operation.
1. terraform init
2. terraform plan - this command checks the script
3. terraform apply - this command used to build the infra in AWS
4. terraform destroy - it will delete all the creation from AWS infrastructure.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "Access Key"
  secret_key = "Secret Access Key"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "My-Vpc"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public-Subnet"
  }
}

resource "aws_subnet" "prisub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "Private-Subnet"
  }
}

resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "My-Internet-Gateway"
  }
}

resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "Public-Routetable"
  }
}

resource "aws_main_route_table_association" "publicrtassociation" {
  vpc_id         = aws_vpc.myvpc.id
  route_table_id = aws_route_table.pubrt.id
}

resource "aws_eip" "myeip" {
  vpc      = true
}

resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "My-Nat-Gateway"
  }

}

resource "aws_route_table" "prirt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mynat.id
  }


  tags = {
    Name = "Private-Routetable"
  }
}

resource "aws_main_route_table_association" "privateroutetableassociation" {
  vpc_id         = aws_vpc.myvpc.id
  route_table_id = aws_route_table.prirt.id
}

resource "aws_security_group" "pubsg" {
  name        = "pubsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Public-Security-Group"
  }
}

resource "aws_security_group" "prisg" {
  name        = "prisg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Private-Security-Group"
  }
}

resource "aws_db_instance" "wordpress_db" {
  engine                 = "mysql"
  engine_version         = "8.0.21"
  instance_class         = "db.t4g.micro"
  name                   = "wordpress"
  username               = "admin"
  password               = "admin123"
  parameter_group_name   = "default.mysql8.0"
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.alltcp.id]

  tags = {
    Name = "WordPress Database"
  }
}


resource "aws_instance" "wordpress_instance" {
  ami                                             = "ami-069aabeee6f53e7bf"
  instance_type                                   = "t4g.small"
  availability_zone                               = "us-east-1a"
  associate_public_ip_address                     = "true"
  vpc_security_group_ids                          = [aws_security_group.pubsg.id]
  subnet_id                                       = aws_subnet.pubsub.id 
  key_name                                        = "linux-virginia"
  user_data                                       = <<-EOF
                                                    #!/bin/bash
                                                    sudo yum update -y
                                                    sudo yum install docker -y
                                                    sudo service docker start
                                                    sudo docker run -itd --name word_app -p "80:80" wordpress
                                                    EOF  
    tags = {
    Name = "wordpress-Server"
  }
}

resource "aws_eip" "elasticip" {
  instance = aws_instance.wordpress_instance.id
  vpc      = true
}

resource "aws_route53_zone" "gkcloudengineer" {
  name = "gkcloudengineer.cloud"
}

resource "aws_route53_record" "gkcloudengineer" {
  zone_id = aws_route53_zone.gkcloudengineer.zone_id
  name    = "www.gkcloudengineer.cloud"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.gkcloudengineer.elasticip]
}


resource "aws_instance" "Db_instance" {
  ami                                             = "ami-069aabeee6f53e7bf"
  instance_type                                   = "t4g.micro"
  availability_zone                               = "us-east-1b"
  associate_public_ip_address                     = "false"
  vpc_security_group_ids                          = [aws_security_group.prisg.id]
  subnet_id                                       = aws_subnet.prisub.id 
  key_name                                        = "linux-virginia"
  user_data                                       = <<-EOF
                                                    #!/bin/bash
                                                    yum update -y
                                                    sudo yum install mysql -y
                                                    sudo mysql -h ${aws_rds_instance.wordpress_db.endpoint} -P 3306 -u ${var.db_username} -p${var.db_password} -e "SHOW DATABASES;"

    tags = {
    Name = "Database-Server"
  }
}
