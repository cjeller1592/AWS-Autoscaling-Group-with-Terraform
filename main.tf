provider "aws" {
  region = "us-east-2"
}

# Creating the SNS topic for our Autoscaling group
# This will allow us to receive notifications as the group adds machines to deal with the load

resource "aws_sns_topic" "autoscale_updates" {
  name = "autoscale-updates-topic"
  delivery_policy = <<EOF
  {
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

# Creating the SQS queue

resource "aws_sqs_queue" "autoscale_updates_queue" {
  name = "autoscale-updates-queue"
}

# Creating the queue policy for SQS to receive Autoscaling messages from SNS
resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.autoscale_updates_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.autoscale_updates_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.autoscale_updates.arn}"
        }
      }
    }
  ]
}
POLICY
}

# Creating the topic subscription which uses our created SQS' ARN

resource "aws_sns_topic_subscription" "autoscale_updates_sqs_target" {
  topic_arn = aws_sns_topic.autoscale_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.autoscale_updates_queue.arn
}

output "queue_url" {
    value   = aws_sqs_queue.autoscale_updates_queue.id
}

output "sns_arn" {
    value   = aws_sns_topic.autoscale_updates.arn
}

# Creating the Autoscaling stuff

# First is the launch template
# NOTE: the launch template includes a key pair that is already made in AWS
# Go make one with the same name or replce with another

resource "aws_launch_template" "foobar" {
  name_prefix   = "foobar"
  image_id      = "ami-09558250a3419e7d0"
  instance_type = "t2.micro"
  key_name      = "my-key-pair"
}

# Second is the autoscaling group

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

# Third is the autoscaling plan
# NOTE: need to figure out how to make it so that the group scan scale in if needed

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

# Creating the Autoscaling notifications using the SNS topic we made earlier

resource "aws_autoscaling_notification" "example_notifications" {
  group_names = [
    aws_autoscaling_group.bar.name,
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.autoscale_updates.arn
}
