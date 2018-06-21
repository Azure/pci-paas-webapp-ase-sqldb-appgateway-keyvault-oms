#requires -RunAsAdministrator

<#
    This script deploys and configures an Azure infrastructure for a fictitious example of a basic payment processing solution for the collection of basic user information and payment data. 

    This script will both provision and deploy an infrastructure for supporting the Contoso Web Store demo example. 
            Owner permission required at Subscription level to execute this script. 
            If an account with appropriate permissions is unavailable, run 0-Setup-AdministrativeAccountAndPermission.ps1 with the -configureGlobalAdmin switch enabled for creating a Global Administrator account member in Azure Active Directory.

        This script performs several pre-requisites including: 
            -   Create 2 example Azure AD Accounts - 1) SQL Account with Company Administrator Role and Contributor Permission on a Subscription.
                                                     2) Receptionist Account with Limited access (as Edna Benson).
            -   Creates AD Application and Service Principle to AD Application.
            -   Generates self-signed SSL certificate for Internal App Service Environment and Application gateway (if required).

    Please note - By default, the application gateway will always communicate with the App Service Environment using HTTPS. 
    This example utilizes a self-signed cert, however the primary deployment does support the use of a custom SSL certificate for supporting production workloads.

    Please be aware that the Contoso Web Store application will need to be loaded into the environment once this deployment completes. 
    This deployment demo is specific to deploying the necessary infrastructure in Azure for supporting the Contoso Web Store application demo only.
#>

# Initial Deployment Messages
Write-Host -ForegroundColor Green "`n `n##################################################################################################"
Write-Host -ForegroundColor Green "##########################    Azure Security and Compliance Blueprint   ##########################"
Write-Host -ForegroundColor Green "##########################      PCI-DSS Payment Processing Example      ##########################"
Write-Host -ForegroundColor Green "##########################       Infrastructure Deployment Script       ##########################"
Write-Host -ForegroundColor Green "################################################################################################## `n "

Write-Host -ForegroundColor Yellow " This script can be used for creating the necessary infrastructure to deploy a sample payment processing solution" 
Write-Host -ForegroundColor Yellow " for the collection of basic user information and payment data. `n " 
Write-Host -ForegroundColor Yellow " The Contoso Web Store example application can be used with this environment for understanding this solution." 
Write-Host -ForegroundColor Yellow "`n See https://aka.ms/pciblueprintprocessingoverview for more information. `n "
Write-Host -ForegroundColor Yellow " This script can only be deployed from an Azure Active Directory Global Administrator account. `n " 
Write-Host -ForegroundColor Magenta " If an Azure Active Directory Global Administrator Account is unavailable, run" 
Write-Host -ForegroundColor Magenta " 0-Setup-AdministrativeAccountAndPermission.ps1 to provision one for a defined" 
Write-Host -ForegroundColor Magenta " Azure subscription. `n " 
Write-Host -ForegroundColor Yellow "                                    Press any key to continue... `n " 

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host -ForegroundColor Green "###############################   Collecting Required Parameters   ############################### `n " 
Write-Host -ForegroundColor Green " The following parameters will be automatically prompted to successfully deploy this example:" 
Write-Host -ForegroundColor Yellow "`t* Azure Subscription ID"
Write-Host -ForegroundColor Yellow "`t* Email Address for sample SQL Threat Detection Alerts `n " 

##########################################################################################################################################################################
################################################         Initial User Prompts for required and optional parameters        ################################################
##########################################################################################################################################################################

        # Resource Group Name for example deployment
        $resourceGroupName = "ContosoPCI-BP"

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

        # This is the suffix used for the example deployment
        $suffix = "Blueprint"

        # Provide Email address for SQL Threat Detection Alerts
        Write-Host -ForegroundColor Yellow " Email address for receiving SQL Threat Detection Alerts." 
        do {
            try {
                [mailaddress]$sqlTDAlertEmailAddress = Read-Host " Email Address for SQL Threat Detection Alerts"
            }
            catch {
                Write-Host -ForegroundColor Magenta "`t-> Please enter a valid email address."
            }
        }
        until (
            [mailaddress]$sqlTDAlertEmailAddress -match "@"
        )

        # Default domain name (azurewebsites.net) used in the example deployment
        $customHostName = "azurewebsites.net"

##########################################################################################################################################################################
################################################                          Azure Login Functions                           ################################################
##########################################################################################################################################################################

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

# Login to Azure Active Directory function
function loginToAzureAD {
	Param(
		[Parameter(Mandatory=$true)]
		[int]$loginCount
	)

    # Login to MSOnline Service for managing Azure Active Directory
    Write-Host -ForegroundColor Yellow  "`t* Prompt for connecting to MSOnline service."
    Connect-MsolService | Out-Null
    if (Get-MsolDomain) {
        Write-Host -ForegroundColor Cyan "`t`t-> Connection to MSOnline service established successfully for managing Azure Active Directory."
    }

    # Login Validation
	if($?) {
		Write-Host "`t`t`t*** Azure Active Directory (AAD) Login Successful! ***" -ForegroundColor Green
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

### Logins to Azure RM and Azure AD ###
Write-Host -ForegroundColor Green "`n###############################         Connecting to Azure        ############################### `n "

try {
    loginToAzureRM -loginCount 1 -subscriptionID $subscriptionID
    loginToAzureAD -loginCount 1
}
catch {
    Write-Host -ForegroundColor Magenta "`t-> Azure login attempts failed. Verify your user credentials before running the deployment script again."
    Break
}

# Setting Azure AD Domain Name
$AzureContext = get-azurermcontext
$azureADDomainName = $AzureContext.account.id.split("@")[1]

# Verify Azure AD Domain Name
Write-Host -ForegroundColor Yellow "`t* Verifying Azure Active Directory Domain."
if ($azureADDomainName -match ".onmicrosoft.com") {Write-Host -ForegroundColor Green "`t`t`t*** Azure Active Directory Domain Verified! ***"}
else {
    Write-Host -ForegroundColor Magenta "`n Azure Active Directory user is not a primary member of $azureAdDomainName."
    Write-Host -ForegroundColor Magenta " Verify an Azure Active Directory Global Administrator associated to a *.onmicrosoft.com domain is used and run this script again." 
    Break
}

##########################################################################################################################################################################
################################################                                Deployment                                ################################################
##########################################################################################################################################################################

Write-Host -ForegroundColor Green "`n###############################         Deploying to Azure         ###############################"

    # Preference variable
    $ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'Stop'
    $WarningPreference = "SilentlyContinue"
    Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted -Force
    
    #Change Path to Script directory
    Set-location $PSScriptRoot

    Write-Host -ForegroundColor Green "`n Step 1: Checking pre-requisites"

    # Checking AzureRM Context version
    Write-Host -ForegroundColor Yellow "`t* Checking AzureRM context version."
    if ((get-command get-azurermcontext).version -le "3.0"){
        Write-Host -ForegroundColor Magenta "`n This script requires PowerShell 3.0 or greater to run."
        Break
    }

    ########### Manage directories ###########
    # Create folder to store self-signed certificates
    Write-Host -ForegroundColor Yellow "`t* Creating a certificates directory for storing the self-signed certificate."
    if (!(Test-path $pwd\certificates)) {
        mkdir $pwd\certificates -Force | Out-Null
    }

    ### Create Output  folder to store logs, deploymentoutputs etc.
    if (! (Test-Path -Path "$(Split-Path $MyInvocation.MyCommand.Path)\output")) {
        New-Item -Path $(Split-Path $MyInvocation.MyCommand.Path) -Name 'output' -ItemType Directory
    }
    else {
        Remove-Item -Path "$(Split-Path $MyInvocation.MyCommand.Path)\output" -Force -Recurse
        Start-Sleep -Seconds 2
        New-Item -Path $(Split-Path $MyInvocation.MyCommand.Path) -Name 'output' -ItemType Directory
    }
    $outputFolderPath = "$(Split-Path $MyInvocation.MyCommand.Path)\output"
    ########### Functions ###########
    Write-Host -ForegroundColor Green "`n Step 2: Loading functions"

    <#
    .SYNOPSIS
        Registers RPs
    #>
    Function RegisterRP {
        Param(
            [string]$ResourceProviderNamespace
        )
        Write-Host -ForegroundColor Yellow "`t* Registering resource provider $ResourceProviderNamespace.";
        Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace | Out-Null;
    }

    # Function to convert certificates into Base64 String.
    function Convert-Certificate ($certPath)
    {
        $fileContentBytes = get-content "$certPath" -Encoding Byte
        [System.Convert]::ToBase64String($fileContentBytes)
    }

    # Function to create a strong 15 length Strong & Random password for the solution.
    function New-RandomPassword () 
    {
        # This function generates a strong 15 length random password using Capital & Small Aplhabets,Numbers and Special characters.
        (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})) + `
        ((10..99) | Get-Random -Count 1) + `
        ('@','%','!','^' | Get-Random -Count 1) +`
        (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})) + `
        ((10..99) | Get-Random -Count 1)
    }

    #  Function for self-signed certificate generator. Reference link - https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6
    .".\1-click-deployment-nested\New-SelfSignedCertificateEx.ps1"

    Write-Host -ForegroundColor Yellow "`t* Functions loaded successfully."

    ########### Manage Variables ###########
    $location = 'eastus'
    $automationAcclocation = 'eastus2'
    $scriptFolder = Split-Path -Parent $PSCommandPath
    $sqlAdAdminUserName = "sqlAdmin@"+$azureADDomainName
    $receptionistUserName = "receptionist_EdnaB@"+$azureADDomainName
    $pciAppServiceURL = "http://pcisolution"+(Get-Random -Maximum 999)+'.'+$azureADDomainName
    $suffix = $suffix.Replace(' ', '').Trim()
    $displayName = ($suffix + " Azure PCI PaaS Sample")
    $sslORnon_ssl = 'non-ssl'
    $automationaccname = "automationacc" + ((Get-Date).ToUniversalTime()).ToString('MMddHHmm')
    $automationADApplication = "AutomationAppl" + ((Get-Date).ToUniversalTime()).ToString('MMddHHmm')
    $deploymentName = "PCI-Deploy-"+ ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
    $_artifactslocationSasToken = "null"
    $clientIPAddress = Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip
    $databaseName = "ContosoPayments"
    $artifactsStorageAccKeyType = "StorageAccessKey"
    $cmkName = "CMK1" 
    $cekName = "CEK1" 
    $keyName = "CMK1" 
    Set-Variable ArtifactsLocationName '_artifactsLocation' -Option ReadOnly -Force
    Set-Variable ArtifactsLocationSasTokenName '_artifactsLocationSasToken' -Option ReadOnly -Force
    $storageContainerName = 'pci-container'
    $storageResourceGroupName = 'pcistageartifacts' + ((Get-Date).ToUniversalTime()).ToString('MMddHHmm')                 

    # Generating common password 
    $newPassword = New-RandomPassword
    $secNewPasswd = ConvertTo-SecureString $newPassword -AsPlainText -Force

    ####################################################################################################

    $subId = ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    $context = Set-AzureRmContext -SubscriptionId $subscriptionId
    $userPrincipalName = $context.Account.Id
    $artifactsStorageAcc = "stage$subId" 
    $sqlBacpacUri = "http://$artifactsStorageAcc.blob.core.windows.net/$storageContainerName/artifacts/ContosoPayments.bacpac"
    $sqlsmodll = (Get-ChildItem "$env:programfiles\WindowsPowerShell\Modules\SqlServer" -Recurse -File -Filter "Microsoft.SqlServer.Smo.dll").FullName

    try {
        # Register RPs
        $resourceProviders = @(
            "Microsoft.Storage",
            "Microsoft.Compute",
            "Microsoft.KeyVault",
            "Microsoft.Network",
            "Microsoft.Web"
        )
        if ($resourceProviders.length) {
            Write-Host -ForegroundColor Yellow "`t* Registering resource providers."
            foreach($resourceProvider in $resourceProviders) {
                RegisterRP($resourceProvider);
            }
        }
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not register the necessary resource providers. Verify the correct PowerShell modules are available in the session before attempting to run the script again."
        Break
    }
    
    try {
        # Create a storage account name if none was provided
        $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $artifactsStorageAcc})

        # Create the storage account if it doesn't already exist
        if($StorageAccount -eq $null){
            Write-Host -ForegroundColor Yellow "`t* Creating an Artifacts Resource group & an associated Storage account."
            New-AzureRmResourceGroup -Location "$location" -Name $storageResourceGroupName -Force | Out-Null
            $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $artifactsStorageAcc -Type 'Standard_LRS' -ResourceGroupName $storageResourceGroupName -Location "$location"
        }
        $StorageAccountContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $artifactsStorageAcc}).Context
        $_artifactsLocation = $StorageAccountContext.BlobEndPoint + $storageContainerName
        
        # Copy files from the local storage staging location to the storage account container
        New-AzureStorageContainer -Name $storageContainerName -Context $StorageAccountContext -Permission Container -ErrorAction SilentlyContinue | Out-Null
        $ArtifactFilePaths = Get-ChildItem $pwd\nested -Recurse -File | ForEach-Object -Process {$_.FullName}
        foreach ($SourcePath in $ArtifactFilePaths) {
            $BlobName = $SourcePath.Substring(($PWD.Path).Length + 1)
            Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $storageContainerName -Context $StorageAccountContext -Force | Out-Null
        }
        $ArtifactFilePaths = Get-ChildItem $pwd\artifacts -Recurse -File | ForEach-Object -Process {$_.FullName}
        foreach ($SourcePath in $ArtifactFilePaths) {
            $BlobName = $SourcePath.Substring(($PWD.Path).Length + 1)
            Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $storageContainerName -Context $StorageAccountContext -Force | Out-Null
        }

        # Retrieve Access Key 
        $artifactsStorageAccKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -name $storageAccount.StorageAccountName -ErrorAction Stop)[0].value 
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not create an artifacts storage account for storing configuration resources. Remove any previously created assets before attempting to run the script again."
        Break
    }

    try {
        ########### Creating Users in Azure AD ###########
        Write-Host -ForegroundColor Green ("`n Step 3: Creating AAD Users for SQL AD Admin & receptionist users for testing various scenarios" )
        
        # Creating SQL Admin & Receptionist Account if does not exist already.
        Write-Host -ForegroundColor Yellow "`t* Checking if $sqlAdAdminUserName already exists in the directory."
        $sqlADAdminDetails = Get-MsolUser -UserPrincipalName $sqlAdAdminUserName -ErrorAction SilentlyContinue
        $sqlADAdminObjectId= $sqlADAdminDetails.ObjectID
        if ($sqlADAdminObjectId -eq $null)  
        {    
            $sqlADAdminDetails = New-MsolUser -UserPrincipalName $sqlAdAdminUserName -DisplayName "SQL AD Administrator PCI Samples" -FirstName "SQL AD Administrator" -LastName "PCI Samples" -PasswordNeverExpires $false -StrongPasswordRequired $true
            $sqlADAdminObjectId= $sqlADAdminDetails.ObjectID
            # Make the SQL Account a Global AD Administrator
            Write-Host -ForegroundColor Yellow "`t* Promoting the SQL AD Administrator account to a Company Administrator role."
            Add-MsolRoleMember -RoleName "Company Administrator" -RoleMemberObjectId $sqlADAdminObjectId
        }

        # Setting up new password for SQL Global AD Admin.
        Write-Host -ForegroundColor Yellow "`t* Setting up a new password for the SQL AD Administrator account."
        Set-MsolUserPassword -userPrincipalName $sqlAdAdminUserName -NewPassword $newPassword -ForceChangePassword $false | Out-Null
        Start-Sleep -Seconds 30

        # Grant 'SQL Global AD Admin' access to the Azure subscription
        $RoleAssignment = Get-AzureRmRoleAssignment -ObjectId $sqlADAdminObjectId -RoleDefinitionName Contributor -Scope ('/subscriptions/'+ $subscriptionID) -ErrorAction SilentlyContinue
        if ($RoleAssignment -eq $null) {
            Write-Host -ForegroundColor Yellow "`t* Assigning $($sqlADAdminDetails.SignInName) with Contributor role."
            Write-Host -ForegroundColor Yellow "`t`t-> On Subscription - $subscriptionID."
            New-AzureRmRoleAssignment -ObjectId $sqlADAdminObjectId -RoleDefinitionName Contributor -Scope ('/subscriptions/' + $subscriptionID ) | Out-Null
            if (Get-AzureRmRoleAssignment -ObjectId $sqlADAdminObjectId -RoleDefinitionName Contributor -Scope ('/subscriptions/'+ $subscriptionID)) {
                Write-Host -ForegroundColor Cyan "`t`t-> $($sqlADAdminDetails.SignInName) has been successfully assigned with Contributor role."
            }
        }
        else { 
            Write-Host -ForegroundColor Cyan "`t* $($sqlADAdminDetails.SignInName) has already been assigned with Contributor role."
        }

        Write-Host -ForegroundColor Yellow "`t* Checking if $receptionistUserName already exists in the directory."
        $receptionistUserObjectId = (Get-MsolUser -UserPrincipalName $receptionistUserName -ErrorAction SilentlyContinue).ObjectID
        if ($receptionistUserObjectId -eq $null) {    
            New-MsolUser -UserPrincipalName $receptionistUserName -DisplayName "Edna Benson" -FirstName "Edna" -LastName "Benson" -PasswordNeverExpires $false -StrongPasswordRequired $true | Out-Null
        }
        # Setting up new password for Receptionist user account.
        Write-Host -ForegroundColor Yellow "`t* Setting up a new password for the Receptionist user account."
        Set-MsolUserPassword -userPrincipalName $receptionistUserName -NewPassword $newPassword -ForceChangePassword $false | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not create necessary Azure Active Directory users for supporting the deployment. Remove any previously created assets before attempting to run the script again." 
        Break
    }

    try {
        ########### Create Azure Active Directory apps in default directory ###########
        Write-Host -ForegroundColor Green ("`n Step 4: Creating an Azure AD application in the default directory") 
        # Get tenant ID
        $tenantID = (Get-AzureRmContext).Tenant.TenantId
        if ($tenantID -eq $null) {
            $tenantID = (Get-AzureRmContext).Tenant.Id
        }

        # Create Active Directory Application
        Write-Host -ForegroundColor Yellow ("`t* Step 4.1: Attempting to create an Azure AD application.") 
        $azureAdApplication = New-AzureRmADApplication -DisplayName $displayName -HomePage $pciAppServiceURL -IdentifierUris $pciAppServiceURL -Password $secnewPasswd
        $azureAdApplicationClientId = $azureAdApplication.ApplicationId.Guid
        $azureAdApplicationObjectId = $azureAdApplication.ObjectId.Guid            
        Write-Host -ForegroundColor Cyan ("`t`t-> Azure Active Directory application creation successful.") 
        Write-Host -ForegroundColor Yellow ("`t`t`t* AppID is $($azureAdApplication.ApplicationId).")

        # Create a service principal for the AD Application and add a Reader role to the principal 
        Write-Host -ForegroundColor Yellow ("`t* Step 4.2: Attempting to create a Service Principal.") 
        $principal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
        Start-Sleep -s 30 # Wait till the ServicePrincipal is completely created. Usually takes 20+secs. Needed as Role assignment needs a fully deployed servicePrincipal
        Write-Host -ForegroundColor Cyan ("`t`t-> Service Principal creation successful - $($principal.DisplayName).")
        Start-Sleep -Seconds 30

        # Assign Reader Role to Service Principal on Azure Subscription
        $scopedSubs = ("/subscriptions/" + $subscriptionID)
        Write-Host -ForegroundColor Yellow ("`t* Step 4.3: Attempting Reader role assignment." ) 
        New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $azureAdApplication.ApplicationId.Guid -Scope $scopedSubs | Out-Null
        Write-Host -ForegroundColor Cyan  ("`t`t-> Reader role assignment successful." )    
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not create the Azure Active Directory application for supporting the deployment. Remove any previously created assets before attempting to run the script again." 
        Break
    }

    try {
        ########### Create Self-signed certificate for ASE ILB and Application Gateway ###########
        Write-Host -ForegroundColor Green "`n Step 5: Create a self-signed certificate for use with ASE ILB and Azure Application Gateway"

            $certData = "null"
            $certPassword = "null"

            ### Generate self-signed certificate for ASE ILB and convert into base64 string
            Write-Host -ForegroundColor Yellow "`t* Creating a self-signed certificate for ASE Internal Load Balancer (ILB)."
            $fileName = "aseilbcertificate"
            $certificate = New-SelfSignedCertificateEx -Subject "CN=*.ase.$customHostName" -SAN "*.ase.$customHostName", "*.scm.ase.$customHostName" -EKU "Server Authentication", "Client authentication" `
            -NotAfter $((Get-Date).AddYears(5)) -KU "KeyEncipherment, DigitalSignature" -SignatureAlgorithm SHA256 -Exportable
            $certThumbprint = "cert:\CurrentUser\my\" + $certificate.Thumbprint
            Write-Host -ForegroundColor Cyan "`t`t-> Certificate created successfully. Exporting certificate into .pfx & .cer format."
            Export-PfxCertificate -cert $certThumbprint -FilePath "$scriptFolder\Certificates\$fileName.pfx" -Password $secNewPasswd | Out-null
            Export-Certificate -Cert $certThumbprint -FilePath "$scriptFolder\Certificates\$fileName.cer" | Out-null
            Start-Sleep -Seconds 3
            $aseCertData = Convert-Certificate -certPath "$scriptFolder\Certificates\$fileName.cer"
            $asePfxBlobString = Convert-Certificate -certPath "$scriptFolder\Certificates\$fileName.pfx"
            $asePfxPassword = $newPassword
            $aseCertThumbprint = $certificate.Thumbprint
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not create the self-signed certificates for supporting the deployment. Remove any previously created assets before attempting to run the script again." 
        Break
    }

    # Create Resource group, Automation account, RunAs Account for Runbook.
    try {
        Write-Host -ForegroundColor Green "`n Step 6: Preparing to deploy the ARM templates"
        # Create Resource Group
        Write-Host -ForegroundColor Yellow "`t* Creating a new Resource group - $resourceGroupName at $location."
        New-AzureRmResourceGroup -Name $resourceGroupName -location $location -Force | Out-Null
        Write-Host -ForegroundColor Cyan "`t`t-> Resource group - $resourceGroupName has been created successfully."
        Start-Sleep -Seconds 5
    }

    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not create the Azure Resource group for the deployment. Remove any previously created assets before attempting to run the script again." 
        Break
    }

    # Initiate template deployment
    try {
        Write-Host -ForegroundColor Green "`n Step 7: Initiating ARM template deployment"

        # Submitting templte deployment to new powershell session
        Write-Host -ForegroundColor Yellow "`t* Submitting deployment..."

        # Parameters for the deployment 
        $OptionalParameters = New-Object -TypeName Hashtable
            $OptionalParameters["_artifactsLocation"] = "$_artifactsLocation"
            $OptionalParameters["_artifactsLocationSasToken"] = ""
            $OptionalParameters["sslORnon_ssl"] = "$sslORnon_ssl"  
            $OptionalParameters["certData"] = "$certData" 
            $OptionalParameters["certPassword"] = "$newPassword"  # Auto-generated
            $OptionalParameters["aseCertData"] = "$aseCertData"
            $OptionalParameters["asePfxBlobString"] = "$asePfxBlobString"
            $OptionalParameters["asePfxPassword"] = "$asePfxPassword" 
            $OptionalParameters["aseCertThumbprint"] = "$aseCertThumbprint" 
            $OptionalParameters["bastionHostAdministratorPassword"] = "$newPassword"  # Auto-generated
            $OptionalParameters["sqlAdministratorLoginPassword"] = "$newPassword"  # Auto-generated
            $OptionalParameters["sqlThreatDetectionAlertEmailAddress"] = "$sqlThreatDetectionAlertEmailAddress"
            $OptionalParameters["automationAccountName"] = "$automationAccountName"
            $OptionalParameters["customHostName"] = "$customHostName"
            $OptionalParameters["azureAdApplicationClientId"] = "$azureAdApplicationClientId"
            $OptionalParameters["azureAdApplicationClientSecret"] = "$newPassword"  # Auto-generated
            $OptionalParameters["azureAdApplicationObjectId"] = "$azureAdApplicationObjectId"
            $OptionalParameters["sqlAdAdminUserName"] = "$sqlAdAdminUserName"
            $OptionalParameters["sqlAdAdminUserPassword"] = "$newPassword"  # Auto-generated

        # Deploy to Azure    
        New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -Mode Incremental -TemplateParameterObject $OptionalParameters -TemplateFile "$scriptFolder\azuredeploydemo.json" -DeploymentDebugLogLevel All -Force -AsJob | Out-Null

        # Deployment Status Update
        Write-Host "`t`t-> Waiting for deployment '$deploymentName' to submit... " -ForegroundColor Yellow
        $count=0
        $status=1
        do {
            if ($count -lt 10) {                
                Write-Host "`t`t-> Checking deployment in 60 secs..." -ForegroundColor Yellow
                Start-sleep -seconds 60
                $count +=1
            }
            else {
                $status=0
                Break
            }
        }
        until ((Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -ErrorAction SilentlyContinue ) -ne $null)             
        if ($status) {
            Write-Host -ForegroundColor Cyan "`t* Deployment '$deploymentName' has been submitted successfully."
        }            
        else {
            Write-Host -ForegroundColor Magenta "`t-> The deployment failed to submit. Review all input parameters and attempt to redeploy the solution."
        }
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Deployment failed at a templated step. Review the error in the Azure portal. Before redeploying, remove any previously created assets and attempt the deployment again."
        Break
    }

    # Loop to check SQL server deployment.
    try {
        Write-Host -ForegroundColor Yellow "`t`t-> Waiting for deployment 'deploy-SQLServerSQLDb' to submit..."            
        do {
            Write-Host -ForegroundColor Yellow "`t`t-> Checking deployment in 60 secs..." 
            Start-sleep -seconds 60
        }
        until ((Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name 'deploy-SQLServerSQLDb' -ErrorAction SilentlyContinue) -ne $null) 

        Write-Host -ForegroundColor Cyan "`t* Deployment 'deploy-SQLServerSQLDb' has been submitted successfully."

        do {
            Write-Host -ForegroundColor Yellow "`t`t-> Deployment 'deploy-SQLServerSQLDb' is currently running. Checking deployment in 60 seconds..."
            Start-Sleep -Seconds 60
        }

        While ((Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name 'deploy-SQLServerSQLDb').ProvisioningState -notin ('Failed','Succeeded'))

        if ((Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name deploy-SQLServerSQLDb).ProvisioningState -eq 'Succeeded') {
            Write-Host -ForegroundColor Cyan "`t* Deployment 'deploy-SQLServerSQLDb' has completed successfully."
        }
        else {
            Write-Host -ForegroundColor Magenta "Deployment 'deploy-SQLServerSQLDb' has failed. Please resolve any reported errors through the portal, and attempt to redeploy the solution."
        }
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> ARM template submission for 'deploy-SQLServerSQLDb' has failed. Please resolve any reported errors through the portal, and attempt to redeploy the solution."
        Break
    }

    # Updating SQL server firewall rule
    Write-Host -ForegroundColor Green "`n Step 8: Updating the SQL server firewall rules"
    try {
        # Getting SqlServer resource object
        Write-Host -ForegroundColor Yellow "`t* Retrieving the SQL server resource object."
        $allResource = (Get-AzureRmResource | ? ResourceGroupName -EQ $resourceGroupName)
        $sqlServerName =  ($allResource | ? ResourceType -eq 'Microsoft.Sql/servers').ResourceName
        Write-Host -ForegroundColor Yellow ("`t* Updating the SQL firewall with your client IP address.")
        Write-Host -ForegroundColor Cyan "`t`t-> Your client IP address is $clientIPAddress."
        $unqiueid = ((Get-Date).ToUniversalTime()).ToString('MMddHHmm')
        New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -FirewallRuleName "ClientIpRule$unqiueid" -StartIpAddress $clientIPAddress -EndIpAddress $clientIPAddress | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not update SQL server firewall rules. Please resolve any reported errors through the portal, and attempt to redeploy the solution."   
        Break
    }

    # Import SQL bacpac and update Azure SQL DB Data masking policy
    Write-Host -ForegroundColor Green "`n Step 9: Importing the example SQL bacpac and updating the Azure SQL DB Data Masking policy"
    try {
        # Getting Keyvault reource object
        Write-Host -ForegroundColor Yellow "`t* Getting the Key Vault resource object."
        $keyVaultName = ($allResource | ? ResourceType -eq 'Microsoft.KeyVault/vaults').ResourceName
        # Importing bacpac file
        Write-Host -ForegroundColor Yellow ("`t* Importing the SQL backpac from the artifacts storage account." ) 
        New-AzureRmSqlDatabaseImport -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -DatabaseName $databaseName -StorageKeytype $artifactsStorageAccKeyType -StorageKey $artifactsStorageAccKey -StorageUri $sqlBacpacUri -AdministratorLogin 'sqladmin' -AdministratorLoginPassword $secNewPasswd -Edition Standard -ServiceObjectiveName S0 -DatabaseMaxSizeBytes 50000 | Out-Null
        Start-Sleep -s 100
        Write-Host -ForegroundColor Yellow ("`t* Updating Azure SQL DB Data Masking policy on the FirstName & LastName columns." )
        Set-AzureRmSqlDatabaseDataMaskingPolicy -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -DatabaseName $databaseName -DataMaskingState Enabled
        Start-Sleep -s 30
        New-AzureRmSqlDatabaseDataMaskingRule -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -DatabaseName $databaseName -SchemaName "dbo" -TableName "Customers" -ColumnName "FirstName" -MaskingFunction Default
        New-AzureRmSqlDatabaseDataMaskingRule -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -DatabaseName $databaseName -SchemaName "dbo" -TableName "Customers" -ColumnName "LastName" -MaskingFunction Default
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not import the SQL bacpac and update the Azure SQL DB Data Masking policy. Please resolve any reported errors through the portal, and attempt to redeploy the solution."   
        Break
    }
    
    # Add an Azure Active Directory administrator for SQL
    try {
        Write-Host -ForegroundColor Green ("`n Step 10: Updating access to SQL Server for the Azure Active Directory administrator account")
        Write-Host -ForegroundColor Yellow ("`t* Granting SQL Server Active Directory Administrator access to $SqlAdAdminUserName.") 
        Set-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DisplayName $SqlAdAdminUserName | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not grant SQL administrative rights. Please resolve any reported errors through the portal, and attempt to redeploy the solution."   
        Break
    }

    # Encrypting Credit card information within database
    try {
        Write-Host ("`n Step 11: Encrypt the SQL DB credit card information column" ) -ForegroundColor Green
        # Connect to your database.
        Add-Type -Path $sqlsmodll
        Write-Host -ForegroundColor Yellow "`t* Connecting to database - $databaseName on $sqlServerName."
        $connStr = "Server=tcp:" + $sqlServerName + ".database.windows.net,1433;Initial Catalog=" + "`"" + $databaseName + "`"" + ";Persist Security Info=False;User ID=" + "`"" + "sqladmin" + "`"" + ";Password=`"" + "$newPassword" + "`"" + ";MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $connection.ConnectionString = $connStr
        $connection.Connect()
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)
        $database = $server.Databases[$databaseName]
        Write-Host -ForegroundColor Cyan "`t`t-> Connected to database - $databaseName on $sqlServerName."

        # Granting Users & ServicePrincipal full access on Keyvault
        Write-Host -ForegroundColor Yellow ("`t* Granting Key Vault access permissions to users and service principals.") 
        Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -UserPrincipalName $userPrincipalName -ResourceGroupName $resourceGroupName -PermissionsToKeys all  -PermissionsToSecrets all
        Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -UserPrincipalName $SqlAdAdminUserName -ResourceGroupName $resourceGroupName -PermissionsToKeys all -PermissionsToSecrets all 
        Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -ServicePrincipalName $azureAdApplicationClientId -ResourceGroupName $resourceGroupName -PermissionsToKeys all -PermissionsToSecrets all
        Write-Host -ForegroundColor Cyan ("`t`t-> Granted permissions to users and serviceprincipals.") 

        # Creating KeyVault Key to encrypt DB
        Write-Host -ForegroundColor Yellow "`t* Creating a new Key Vault key."
        $key = (Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyName -Destination 'Software').ID

        # Switching SQL commands context to the AD Application
        Write-Host -ForegroundColor Yellow "`t* Creating a SQL Column Master Key & a SQL Column Encryption Key."
        $cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyURL $key
        $sqlMasterKey = Get-SqlColumnMasterKey -Name $cmkName -InputObject $database -ErrorAction SilentlyContinue
        if ($sqlMasterKey){Write-Host -ForegroundColor Yellow "`t* SQL Master Key $cmkName already exists."} 
        else {
            try {
                New-SqlColumnMasterKey -Name $cmkName -InputObject $database -ColumnMasterKeySettings $cmkSettings | Out-Null
                Write-Host ("`t* Creating a new SQL Column Master Key.") -ForegroundColor Yellow
            }
            catch {
                Write-Host -ForegroundColor Magenta "`t-> Could not create a new SQL Column Master Key. Please verify deployment details, remove any previously deployed assets specific to this example, and attempt a new deployment."
                break
            }
        }
        Add-SqlAzureAuthenticationContext -ClientID $azureAdApplicationClientId -Secret $newPassword -Tenant $tenantID
        try {
            New-SqlColumnEncryptionKey -Name $cekName -InputObject $database -ColumnMasterKey $cmkName | Out-Null
            Write-Host -ForegroundColor Yellow ("`t* Creating a new SQL Column Encryption Key.") 
        }
        catch {
            Write-Host -ForegroundColor Magenta "`t-> Could not create a new SQL Column Encryption Key. Please verify deployment details, remove any previously deployed assets specific to this example, and attempt a new deployment."
            break
        }

        Write-Host -ForegroundColor Cyan "`t* SQL encryption has been successfully created."
        Write-Host -ForegroundColor Yellow "`t* Encrypting SQL columns..."

        # Encrypt the selected columns (or re-encrypt, if they are already encrypted using keys/encrypt types, different than the specified keys/types.
        $ces = @()
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.Customers.CreditCard_Number" -EncryptionType "Deterministic" -EncryptionKey $cekName
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.Customers.CreditCard_Code" -EncryptionType "Deterministic" -EncryptionKey $cekName
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.Customers.CreditCard_Expiration" -EncryptionType "Deterministic" -EncryptionKey $cekName
        Set-SqlColumnEncryption -InputObject $database -ColumnEncryptionSettings $ces
        Write-Host -ForegroundColor Cyan "`t`t-> Column CreditCard_Number, CreditCard_Code, CreditCard_Expiration have been successfully encrypted."            
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Column encryption has failed."
        Write-Host -ForegroundColor Magenta "`t-> Could not successfully encrypt SQL columns. Please verify deployment details, remove any previously deployed assets specific to this example, and attempt a new deployment."
        Break
    }

    # Enabling the Azure Security Center Policies.
    try {
        Write-Host -ForegroundColor Green ("`n Step 12: Enabling policies for Azure Security Center" )
        
        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        Write-Host -ForegroundColor Yellow "`t* Checking AzureRM Context."
        $currentAzureContext = Get-AzureRmContext
        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        
        Write-Host -ForegroundColor Yellow "`t* Getting access token and setting variables to invoke the REST API." 
        Write-Host -ForegroundColor Yellow "`t* Getting access token for tenant $($currentAzureContext.Subscription.TenantId)." 
        $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
        $token = $token.AccessToken
        $Script:asc_clientId = "1950a258-227b-4e31-a9cf-717495945fc2"              # Well-known client ID for Azure PowerShell
        $Script:asc_redirectUri = "urn:ietf:wg:oauth:2.0:oob"                      # Redirect URI for Azure PowerShell
        $Script:asc_resourceAppIdURI = "https://management.azure.com/"             # Resource URI for REST API
        $Script:asc_url = 'management.azure.com'                                   # Well-known URL endpoint
        $Script:asc_version = "2015-06-01-preview"                                 # Default API Version
        $PolicyName = 'default'
        $asc_APIVersion = "?api-version=$asc_version" #Build version syntax.
        $asc_endpoint = 'policies' #Set endpoint.
        
        Write-Host -ForegroundColor Yellow "`t* Creating an authorization header."
        Set-Variable -Name asc_requestHeader -Scope Script -Value @{"Authorization" = "Bearer $token"}
        Set-Variable -Name asc_subscriptionId -Scope Script -Value $currentAzureContext.Subscription.Id
        
        #Retrieve existing policy and build hashtable
        Write-Host -ForegroundColor Yellow "`t* Retrieving data for $PolicyName policy..."
        $asc_uri = "https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/$asc_endpoint/$PolicyName$asc_APIVersion"
        $asc_request = Invoke-RestMethod -Uri $asc_uri -Method Get -Headers $asc_requestHeader
        $a = $asc_request 
        $json_policy = @{
            properties = @{
                policyLevel = $a.properties.policyLevel
                policyName = $a.properties.name
                unique = $a.properties.unique
                logCollection = $a.properties.logCollection
                recommendations = $a.properties.recommendations
                logsConfiguration = $a.properties.logsConfiguration
                omsWorkspaceConfiguration = $a.properties.omsWorkspaceConfiguration
                securityContactConfiguration = $a.properties.securityContactConfiguration
                pricingConfiguration = $a.properties.pricingConfiguration
            }
        }
        if ($json_policy.properties.recommendations -eq $null) {Write-Error "The specified policy does not exist."; return}
        
        #Set all params to on,
        $json_policy.properties.recommendations.patch = "On"
        $json_policy.properties.recommendations.baseline = "On"
        $json_policy.properties.recommendations.antimalware = "On"
        $json_policy.properties.recommendations.diskEncryption = "On"
        $json_policy.properties.recommendations.acls = "On"
        $json_policy.properties.recommendations.nsgs = "On"
        $json_policy.properties.recommendations.waf = "On"
        $json_policy.properties.recommendations.sqlAuditing = "On"
        $json_policy.properties.recommendations.sqlTde = "On"
        $json_policy.properties.recommendations.ngfw = "On"
        $json_policy.properties.recommendations.vulnerabilityAssessment = "On"
        $json_policy.properties.recommendations.storageEncryption = "On"
        $json_policy.properties.recommendations.jitNetworkAccess = "On"
        $json_policy.properties.recommendations.appWhitelisting = "On"
        $json_policy.properties.securityContactConfiguration.areNotificationsOn = $true
        $json_policy.properties.securityContactConfiguration.sendToAdminOn = $true
        $json_policy.properties.logCollection = "On"
        $json_policy.properties.pricingConfiguration.selectedPricingTier = "Standard"
        try {
            $json_policy.properties.securityContactConfiguration.securityContactEmails = $siteAdminUserName
        }
        catch {
            $json_policy.properties.securityContactConfiguration | Add-Member -NotePropertyName securityContactEmails -NotePropertyValue $siteAdminUserName
        }
        Start-Sleep 5
        
        Write-Host -ForegroundColor Yellow "`t* Enabling ASC Policies..."
        $JSON = ($json_policy | ConvertTo-Json -Depth 3)
        $asc_uri = "https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/$asc_endpoint/$PolicyName$asc_APIVersion"
        $result = Invoke-WebRequest -Uri $asc_uri -Method Put -Headers $asc_requestHeader -Body $JSON -UseBasicParsing -ContentType "application/json"
        
    }
    catch {
        Write-Host -ForegroundColor Magenta "`t-> Could not set policies for Azure Security Center. Please verify deployment details, remove any previously deployed assets specific to this example, and attempt a new deployment."
        Break
    }

#########################################################################################################################################################################################

Write-Host -ForegroundColor Green "`n###############################         Deployment Running         ############################### `n "

Write-Host -ForegroundColor Yellow " The deployment for the Azure infrastructure of the sample PCI Contoso Web Store example is currently running." 
Write-Host -ForegroundColor Yellow "`n Verify the running status of the deployment in the Azure portal." 
Write-Host -ForegroundColor Yellow " Deployment times will vary, depending on the Azure App Service Environment. Deployments may take up to 2.5 hours."
Write-Host -ForegroundColor Yellow "`n For additional PCI compliance details, see https://aka.ms/pciblueprintprocessingoverview for more information. `n "
Write-Host -ForegroundColor Yellow " The sample Contoso Web Store application can be loaded into the deployed environment through the bastion host. `n " 
Write-Host -ForegroundColor Yellow " Deployment details will be printed to the PowerShell console for interacting with the Azure environment. `n " 

Write-Host -ForegroundColor Yellow "                                    Press any key to continue... `n " 

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host -ForegroundColor Green "`n###############################        Deployment Variables        ###############################"

    $templateInputTable = New-Object -TypeName Hashtable
    $templateInputTable.Add('sslORnon_ssl',$sslORnon_ssl)
    $templateInputTable.Add('certData',$certData)
    $templateInputTable.Add('certPassword',$certPassword)
    $templateInputTable.Add('aseCertData',$aseCertData)
    $templateInputTable.Add('asePfxBlobString',$asePfxBlobString)
    $templateInputTable.Add('asePfxPassword',$asePfxPassword)
    $templateInputTable.Add('aseCertThumbprint',$aseCertThumbprint)
    $templateInputTable.Add('bastionHostAdministratorUserName','bastionadmin')
    $templateInputTable.Add('bastionHostAdministratorPassword',$newPassword)
    $templateInputTable.Add('sqlAdministratorLoginUserName','sqladmin')
    $templateInputTable.Add('sqlAdministratorLoginPassword',$newPassword)
    $templateInputTable.Add('sqlThreatDetectionAlertEmailAddress',$sqlTDAlertEmailAddress)
    $templateInputTable.Add('customHostName',$customHostName)
    $templateInputTable.Add('azureAdApplicationClientId',$azureAdApplicationClientId)
    $templateInputTable.Add('azureAdApplicationClientSecret',$newPassword)        
    $templateInputTable.Add('azureAdApplicationObjectId',$azureAdApplicationObjectId)
    $templateInputTable.Add('sqlAdAdminUserName',$sqlAdAdminUserName)
    $templateInputTable.Add('sqlAdAdminUserPassword',$newPassword)
    $templateInputTable | Sort-Object Name  | Format-Table -AutoSize -Wrap -Expand EnumOnly 

Write-Host -ForegroundColor Green "`n###############################        Deployment Accounts         ###############################"

    $outputTable = New-Object -TypeName Hashtable
    $outputTable.Add('tenantId',$tenantID)
    $outputTable.Add('subscriptionId',$subscriptionID)
    $outputTable.Add('receptionistUserName',$receptionistUserName)
    $outputTable.Add('receptionistPassword',$newPassword)
    $outputTable | Sort-Object Name  | Format-Table -AutoSize -Wrap -Expand EnumOnly 

    #Merging the Two Tables 
    $MergedtemplateoutputTable = $templateInputTable + $outputTable

####################  End of Script ###############################