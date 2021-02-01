#aws_launch config for ec2 for autoscaling group
resource "aws_launch_configuration" "webcluster" {
name = "ruby_AWS_LC"
image_id= "ami-04f5991336bf3845c"
instance_type = "t2.micro"
security_groups = ["${aws_security_group.websg.id}"]
key_name = "Singapore-key"
user_data = <<-EOF
#!/bin/bash
sudo su root
docker start a08051019de3
EOF

lifecycle {
create_before_destroy = true
}
}

resource "aws_autoscaling_group" "aws_autoscaling_group" {
name = "g2_autoscale"
launch_configuration = "${aws_launch_configuration.webcluster.name}"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
min_size = 1
max_size = 3
enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
metrics_granularity="1Minute"
load_balancers= ["${aws_elb.elb1.id}"]
health_check_type = "ELB"
tag {
key = "Name"
value = "terraform-asg-example"
propagate_at_launch = true
}
}
resource "aws_autoscaling_policy" "autopolicy" {
name = "terraform-autoplicy"
scaling_adjustment = 1
adjustment_type = "ChangeInCapacity"
cooldown = 300
autoscaling_group_name = "${aws_autoscaling_group.aws_autoscaling_group.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpualarm" {
alarm_name = "terraform-alarm"
comparison_operator = "GreaterThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "120"
statistic = "Average"
threshold = "60"
alarm_description = "This metric monitor EC2 instance cpu utilization"
alarm_actions = ["${aws_autoscaling_policy.autopolicy.arn}"]
}


resource "aws_autoscaling_policy" "autopolicy-down" {
name = "terraform-autoplicy-down"
scaling_adjustment = -1
adjustment_type = "ChangeInCapacity"
cooldown = 300
autoscaling_group_name = "${aws_autoscaling_group.aws_autoscaling_group.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpualarm-down" {
alarm_name = "terraform-alarm-down"
comparison_operator = "LessThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "120"
statistic = "Average"
threshold = "10"
alarm_description = "This metric monitor EC2 instance cpu utilization"
alarm_actions = ["${aws_autoscaling_policy.autopolicy-down.arn}"]
}

resource "aws_security_group" "websg" {
name = "security_group_for_web_server"
ingress {
from_port = 8080
to_port = 8080
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
lifecycle {
create_before_destroy = true
}
}

resource "aws_security_group" "elbsg" {
name = "security_group_for_elb"
ingress {
from_port = 8080
to_port = 8080
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
lifecycle {
create_before_destroy = true
}
}
resource "aws_elb" "elb1" {
name = "terraform-elb"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
security_groups = ["${aws_security_group.elbsg.id}"]
listener {
instance_port = 8080
instance_protocol = "tcp"
lb_port = 8080
lb_protocol = "tcp"
}
health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 10
target = "TCP:8080"
interval = 30
}
idle_timeout = 60
connection_draining = true
connection_draining_timeout = 120

}
output "elb-dns" {
value = "${aws_elb.elb1.dns_name}"
}