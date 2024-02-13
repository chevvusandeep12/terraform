
In this tutorial our case study is that an e-commerce company needs to handle a surge in traffic during the holiday season. The company wants to ensure that their website remains available and responsive to customers even during high traffic periods.
In this project we will create an auto-scaling group that spans two subnets in the default VPC that will automatically scale up or down based on traffic. We will then create a security group that allows traffic from the internet and associate it with the instances. We will also bootstrap an Apache web server to these instances. Lastly we will create an S3 bucket and set it as a remote backend for Terraform.
What you’ll need to get started:
AWS account
Cloud9 Environment (Or your choice of IDE)
Basic Understanding of Linux
A GitHub Account
Step 1: Setting Up Your Cloud9 Environment
When creating your new GitHub repository in GitHub, make sure to choose Terraform as the .gitignore template to ensure that the correct files are ignored.

In the settings of the new repository it is also good to create branch protection rules.

Head over to Cloud9 in the AWS console and create an environment in your default VPC. Click on the GitHub icon and choose “Clone Repository” and paste in the URL of your repository.

We will now create a directory for our terraform files to be in and cd into them at the same time.
mkdir auto-scaling && cd auto-scaling
We will create a couple of empty files inside of our directory. You can create them all at once.
touch main.tf providers.tf variables.tf apache.sh

Double check that the files are in the proper folder and not the /home/ec2-user/environment folder because Cloud9 will not recognize your changes and you will not be able to push your code to GitHub.

Step 2: Creating Terraform Files
It is important that every file that you want Terraform to recognize must end with the .tf extension.
The first file we are going to work on is the providers.tf files because it’s simple.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

You can find different providers right on the Terraform Registry but in this tutorial we will be using AWS.
Next we will create the apache script that will be bootstrapped to the EC2 instance for our apache.sh file.
#!/bin/bash
sudo yum update -y &&
sudo yum install -y httpd &&
systemctl start httpd
systemctl enable httpd

This very simple script will start up Apache in the EC2 instances upon creation. We will now move onto our main.tf file. I will break this down piece by piece and then we will put the whole thing together.
The first part of our script is the security group that will allow us to reach the internet from our EC2 instances and this will be attached to our auto-scaling group as well.
# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = var.vpc_id #your VPC ID will be different in variable file

  # allow access on port 80
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow access on port 22
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apache server security group" #you can choose any name you like
  }
}
The next part of our script is the auto-scaling group that will launch a minimum of 2 EC2 instances in two different subnets. This was customized with other supported arguments from the latest version of the launch template from the Terraform registry. Many of these arguments are optional but check the documentation to add anything extra you may need.
Keep in mind that the bracket placement is extremely important. The launch template reference is within the auto-scaling group and the actual resource block that defines the launch template is in its own bracket. This is where the arguments would be added to define what is associated with the EC2 instances.

resource "aws_autoscaling_group" "tf" {
  desired_capacity    = 2   #set to what you like; must be same number as min
  max_size            = 5   #set to what you like
  min_size            = 2   #set to what you like; must be same as desired capacity
  vpc_zone_identifier = [var.subnet_id_2, var.subnet_id_1]   #two subnets

  launch_template {
    id      = aws_launch_template.tf_launch_template.id
    version = "$Latest"
  }
}

resource "aws_launch_template" "tf_launch_template" {
  name_prefix            = "tf-launch_template"
  image_id               = var.image_id                 #in variable file
  instance_type          = var.instance_type            #in variable file
  key_name               = var.key_name                 #in variable file
  user_data              = filebase64("${path.root}/apache.sh")
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform_auto_scaling"
    }
  }
}

#note: if user data is not in your EC2 instances check that you file is in root
The last part of our script will be setting an S3 bucket as a remote backend for our terraform state file to live. This is important because when you create your terraform resources, by default the terraform state file is stored locally on your computer but how would everyone on your team at work be able to access that? They couldn’t and that’s why it is a best practice to store your terraform state file remotely somewhere like an S3 bucket or Terraform cloud.
The first thing we are going to do is manually create the bucket in AWS.
Create a bucket with a globally unique name in the correct region
Block all public access
Enable bucket versioning
Enable encryption & select AWS Key Management Service key (SSE-KMS)
Click create KMS key(leave defaults), select a user who has access to all permissions and click finish.
Get the whole alias ARN from the KMS dashboard & paste it into the box
Leave bucket key enabled



After creating the bucket, go into the permissions and edit the policy and add the following policy and save the changes.

A simple way to get your user ARN is to enter the following command.
aws sts get-caller-identity

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "<your_user_arn>"
            },
            "Action": "s3:ListBucket",
            "Resource": "<your_bucket_arn>"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "<your_user_arn>"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "<your_bucket_arn>/*"
        }
    ]
}
Now that our bucket is created, we need to create a DynamoDB table for the state locking file in the AWS console.
When creating the table choose a name but for the partition key name it LockID and leave all of the other settings as default and create the table.
Now that everything is configured, head over to Cloud9.
You can add this directly to the main.tf file but to make our code more reusable we are going to store our backend configuration in a new file called terraform.tf.
This file is used to communicate required versions and providers. For example if there was a newer version that gets released that is not compatible with the code you’ve written maybe 3 months ago, this lets others know what is needed to run your code.
Terraform knows to store the state file locally so it is not necessary to tell it to do so but this is what it would look like if it was in the terraform.tf file.
terraform {
  backend "local" {
    path   = "terraform.tfstate"
  }
}
Since we our changing where the state file is being store this is what will be placed in our terraform.tf file.
terraform {
  backend "s3" {
    bucket         = "<your_bucket_name>"
    key            = "terraform.tfstate" #don't replace this value
    region         = "<your_aws_region>"
    dynamodb_table = "<your_dynamo_dbtable_name>"
  }
}
This is what the whole code should look like if you leave the backend information in the main.tf file. Again a best practice is to put the last part for the S3 backend in a terraform.tf file.
# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "apache security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = var.vpc_id #your VPC ID will be different

  # allow access on port 80
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow access on port 22
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apache server security group"
  }
}

resource "aws_autoscaling_group" "tf" {
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = [var.subnet_id_2, var.subnet_id_1]

  launch_template {
    id      = aws_launch_template.tf_launch_template.id
    version = "$Latest"
  }
}

resource "aws_launch_template" "tf_launch_template" {
  name_prefix            = "tf-launch_template"
  image_id               = var.image_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = filebase64("${path.root}/apache.sh")
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform_auto_scaling"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "my-bucket-name"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "my-terraform-dbtable"
  }
}
Last we will work on our variables.tf file. Every variable in the main.tf file is defined in this file so you will need to grab your actual values from the AWS console.
variable "subnet_id_1" {
  description = "The VPC subnet the instance(s) will be created in"
  default     = "subnet-1234567890"
}

variable "subnet_id_2" {
  description = "The VPC subnet the instance(s) will be created in"
  default     = "subnet-0987654321"
}

variable "vpc_id" {
  type    = string
  default = "vpc-1234abc5678def90"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "image_id" {
  type    = string
  default = "ami-0135792468" # use the AMI for Amazon Linux 2
}

variable "key_name" {
  type    = string
  default = "yourkeyname"
}
Now that we have all of our files created make sure to save them. We will now run our commands.
Step 3: Deploying Resources Using Terraform
If you have any resources currently deployed in the state file just run the command terraform destroy to start fresh.
The first command we will run within our directory is to initialize Terraform.
terraform init

This is the message you are looking for. If you don’t get a green success message something has gone wrong. You can also see the it has recognized our S3 backend. The next command is not necessary but good to use to double check your work.
#checks for syntax errors and validates your configuration
terraform validate

Terraform validate is a good way to catch a couple of syntax errors before you deploy your resources. If you get that your configuration has issues you can run the following command to see if there are any formatting issues.
terraform fmt
Last we will run a plan. It is good to review exactly what will be deployed before you do so because maybe there is something in your code that you wrote correctly but the desired outcome is not what Terraform is recognizing.
#see what resources will be deployed
terraform plan
Last if you’re satisfied with how the plan looks you can run the last command.
#deploy resources
terraform apply

#type yes to confirm

Step 4: Verify Resources were Deployed Accurately
Now we can verify and check that our resources were created correctly.
First we have our security group named “apache security group” with the appropriate permissions.

We have our EC2 instances with two different subnets and we can reach our apache server.



To double check that our auto-scaling group is working properly I am going to manually terminate one instance and another one should spin up because we set our minimum to 2 and it did.

Now lets check our auto-scaling group to make sure the permissions are associated with it.

Last we will check our S3 bucket to make sure our state file was stored there. We can also check our DynamoDB table.

Here we see a spike in activity which was our lock state being stored as well as well as auto-scaling activity.


Now that we’re complete you want to make sure to clean up all resources by running a terraform destroy to destroy all of the resources created.
If you’ve made it this far thank you so much for sticking with me and if you’d like to follow more of my journey please connect with me on LinkedIn!
Terraform
DevOps
Women In Tech
Cloud Engineering
AWS
74


