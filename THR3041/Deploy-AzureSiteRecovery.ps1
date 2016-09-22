<#   
           .SYNOPSIS 
           Script to automatically setup an Azur Site Recovery Vault in Azure
		   Demo for Microsoft Ignite 2016 in Atlanta
		   Created by: Eric berg
		   Blog: http://www.ericberg.de
		   Twitter: @ericberg_de

           .DESCRIPTION
			This script creates everything erequired for doing ASR and replicates 
			two choosen VMs to Azure.
			
			It is just an example of what is possible in Azure

			You can reuse, extend and configure it!
    
		   .PARAMETER $SubscriptionName
           Insert your subscription name

		   .PARAMETER $ASRVaultName
           Specify a name for you ASR Vault

		   .PARAMETER $ResourceGroupName
           Sepcify the name of the resource group

		   .PARAMETER $Location
           Sepcify a location for your deployment

		   .PARAMETER $HVSiteName
           Name you Hyper-V Site

		   .PARAMETER $RegKeyPath
           Specify the download for the vault credentials

		   .PARAMETER $storageaccount
           Specify a name for you storage account. Also change name in .json file!

		   .PARAMETER $ReplicationFrequencyInSeconds
           Choose replication frequency.

		   .PARAMETER $PolicyName
           Define a name for your replication policy

		   .PARAMETER $VMFriendlyName01
           Specify the name of your first VM

		   .PARAMETER $VMFriendlyName02
           Specify the name of your second VM

		   .PARAMETER $OStype
           Choose your OS Type

           .EXAMPLE
           C:\PS> .\Deploy-AzureSiteRecovery.ps1

           .EXAMPLE
           C:\PS> .\Deploy-AzureSiteRecovery.ps1 -ResourceGroupName "Demo" -HVSiteName "HV Site"
#>

Param(
	[string] $SubscriptionName = "Visual Studio Enterprise mit MSDN",
	[string] $ASRVaultName = "IgniteDemoASRVault",
	[string] $ResourceGroupName = "IgniteDemoASR",
	[string] $Location = "East US",
	[string] $HVSiteName = "Ignite-HV01",
	[string] $RegKeyPath = "D:\Demo\",
	[string] $source = "https://aka.ms/downloaddra",
	[string] $destination = "D:\Demo\AzureSiteRecoveryProvider.exe",
	[string] $storageaccount = "igniteasrdemostor",
	[string] $ReplicationFrequencyInSeconds = "300",
	[string] $PolicyName = “IgniteRP”,
	[int] $Recoverypoints = 3,
	[string] $VMFriendlyName01 = "Nano01",
	[string] $VMFriendlyName02 = "Nano02",
	[string] $OStype = "Windows"
)

$starttime = get-date -Format "hh:mm:ss"
Write-Host "Script started at $starttime" -ForegroundColor Green

#connect
Login-AzureRmAccount 

#select
Select-AzureRmSubscription -SubscriptionName $SubscriptionName

#deploy prereq
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force -ErrorAction Stop 

Write-Host "ResourceGroup $ResourceGroupName created" -ForegroundColor Green

New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageaccount -Type Standard_LRS -Location $Location

Write-Host "Storage Account $storageaccount created" -ForegroundColor Green

#check providers
$ProviderRecoveryServices = Get-AzureRmResourceProvider -ProviderNamespace Microsoft.RecoveryServices -Location $Location
$ProviderSiteRecovery = Get-AzureRmResourceProvider -ProviderNamespace Microsoft.SiteRecovery

if($ProviderRecoveryServices.RegistrationState -eq "Registered")
{
	Write-Host "Provider Microsoft.RecoveryServices already registered" -ForegroundColor Green
}
else
{
    Write-Host "Provider Microsoft.RecoveryServices not registered" -ForegroundColor Yellow
    Write-Host "Registering Provider Microsoft.RecoveryServices..." -ForegroundColor Yellow

	Register-AzureRmResourceProvider -ProviderNamespace Microsoft.RecoveryServices

    Write-Host "Provider Microsoft.RecoveryServices succesfully registered" -ForegroundColor Green
}

if($ProviderSiteRecovery.RegistrationState -eq "Registered")
{
	Write-Host "Provider Microsoft.SiteRecovery already registered" -ForegroundColor Green
}
else
{
    Write-Host "Provider Microsoft.SiteRecovery not registered" -ForegroundColor Yellow
    Write-Host "Registering Provider Microsoft.SiteRecovery..." -ForegroundColor Yellow

	Register-AzureRmResourceProvider -ProviderNamespace Microsoft.SiteRecovery

    Write-Host "Provider Microsoft.SiteRecovery succesfully registered" -ForegroundColor Green
}

#create ASR Vault
$vault = New-AzureRmRecoveryServicesVault -Name $ASRVaultName -ResourceGroupName $ResourceGroupName -Location $Location

Write-Host "ASR Vault $ASRVaultName is created in $Location!" -ForegroundColor Green

#set context
Set-AzureRmSiteRecoveryVaultSettings -ARSVault $vault

#create Hyper-V Site
$HVSiteJob = New-AzureRmSiteRecoverySite -Name $HVSiteName

#wait for job to finish
do
{
    $state = Get-AzureRmSiteRecoveryJob -Name $HVSiteJob.Name | select -ExpandProperty State
}
until ($state -eq "Succeeded")

Write-Host "New Hyper-V Site $HVSitename registered!" -ForegroundColor Green

#registration key download
$SiteIdentifier = Get-AzureRmSiteRecoverySite -Name $HVSiteName | Select -ExpandProperty SiteIdentifier
Get-AzureRmRecoveryServicesVaultSettingsFile -Vault $vault -SiteIdentifier $SiteIdentifier -SiteFriendlyName $HVSiteName -Path $RegKeyPath

Write-Host "VaultSettingsFile for  $ASRVaultName downloaded!" -ForegroundColor Green

#download ASR Agent
Write-Host "Downloading actual ASR Provider!" -ForegroundColor Green
Invoke-WebRequest $source -OutFile $destination
Write-Host "ASR Provider downloaded successfully" -ForegroundColor Green

#Install Agent
Start-Process $destination -Wait

Write-Host "Manual configuration of ASR Provider completed" -ForegroundColor Green

#check regitration
do
{
    $HVServerState = Get-AzureRmSiteRecoveryServer -FriendlyName $HVSiteName | select -ExpandProperty Connected
}
until ($HVServerState -eq $True)

Write-Host "New Hyper-V Host $HVSitename is connected!" -ForegroundColor Green

#Replication Policy
$storageaccountID = Get-AzureRmStorageAccount -Name $storageaccount -ResourceGroupName $ResourceGroupName | Select -ExpandProperty Id
$PolicyResult = New-AzureRmSiteRecoveryPolicy -Name $PolicyName -ReplicationProvider “HyperVReplicaAzure” -ReplicationFrequencyInSeconds $ReplicationFrequencyInSeconds  -RecoveryPoints $Recoverypoints -ApplicationConsistentSnapshotFrequencyInHours 1 -RecoveryAzureStorageAccountId $storageaccountID

Write-Host "New Replication Policy $PolicyName is created!" -ForegroundColor Green

#protectioncontainer
$protectionContainer = Get-AzureRmSiteRecoveryProtectionContainer

#associate
$Policy = Get-AzureRmSiteRecoveryPolicy -FriendlyName $PolicyName
$associationJob  = Start-AzureRmSiteRecoveryPolicyAssociationJob -Policy $Policy -PrimaryProtectionContainer $protectionContainer

Start-Sleep -Seconds 60

#protect

$protectionEntity01 = Get-AzureRmSiteRecoveryProtectionEntity -ProtectionContainer $protectionContainer -FriendlyName $VMFriendlyName01
$protectionEntity02 = Get-AzureRmSiteRecoveryProtectionEntity -ProtectionContainer $protectionContainer -FriendlyName $VMFriendlyName02

$DRjob01 = Set-AzureRmSiteRecoveryProtectionEntity -ProtectionEntity $protectionEntity01 -Policy $Policy -Protection Enable -RecoveryAzureStorageAccountId $storageaccountID  -OS $OStype -OSDiskName $protectionEntity01.Disks[0].Name
$DRjob02 = Set-AzureRmSiteRecoveryProtectionEntity -ProtectionEntity $protectionEntity02 -Policy $Policy -Protection Enable -RecoveryAzureStorageAccountId $storageaccountID  -OS $OStype -OSDiskName $protectionEntity02.Disks[0].Name

Write-Host "ProtectionJobs started..." -ForegroundColor Green

#check replica
do
{
    $DRJob01State = Get-AzureRmSiteRecoveryJob -Job $DRjob01 | Select-Object -ExpandProperty State
}
until ($DRJob01State -eq "Succeeded")

Write-Host "Replication of $VMFriendlyName01 is successful!" -ForegroundColor Green

do
{
    $DRJob02State = Get-AzureRmSiteRecoveryJob -Job $DRjob02 | Select-Object -ExpandProperty State
}
until ($DRJob02State -eq "Succeeded")

Write-Host "Replication of $VMFriendlyName02 is successful!" -ForegroundColor Green

#finish
$endtime = get-date -Format "hh:mm:ss"
Write-Host "Script ended at $endtime" -ForegroundColor Green