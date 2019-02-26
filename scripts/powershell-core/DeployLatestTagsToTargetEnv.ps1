<###################################################################################>
<#       Script: DeployLatestTagsToTargetEnv                                       #>
<#  Description: Deploy to target environment the latest tags of configured        #>
<#               LifeTime applications.                                            #>
<#         Date: 2017-10-06                                                        #>
<#       Author: rrmendes                                                          #>
<#         Path: jenkins/scripts/powershell/DeployLatestTagsToTargetEnv.ps1        #>
<###################################################################################>

<###################################################################################>
<#     Function: CallDeploymentAPI                                                 #>
<#  Description: Helper function that wraps calls to the LifeTime Deployment API.  #>
<#       Params: -Method: HTTP Method to use for API call                          #>
<#               -Endpoint: Endpoint of the API to invoke                          #>
<#               -Body: Request body to send when calling the API                  #>
<###################################################################################>
function CallDeploymentAPI ($Method, $Endpoint, $Body)
{
        $Url = "https://$env:LifeTimeUrl/LifeTimeAPI/rest/v1/$Endpoint"
        #$Url = "https://catalyst-lt.outsystemsenterprise.com/LifeTimeAPI/rest/v1/$Endpoint"

    $ContentType = "application/json"
        $Headers = @{
		Authorization = "Bearer $env:AuthorizationToken"
		Accept = "application/json"
	}

        try { Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ContentType $ContentType -Body $body }
        catch { Write-Host $_; exit 9 }
}

# Unable to load from csv of another session
# get files from api again
$Environments = CallDeploymentAPI -Method GET -Endpoint environments

# Process output
$envtab = $Environments | Select-Object -Property Name,Key
$csv_env = $envtab


# Fetch latest OS Applications data
# Unable to load CSV file form another session
# get applications from api again
$Applications = CallDeploymentAPI -Method GET -Endpoint applications

# Process output
$appstab = $Applications  | Select-Object -Property Name,Key
$csv_app = $appstab

# Translate environment names to the corresponding keys

#$SourceEnvKey = $csv_env.Where({$_.name -eq "Development"}).key
#$TargetEnvKey = $csv_env.Where({$_.name -eq "Production"}).key
$SourceEnvKey = $csv_env.Where({$_.name -eq "$env:SourceEnvironment"}).key
$TargetEnvKey = $csv_env.Where({$_.name -eq "$env:TargetEnvironment"}).key



# Translate application names to the corresponding keys
$apps = $env:ApplicationsToDeploy -split ","


$AppKeys = ""
foreach($item in $apps){
    $Appkeys = $Appkeys + "," + ($csv_app.Where({$_.Name -eq $item}).Key)
    }
$AppKeys = $AppKeys.substring(1)



echo "Creating deployment plan from '$env:SourceEnvironment' ($SourceEnvKey) to '$env:TargetEnvironment' ($TargetEnvKey) including applications: $env:ApplicationsToDeploy ($AppKeys)."

# Get latest version Tags for each OS Application to deploy
$AppVersionKeys = ( $AppKeys -split "," | %{ CallDeploymentAPI -Method GET -Endpoint "applications/$_/versions?MaximumVersionsToReturn=1" } | %{ '"' + $_.Key + '"' } ) -join ","

# Create a new LifeTime Deployment Plan that includes the retrieved version Tags
$RequestBody = @"
{
        "ApplicationVersionKeys": [$AppVersionKeys],
        "Notes" : "Automatic deployment plan created by Jenkins",
        "SourceEnvironmentKey":"$SourceEnvKey",
        "TargetEnvironmentKey":"$TargetEnvKey"
}
"@

$DeploymentPlanKey = CallDeploymentAPI -Method POST -Endpoint "deployments" -Body $RequestBody
echo "Deployment plan '$DeploymentPlanKey' created successfully."

# commit
# Deployment Details
echo "Deployment detail for plan '$DeploymentPlanKey' "
$DeploymentDetails = CallDeploymentAPI -Method GET -Endpoint "deployments/$DeploymentPlanKey"
echo "###### '$DeploymentDetails' #####"

# Start Deployment Plan execution
$DeploymentPlanStart = CallDeploymentAPI -Method POST -Endpoint "deployments/$DeploymentPlanKey/start"
echo "Deployment plan '$DeploymentPlanKey' started being executed."

# Sleep thread until deployment has finished
$WaitCounter = 0
do {
        Start-Sleep -s $env:SleepPeriodInSecs
        $WaitCounter += $env:SleepPeriodInSecs
        echo "$WaitCounter secs have passed since the deployment started..."

        # Check Deployment Plan status. If deployment is still running then go back to step 5
        $DeploymentStatus =  CallDeploymentAPI -Method GET -Endpoint "deployments/$DeploymentPlanKey/status" | %{ $_.DeploymentStatus }

        if ($DeploymentStatus -ne "running") {
                # Return Deployment Plan status
                echo "Deployment plan finished with status '$DeploymentStatus'."
                exit 0
        }
}
while ($WaitCounter -lt $env:DeploymentTimeoutInSecs)

# Deployment timeout reached. Exit script with error
echo "Timeout occurred while deployment plan is still in 'running' status."
exit 1
