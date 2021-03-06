#!/bin/bash
echo "Enter your region.."
read REGION
export REGION=${REGION}
function workspace() {
    cd aws-jenkins
}

function terraform_fmt(){
    terraform fmt
}

function terraform_init(){
    terraform init
}

function terraform_get(){
    terraform get
}

function terraform_plan(){
    terraform plan -var-file conf/parameters-${REGION}.tf
}
function terraform_apply(){
    terraform apply -var-file conf/parameters-${REGION}.tf --auto-approve
}
function terraform_destroy(){
    terraform destroy -var-file conf/parameters-${REGION}.tf --auto-approve
}

function main(){
    workspace
    terraform_fmt
    terraform_init
    terraform_get
    terraform_plan
    terraform_apply
    terraform_destroy
}

main