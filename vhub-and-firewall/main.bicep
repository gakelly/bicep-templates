@description('Admin username for the servers')
param adminUsername string

@description('Password for the admin account on the servers')
@secure()
param adminPassword string

@description('Environemnt identifier')
param envId string = 'ths'


@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'

param defaultTags object = {
  environment: envId
  owner: 'TechHub'
  change: 'Firewall-Test'
}


resource virtualWan 'Microsoft.Network/virtualWans@2021-08-01' = {
  name: 'VWan-${envId}-01'
  location: location
  tags: defaultTags
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

resource virtualHub 'Microsoft.Network/virtualHubs@2021-08-01' = {
  name: 'Hub-${envId}-01'
  location: location
  tags: defaultTags
  properties: {
    addressPrefix: '10.1.0.0/16'
    virtualWan: {
      id: virtualWan.id
    }
  }
}

resource hubVNetconnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2021-08-01' = {
  parent: virtualHub
  name: 'hub-${envId}-spoke'
  dependsOn: [
    firewall
  ]
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hubRouteTable.id
      }
      propagatedRouteTables: {
        labels: [
          'VNet'
        ]
        ids: [
          {
            id: hubRouteTable.id
          }
        ]
      }
    }
  }
}

resource policy 'Microsoft.Network/firewallPolicies@2021-08-01' = {
  name: 'Test-${envId}-Policy-01'
  location: location
  tags: defaultTags
  properties: {
    threatIntelMode: 'Alert'
  }
}

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-08-01' = {
  parent: policy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RuleCollection-01'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-msft'
            sourceAddresses: [
              '*'
            ]
            protocols: [
              {
                port: 80
                protocolType: 'Http'
              }
              {
                port: 443
                protocolType: 'Https'
              }
            ]
            targetFqdns: [
              '*.microsoft.com'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2021-08-01' = {
  name: 'AzfwTest-${envId}'
  location: location
  tags: defaultTags
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Premium'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: virtualHub.id
    }
    firewallPolicy: {
      id: policy.id
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: 'Spoke-${envId}-01'
  location: location
  tags: defaultTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_Workload_SN 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  parent: virtualNetwork
  name: 'Workload-SNet'
  properties: {
    addressPrefix: '10.0.1.0/24'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource subnet_Jump_SN 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  parent: virtualNetwork
  name: 'Jump-SNet'
  dependsOn: [
    subnet_Workload_SN
  ]
  properties: {
    addressPrefix: '10.0.2.0/24'
    routeTable: {
      id: routeTable.id
    }
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource Jump_Srv 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: 'Jump-Srv'
  location: location
  tags: defaultTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: 'Jump-Srv'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        // ssh: {
        //   publicKeys: [
        //     {
        //       path: '/home/${adminUsername}/.ssh/authorized_keys'
        //       keyData: sshKeyData
        //     }
        //   ]
        // }
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: netInterface_jump_srv.id
        }
      ]
    }
  }
}

resource policy_2 'Microsoft.Network/firewallPolicies@2021-08-01' = {
  name: 'Test-${envId}-Policy-02'
  location: location
  tags: defaultTags
  properties: {
    threatIntelMode: 'Alert'
  }
}

resource ruleCollectionGroup_2 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-08-01' = {
  parent: policy_2
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RuleCollection-01'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-msft'
            sourceAddresses: [
              '*'
            ]
            protocols: [
              {
                port: 80
                protocolType: 'Http'
              }
              {
                port: 443
                protocolType: 'Https'
              }
            ]
            targetFqdns: [
              '*.microsoft.com'
            ]
          }
        ]
      }
    ]
  }
}



resource Workload_Srv 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: 'Workload-Srv'
  location: location
  tags: defaultTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: 'Workload-Srv'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      allowExtensionOperations: true
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: netInterface_workload_srv.id
        }
      ]
    }
  }
}

resource netInterface_workload_srv 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: 'netInterface-workload-srv'
  location: location
  tags: defaultTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_Workload_SN.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: nsg_workload_srv.id
    }
  }
}

resource netInterface_jump_srv 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: 'netInterface-jump-srv'
  location: location
  tags: defaultTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP_jump_srv.id
          }
          subnet: {
            id: subnet_Jump_SN.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: nsg_jump_srv.id
    }
  }
}

resource nsg_jump_srv 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'nsg-jump-srv'
  location: location
  tags: defaultTags
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nsg_workload_srv 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'nsg-workload-srv'
  location: location
  properties: {}
}

resource publicIP_jump_srv 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'publicIP-jump-srv'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource routeTable 'Microsoft.Network/routeTables@2021-08-01' = {
  name: 'RT-01'
  location: location
  tags: defaultTags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'jump-to-inet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

resource hubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-08-01' = {
  parent: virtualHub
  name: 'RT_VNet'
  properties: {
    routes: [
      {
        name: 'Workload-SNToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '10.0.1.0/24'
        ]
        nextHopType: 'ResourceId'
        nextHop: firewall.id
      }
      {
        name: 'InternetToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: firewall.id
      }
    ]
    labels: [
      'VNet'
    ]
  }
}
