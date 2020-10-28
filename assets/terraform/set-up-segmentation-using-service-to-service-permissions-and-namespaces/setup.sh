#/bin/sh

# terraform import consul_intention.default $(terraform output -state=../move-application-into-the-service-mesh/terraform.tfstate consul_default_intention_id)

cd ../move-application-into-the-service-mesh
terraform apply -var 'solve=true' -var 'default_intention=deny'