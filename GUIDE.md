# Create a new Terraform project
```
- main.tf
- modules/
  |- backend/
  |- vpc/
- dev.tfvars
- variables.tf
```

Create a "dev" workspace
```terraform workspace new dev```
This is where we will deploy everything for the dev environment.

Create a "backend" workspace
```terraform workspace new backend```
This is where we will deploy resources for the backend.

