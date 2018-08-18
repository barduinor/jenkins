<###################################################################################>
<#       Script: FetchLifeTimeData                                                 #>
<#  Description: Fetch the latest Application and Environment data in LifeTime     #>
<#               for invoking the Deployment API.                                  #>
<#         Date: 2017-10-05                                                        #>
<#       Author: rrmendes                                                          #>
<#         Path: jenkins/scripts/powershell/FetchLifeTimeData.ps1                  #>
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
        #Authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJsaWZldGltZSIsInN1YiI6IllqUmtZbU00WkRjdE9EWTVaQzAwTWpWaUxUbGhaRGd0WldZM05HVmlOV1ZsWVRRMSIsImF1ZCI6ImxpZmV0aW1lIiwiaWF0IjoiMTUzNDM2NDUzNyIsImppdCI6Ik0xT20xVXBqbloifQ==.ZU0vGrIQtiaMOXYFDSR/+Lp6Fd14aZKFvHW1mLsNEhI="
                Accept = "application/json"
        }

        try { Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ContentType $ContentType -Body $body }
        catch { Write-Host $_; exit 9 }
}

# Fetch latest OS Environments data
$Environments = CallDeploymentAPI -Method GET -Endpoint environments
#echo "Debug: json"
#$Environments

# Process output
$envtab = $Environments | Select-Object -Property Name,Key
#echo "Environment Table"
#echo $envtab

$envtab | export-csv LT.Environments.mapping
#echo "Done Conversion"

echo "Debug - LT.Environments.mapping File content"
cat ./LT.Environments.mapping

"Environments=" + ( ( $Environments | %{ $_.Name } | Sort-Object ) -join "," ) | Out-File LT.Environments.properties -Encoding Default
echo "OS Environments data retrieved successfully."
echo "Debug - LT.Environments.properties File content"
cat ./LT.Environments.properties

echo "------------------"
echo "Done Environments"
echo "------------------"


# Fetch latest OS Applications data
$Applications = CallDeploymentAPI -Method GET -Endpoint applications
#$Applications | Format-Table Name,Key > LT.Applications.mapping

#echo "Debug: json"
#$Applications

# Process output
$appstab = $Applications  | Select-Object -Property Name,Key
#echo "Debug - Applications Table"
#echo $appstab

$appstab | export-csv LT.Applications.mapping
echo "Debug - LT.Applications.mapping File content"
cat ./LT.Applications.mapping

"Applications=" + ( ( $Applications | %{ $_.Name } | Sort-Object ) -join "," ) | Out-File LT.Applications.properties -Encoding Default

echo "Debug - LT.Applications.properties File content"
cat ./LT.Applications.properties

echo "------------------"
echo "Done Applications "
echo "------------------"

echo "OS Applications data retrieved successfully."