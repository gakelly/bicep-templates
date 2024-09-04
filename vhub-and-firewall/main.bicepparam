using './main.bicep'

param virtualNetworkName = 'vnet${uniqueString(resourceGroup().id)}'
param firewallName = 'fw${uniqueString(resourceGroup().id)}'
param numberOfPublicIPAddresses = 2
param availabilityZones = []
param location = resourceGroup().location
param infraIpGroupName = '${location}-infra-ipgroup-${uniqueString(resourceGroup().id)}'
param workloadIpGroupName = '${location}-workload-ipgroup-${uniqueString(resourceGroup().id)}'
param firewallPolicyName = '${firewallName}-firewallPolicy'

