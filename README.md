# Terraform SSH Inception

[Terraform](https://en.wikipedia.org/wiki/Terraform_(software)) is software that provisions cloud infrastructure from a declarative configuration language.
This repository is a proof of concept for configuring the EDURange scenario SSH Inception using terraform.

## Prerequisites

You must install the `terraform` command line tool.

## Running

* [`terraform init`](https://www.terraform.io/docs/commands/init.html)
* [`terraform plan`](https://www.terraform.io/docs/commands/plan.html)
* [`terraform apply`](https://www.terraform.io/docs/commands/apply.html)
* [`terraform destroy`](https://www.terraform.io/docs/commands/destroy.html)

## Variables

The scenario can be parameterized with files in the `terraform.tfvars.json` file.

How to make password hashes to put in variables file:
```
openssl passwd -6 PASSWORD
```

