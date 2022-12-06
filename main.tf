variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_name" {}
variable "private_key_path" {}
provider "aws" {
  region = "eu-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  default_tags {
    tags = {
      hashicorp-learn = "aws-asg"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-ebs"]
  }
}
   






resource "aws_launch_configuration" "terramino" {

  name_prefix     = "learn-terraform-aws-asg-"
  image_id        = data.aws_ami.amazon-linux.id
  instance_type   = "t2.micro"
  user_data       = file("user-data.sh")

  lifecycle {
    create_before_destroy = true
  }
}



data "aws_subnet_ids" "example" {
  vpc_id = module.vpc.vpc_id
}
data "aws_subnet" "example" {
  for_each = toset(data.aws_subnet_ids.example.ids)
  id       = each.value
}




resource "aws_autoscaling_group" "terramino" {
  
  name                 = "terramino"
  min_size             = 1
  max_size             = 4
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.terramino.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "Devops"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_schedule" "terramino-up" {
  scheduled_action_name  = "terramino-up"
  min_size = 1
  max_size = 4
  desired_capacity = 2
  recurrence = "00 18 * * 1-5"
  autoscaling_group_name = aws_autoscaling_group.terramino.name
}

resource "aws_autoscaling_schedule" "terramino-down" {
  scheduled_action_name  = "terramino -down"
  min_size = 1
  max_size = 4
  desired_capacity = 1
  recurrence = "00 08 * * 1-5"
  autoscaling_group_name = aws_autoscaling_group.terramino.name
}



resource "aws_lb" "front_end" {
  name               = "basic-load-balancer"
  load_balancer_type = "network"
  subnets =  ["${element(module.vpc.public_subnets, 0)}"]
  enable_cross_zone_load_balancing = true
  timeouts {
    create = "10m"
    delete = "10m"
  }
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn

  protocol          = "TCP"
  port = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_target_group" "front_end" {
  port        = 31555
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id


  depends_on = [
    aws_lb.front_end
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "target" {
  autoscaling_group_name = aws_autoscaling_group.terramino.name
  alb_target_group_arn   = aws_lb_target_group.front_end.arn
}