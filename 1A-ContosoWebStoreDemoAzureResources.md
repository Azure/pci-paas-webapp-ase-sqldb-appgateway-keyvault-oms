## 1A-ContosoWebStoreDemoAzureResources.ps1

Deploying this demo solution requires that a subscription be configured with the proper permissions and roles. For more information, see [Script Details: 0-Setup-AdministrativeAccountAndPermission.ps1](./0-Setup-AdministrativeAccountAndPermission.md).
This and all PowerShell scripts in the enviroment will run in an ['Unrestricted' execution policy.](https://technet.microsoft.com/en-us/library/ee176961.aspx?f=255&MSPPError=-2147217396)

![](images/Warning-sign.png) **CAUTION** The script adds domain users to the Azure Active Directory (AAD) tenant that you specify. It is recommended to create a new Azure Active Directory (AAD) tenant to test this demo payment processing solution.

![](images/Warning-sign.png) **CAUTION** It is recommended to use a [clean Windows 10](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-portal) (or similar) VM to deploy the solution to ensure that the correct PowerShell modules get loaded. If challenges are experienced with loading the correct PowerShell modules, remove any Azure-specific modules from the PowerShell modules directory. 

![](images/Warning-sign.png) **CAUTION** If any issues are encountered during the deployment, see [FAQ and troubleshooting](pci-faq.md).

This PowerShell script is used to deploy the infrastructure for the Contoso Web App Store demo.

```PowerShell
.\1A-ContosoWebStoreDemoAzureResources.ps1
```
### Deployment Timeline

The estimated time to deploy the solution components is shown in the diagram below. The total time required is approximately 2.0-2.5 hours from when the script starts. If the App Service Environment takes greater than 2 hours to deploy, the deployment may time out. 

## Example 1: Simple deployment 
    
```powershell
.\1A-ContosoWebStoreDemoAzureResources.ps1 
```

This deployment script creates the required Azure Active Directory (AAD) accounts and generates a self-signed certificate for the ASE ILB and Application Gateway SSL endpoint using a provided custom domain.
Users will be prompted for two logins, one for Azure Active Directory (AAD) and another for Azure Resource Manager (ARM). The only required inputs are guided prompts for providing an email address for SQL Threat Detection alerts and an Azure Subscription ID. 

## Initiating the Deployment

An Azure Active Directory (AAD) Global Administrator account will be required for initiating this deployment. This user must be a *Global Administrator* that has been granted full control of the default Azure Active Directory instance. The user must be in the Azure Active Directory domain namespace.

In deploying this solution, two login prompts will be presented such that users' AAD Global Administrator account credentials are not captured and presented in the open PowerShell session. 

As the deployment utilizes both the *AzureRM* and *MSOnline* PowerShell modules for monitoring and configuring the deployment, there are two login prompts users will be required to provide credentials for. 

Azure Active Directory Global Admininistrator credentials will not be presented in the PowerShell console, and is securely authenticated through web portal logins. 

Role-based access control (RBAC) requires that an administrator grants themselves administrative rights in AAD. Refer to this blog for a detailed explanation.
> [Delegating Admin Rights in Microsoft Azure](https://www.petri.com/delegating-admin-rights-in-microsoft-azure)
> [PowerShell - Connecting to Azure Active Directory using Microsoft Account](http://stackoverflow.com/questions/29485364/powershell-connecting-to-azure-active-directory-using-microsoft-account) user.

For more information, see [Script Details: 0-Setup-AdministrativeAccountAndPermission.ps1](./0-Setup-AdministrativeAccountAndPermission.md).

## Required Parameters

> Email Address for SQL Threat Detection Alerts

Provide a valid email address for SQL Threat Detection alerts and issues associated with your deployment.

> Azure Subscription ID

Specifies the ID of a subscription. This needs to be provided for validating the Azure Active Directory (AAD) global administrator account that will be used with the deployment. 

## Default Parameters

> Resource group

The default of `ContosoPCI-BP` will be the name of the resource group where the solution will be deployed.

> Suffix

`Blueprint` will be used as an identifier in the deployment of the solution. In a production environment, this can be any character or identifier, such as a business unit name.


## (Optional) Using a custom host name 

> $customHostName

Specifies a custom domain for the deployment. To be able to connect to the website, it is required that you provide a custom domain name, such as contoso.com. The default, Azure-provided `azurewebsites.net` will be used if a custom domain name is not specified. A custom domain name is not required to successfully deploy the solution, however you will not be able to connect to the website for demonstration purposes. For more information, see [How to buy and enable a custom domain name for Azure Web Apps](https://docs.microsoft.com/en-us/azure/app-service-web/custom-dns-web-site-buydomains-web-app). If this variable is updated you will be required to update the application's IP address with your DNS hosting provider (custom domain name). In the example, the customer’s DNS settings require the Application
Gateway IP address to be updated as a DNS record on the hosting site. You can do this via the steps below. 

1.  Collect the Application Gateway IP address using the following PowerShell command:

```PowerShell
Get-AzureRmPublicIpAddress | where {$_.Name -eq "publicIp-AppGateway"} | select IpAddress
```

This command will return the IP address. For example:
>` IpAddress`  
>` ---------`
>` 172.16.0.10`

2.  Log into your DNS hosting provider and update the A/AAAA record with the Application Gateway IP address.

## Optional variables

> $location

This variable can be changed to a different location than the default value `eastus`. Changing this setting requires that the deployment is monitored to ensure its successful completion.
If this is updated, the variables set in `azuredeploydemo.json` under `aseLocation` and `omsRegion` will need to be updated to match the corresponding region set for `$location`. 

> $automationAcclocation

This variable can be changed to a different location than the default value `eastus2`. Changing this setting requires that the deployment is monitored to ensure its successful completion.
If this is updated, the variable set in `azuredeploydemo.json` under `automationRegion` will need to be updated to match the corresponding region set for `$automationAcclocation`. 

## Troubleshooting the deployment script

If errors are experience when attempting to run the 1A-ContosoWebStoreDemoAzureResources.ps1 script, verify that the correct version PowerShell modules were imported when running the 0-Setup-AdministrativeAccountAndPermission.ps1 script. 

## Next Steps (2-EnableOMSLoggingOnResources.ps1 and 3-GrantAccessOnDB.sql)

Once the deployment is complete, `2-EnableOMSLoggingOnResources.ps1` can be run for enabling OMS logging on the resources deployed with the deployment. It is recommended to fully deploy the Contoso Web Store demo application solution into the environment before running this script. 

After the application is deployed, `3-GrantAccessOnDB.sql` can be used for granting SQL DB access to the Azure Active Directory (AAD) users created in this solution.