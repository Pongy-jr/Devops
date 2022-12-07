# Devops
Commands to run application:
1. terraform init
2. terraform apply -target="module.vpc"
3. terraform apply

Commands explanation
1. Init the directory andconfigurations
2. Run VPC modul first so we  are sure that the subnets are ready for next resources/modules
3. Run rest of the code

Code:
1. First we create VPC with three subnets with ip range 10.0.x.x
2. Then we set up launch config for instances and add the to Auto scaling group, for which we also set up a schedule and add it to Target group
3. then we set up a Network load balancer and it's listener on port 80 and also add it to Auto scaling group. For the NLB I set the create wait time to 10 minutes so the program has time to set it as it take a bit of time to finish.