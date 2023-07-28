provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy = "default"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "eu-west-2${element(["a", "b", "c"], count.index)}"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

################################################################

resource "aws_lb" "ecs_lb" {
  name               = "arsit-ecs-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.load_balancer_security_group.id]
}

resource "aws_lb_target_group" "ecs_target_group" {
  name     = "arsit-ecs-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
  healthy_threshold   = "3"
  interval            = "300"
  protocol            = "HTTP"
  matcher             = "200"
  timeout             = "3"
  path                = "/v1/status"
  unhealthy_threshold = "2"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.ecs_lb.id
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.id
  }
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port        = 8000
    to_port          = 8000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


################################################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_full_access_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.cluster_name
}


resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "arsit-ecs-task"
  container_definitions    = jsonencode([
    {
      "name": "arsit-container",
      "image": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:${var.ecr_image_tag}",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "hostPort": 8000
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "ecs_service" {
  name            = "arsit-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count   = 1
   force_new_deployment = true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets = aws_subnet.public.*.id
    assign_public_ip = true
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "arsit-container"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.listener]
}
