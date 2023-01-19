terraform {
    backend "s3" {
    bucket = "vabram-devops-dir-tfstate"
    key = "tf-infra/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "vabram-devops-state-locking"
    encrypt = true
  }

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "vabram-devops-dir-tfstate"
    force_destroy = true
    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

resource "aws_dynamodb_table" "terraform_locks" {
    name = "vabram-devops-state-locking"
    read_capacity  = 5
    write_capacity = 5
    hash_key       = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

resource "aws_security_group" "elb-sg" {
  name = "elb-sg"
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    description = "ALL TRAFFIC"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
   }
}

resource "aws_instance" "web_server1" {
  ami = "ami-08c40ec9ead489470"
  instance_type = "t2.micro"
  security_groups = [ "${aws_security_group.elb-sg.name}" ]
  availability_zone = "us-east-1a"
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
  EOF
}

resource "aws_instance" "web_server2" {
  ami = "ami-08c40ec9ead489470"
  instance_type = "t2.micro"
  security_groups = [ "${aws_security_group.elb-sg.name}" ]
  availability_zone = "us-east-1b"
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
  EOF
}

resource "aws_elb" "bar" {
  name = "vabram-classic-elb"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval            = 10
  }

  instances = [aws_instance.web_server1.id, aws_instance.web_server2.id]
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400
}