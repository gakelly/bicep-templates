# bicep-templates


### Creating a VHub and Firewall
`
az group create --name fw-vhub-test-rg --location australiaeast
`
### What if test
`
az deployment group create --resource-group fw-vhub-test-rg --template-file main.bicep --what-if --parameters adminUsername=ths-admin
`
### Deploy Bicep
`
az deployment group create --resource-group fw-vhub-test-rg --template-file main.bicep --parameters adminUsername=ths-admin
`