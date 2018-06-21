<#
This script enables diagnostics logging on the resources and configure Log analytics to collect the logs.

Make sure you import AzureRM and AzureDiagnosticsAndLogAnalytics modules before executing this script.

#>

# Login to AzureRM function
function loginToAzureRM {
	Param(
		[Parameter(Mandatory=$true)]
		[int]$loginCount,
        [Parameter(Mandatory=$true)]
		[string]$subscriptionID
	)

    # Login to AzureRM Service
    Write-Host -ForegroundColor Yellow "`t* Prompt for connecting to AzureRM Subscription - $subscriptionID."
    Login-AzureRmAccount -SubscriptionId $subscriptionID | Out-null
    if (Get-AzureRmContext) {
        Write-Host -ForegroundColor Cyan "`t`t-> Connection to AzureRM Subscription established successfully for managing Azure Resource Manager."
    }

    # Login Validation
	if($?) {
		Write-Host "`t`t`t*** Azure Resource Manager (ARM) Login Successful! ***" -ForegroundColor Green
	} 
    else {
		if ($loginCount -lt 3) {
			$loginCount = $loginCount + 1
			Write-Host -ForegroundColor Magenta "`t-> Invalid Credentials! Please try logging in again."
			loginToAzure -lginCount $loginCount
		} 
        else {
			Write-Host -ForegroundColor Magenta "`t-> Credentials input are incorrect, invalid, or exceed the maximum number of retries. Verify the correct Azure account information is being used."
			Write-Host -ForegroundColor Yellow "                                    Press any key to exit..."
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			Exit
		}
	}
}

    # Provide resourceGroupName for deployment
    Write-Host -ForegroundColor Yellow " Name of the resource group to be created for this deployment (if blank, 'PCI-PayProc-BP' will be used as the resource group name)."
    $resourceGroupName = Read-Host " Resource Group Name"
    if ($resourceGroupName -eq "") {$resourceGroupName = "PCI-PayProc-BP"}
    Write-Host ""

    # Provide Subscription ID that will be used for deployment
    Write-Host -ForegroundColor Yellow " Azure Subscription ID associated to the Global Administrator account for deploying this solution." 
    do {
        try {
            [System.Guid]$subscriptionID = Read-Host " Azure Subscription ID"
        }
        catch {
            Write-Host -ForegroundColor Magenta "`t-> Please enter a valid Azure Subscription ID."
        }
    }
    until (
        $subscriptionID -match ("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")
    )
    Write-Host ""

### Login to Azure RM ###
Write-Host -ForegroundColor Green "`n###############################         Connecting to Azure        ############################### `n "

try {
    loginToAzureRM -loginCount 1 -subscriptionID $subscriptionID
}
catch {
    Write-Host -ForegroundColor Magenta "`t-> Azure login attempts failed. Verify your user credentials before running the deployment script again."
    Break
}

try {
    Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted -Force
            
    # Start OMS Diagnostics
    Write-Host ("`n Getting OMS Workspace details.." ) -ForegroundColor Yellow
    $omsWS = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName

    Write-Host ("`n Collecting list of resourcetype to enable log analytics." ) -ForegroundColor Yellow
    $resourceTypes = @( "Microsoft.Network/applicationGateways",
                        "Microsoft.Network/NetworkSecurityGroups",
                        "Microsoft.Web/serverFarms",
                        "Microsoft.Sql/servers/databases",
                        "Microsoft.Compute/virtualMachines",
                        "Microsoft.Web/sites",
                        "Microsoft.KeyVault/Vaults" )

    Write-Host ("`n Enabling diagnostics for each resource type." ) -ForegroundColor Yellow
    foreach($resourceType in $resourceTypes)
    {
        Enable-AzureRMDiagnostics -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId -WSID $omsWS.ResourceId -ResourceType $resourceType -Force -Update -EnableLogs -EnableMetrics 
    }

    $workspace = Find-AzureRmResource -ResourceType "Microsoft.OperationalInsights/workspaces" -ResourceNameContains $omsWS.Name -ResourceGroupNameEquals $resourceGroupName
    Write-Host ("`n Configure Log Analytics to collect Azure diagnostic logs" ) -ForegroundColor Yellow
    foreach($resourceType in $resourceTypes)
    {
        Write-Host ("`n`t-> Adding Azure Diagnostics to Log Analytics for -" + $resourceType) -ForegroundColor Yellow
        $resource = Find-AzureRmResource -ResourceType $resourceType -ResourceGroupNameEquals $resourceGroupName
        Add-AzureDiagnosticsToLogAnalytics $resource $workspace
    }
    # End OMS Diagnostics    
}
catch {
    Write-Host -ForegroundColor Magenta "`t-> Could not configure OMS for the specified resources. Verify the resources specified are available in the Azure portal before re-running this script."
    Break
}