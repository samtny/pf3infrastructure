aws
===

### SUMMARY:

The scripts provided here will bring up Amazon EC2 resources as follows;

* Create a VPC, subnets, security groups, etc (network layer)
* Bring up an EC2 instance running Amazon 'NAT' firmware to act as bridge from private to internet gateway
* Bring up an EC2 instance running Ubuntu 18.04 on the private subnet of the VPC and install a LAMP stack there
* Bring up an ELB on the public subnet of the VPC and point it to the LAMP instance, ports 80, 443

### REQUIREMENTS:

* AWS account with full EC2 / admin permissions.
* AWS CLI tool v1.8+.

### INITIAL INFRASTRUCTURE SETUP:

1. Execute 'aws configure --profile myprofile' to set up a credentials profile for this project.
1. Execute 'export AWS_PROFILE=myprofile' to set the default profile for the current session. 
1. Execute './keypair-create.sh myproject'.
1. Execute 'vim ~/.ssh/myproject.pem' and clean up the private key so it is usable.
1. Execute './vpcs-create.sh myproject' to create the project vpc.

### CREATING A NEW ENVIRONMENT:
1. Execute './environments-create.sh myproject prod', optionally replacing 'prod' with the environment name you would prefer ('stage/uat').
1. Wait a minute to let the EC2 instances initialize.
1. Execute the jump script './jump.sh myproject prod lamp'.  You should be looking at a command prompt on the LAMP instance.

### ENVIRONMENT TEARDOWN:

The scripts do not include 'terminate' for these resources, so to delete an environment, e.g. 'dev';

1. Delete the 'myproject-dev-lamp' ELB
1. Delete all EIPS associated with the instances named like 'Name=myprojects-dev'
1. Delete all EC2 instances tagged with 'Environment=dev'

### INFRASTRUCTURE TEARDOWN:

1. Ensure all environments have been removed as above
1. Delete the 'myproject' VPC

### TODO:

* Refactor all variables out of scripts and into some top-level layer.
* Remove a bunch of debug 'set -x', etc.
* Fix "create-elbs.sh" to take a port/s
* Various other refactorings...

### END
