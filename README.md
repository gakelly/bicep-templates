# bicep-templates


### Creating a VHub and Firewall
```bash
az group create --name fw-vhub-test-rg --location australiaeast
```
### What if test
```bash
az deployment group create --resource-group fw-vhub-test-rg --template-file main.bicep --what-if --parameters adminUsername=ths-admin
```
### Deploy Bicep
```bash
az deployment group create --resource-group fw-vhub-test-rg --template-file main.bicep --what-if --parameters adminUsername=ths-admin
```