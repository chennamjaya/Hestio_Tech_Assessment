# Hestio_Tech_Assessment
AWS 2-tier application

VPC with at least one Private and one Public subnet: Your code defines both public and private subnets within the specified VPC.

Two VMs, one in the Private subnet, one in the Public subnet: You have resources for both aws_instance.public_vm and aws_instance.private_vm, each placed in their respective subnets.

Restrict access to the VM in the Public subnet to a single IP address: The security group (aws_security_group.security_group) associated with aws_instance.public_vm has ingress rules allowing traffic on ports 80 and 443 only from the specified CIDR block.

Restrict access to the VM in the Private subnet to only from the VM in the Public subnet: The security group (aws_security_group.security_group) associated with aws_instance.private_vm allows ingress from the security group of the public VM.

Both VMs should be able to reach the internet (either directly or indirectly): The public subnet instances will have internet access through the NAT gateway (aws_nat_gateway.ngw), and the private subnet instances will route traffic through the NAT gateway.

The code can be used to provision and de-provision the resources based on the requirement. We need to make some changes to the code like account ID and default vpc_id which needs to be updated as per the company's aws account information.

We can use the following link: https://opentofu.org/docs/intro/migration/ to migrate from Terraform to opentofu as opentofu is compatible with the Terraform version of 1.7 
