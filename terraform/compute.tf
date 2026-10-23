data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_bucket   = aws_s3_bucket.app.id
    secret_id    = aws_secretsmanager_secret.db.arn
    region       = var.aws_region
    environment  = var.environment
    release_hash = md5("${filemd5("${path.module}/../app/app.py")}${filemd5("${path.module}/../app/requirements.txt")}")
  })
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]
  user_data              = base64encode(local.user_data)

  # IMDSv2 only.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true # encryption at rest
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app" }
  }

  # Instances need the artifacts and the secret value before they boot.
  depends_on = [
    aws_s3_object.app_py,
    aws_s3_object.requirements,
    aws_secretsmanager_secret_version.db,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.private[*].id

  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Roll instances automatically when the launch template (i.e. app release) changes.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  depends_on = [aws_nat_gateway.main, aws_db_instance.main]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
