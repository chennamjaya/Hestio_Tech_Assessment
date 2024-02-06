provider "aws" {
  region = var.region 
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnets)
  vpc_id           = aws_vpc.main.id
  cidr_block       = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true  # This ensures instances in the public subnet get public IPs
  tags = {
    Name = "public-subnets-${count.index}"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnets)
  vpc_id           = aws_vpc.main.id
  cidr_block       = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "private-subnets-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_eip" "ngw" {
  domain   = "vpc"
  tags = {
    Name = "${var.env}-ngw"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "${var.env}-ngw"
  }
}

resource "aws_instance" "public_vm" {
  ami             = "ami-03265a0778a880afb"  # Specify the AMI ID for your public VM
  instance_type   = "t2.micro"  # Adjust instance type as needed
  subnet_id       = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = ["${aws_security_group.public.id}"]
}

resource "aws_instance" "private_vm" {
  ami             = "ami-03265a0778a880afb"  # Specify the AMI ID for your private VM
  instance_type   = "t2.micro"  # Adjust instance type as needed
  subnet_id       = aws_subnet.private_subnets[0].id
  vpc_security_group_ids = ["${aws_security_group.private.id}"]
}

resource "aws_security_group" "security_group" {
  name        = "${var.env}-${var.alb_type}-sg"
  description = "${var.env}-${var.alb_type}-sg"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.alb_sg_allow_cidr]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.alb_sg_allow_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-${var.alb_type}-sg"
  }
}

resource "aws_iam_role" "role" {
  name = "${var.env}-${var.component}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.env}-${var.component}-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
         "Sid": "VisualEditor0",
			   "Effect": "Allow",
			   "Action": [
           "kms:Decrypt",
				   "ssm:DescribeParameters",
           "ssm:GetParameterHistory",
				   "ssm:GetParametersByPath",
				   "ssm:GetParameters",
           "ssm:GetParameter"
			  ],
          Resource = "*"
        },
      ]
    })
  }


  tags = {
    tag-key = "${var.env}-${var.component}-role"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.env}-${var.component}-role"
  role = aws_iam_role.role.name
}

resource "aws_lb" "alb" {
  name               = "${var.env}-${var.alb_type}"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = var.subnets
  tags = {
    Environment = "${var.env}-${var.alb_type}"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.env}-${var.component}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  deregistration_delay = 30
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 5
    unhealthy_threshold = 2
    port                = var.app_port
    path                = "/health"
    timeout             = 3
  }
}

resource "aws_lb_listener" "listener-http-public" {
  count             = var.alb_type == "public" ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "listener-http-private" {
  count             = var.alb_type == "private" ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.tg_arn
  }
}


resource "aws_lb_listener" "listener-https" {
  count             = var.alb_type == "public" ? 1 : 0 #it should run if count is one which is public
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:851512651356:certificate/693cd3c7-3ef9-41d6-8acf-97ad07cce2c2"

  default_action {
    type             = "forward"
    target_group_arn = var.tg_arn
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_route" {
  route_table_id                = aws_route_table.private.id
  destination_cidr_block        = "0.0.0.0/0"
  nat_gateway_id                = aws_nat_gateway.ngw.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private.id
}
