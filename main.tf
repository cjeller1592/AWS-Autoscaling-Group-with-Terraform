provider "aws" {
    region = "us-east-2"
} 

resource "aws_launch_template" "foobar" {
  name_prefix   = "foobar"
  image_id      = "ami-09558250a3419e7d0"
  instance_type = "t2.micro"
  key_name      = "my-key-pair"
}

resource "aws_autoscaling_group" "bar" {
  availability_zones = ["us-east-2a", "us-east-2b"]
  desired_capacity   = 1
  max_size           = 5
  min_size           = 1

  launch_template {
    id      = aws_launch_template.foobar.id
    version = "$Latest"
  }

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

}

resource "aws_autoscalingplans_scaling_plan" "example" {
  name = "example-predictive-cost-optimization"

  application_source {
    tag_filter {
      key    = "application"
      values = ["example"]
    }
  }

scaling_instruction {
  #  disable_dynamic_scaling = true

    max_capacity       = 5
    min_capacity       = 1
    resource_id        = format("autoScalingGroup/%s", aws_autoscaling_group.bar.name)
    scalable_dimension = "autoscaling:autoScalingGroup:DesiredCapacity"
    service_namespace  = "autoscaling"

    target_tracking_configuration {
      predefined_scaling_metric_specification {
        predefined_scaling_metric_type = "ASGAverageCPUUtilization"
      }

      target_value = 5
    }

    predictive_scaling_max_capacity_behavior = "SetForecastCapacityToMaxCapacity"
    predictive_scaling_mode                  = "ForecastAndScale"

    predefined_load_metric_specification {
      predefined_load_metric_type = "ASGTotalCPUUtilization"
    }
  }
}

output "ec2_ip" {
  description = "IP address for EC2 instance in the Auto Scaling group"
  value = aws_autoscaling_group.bar
}