#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location

try
{
    # Fetch the inputs

    $queuedMinutesExceeded = Get-ActionInputInt32 "queued-minutes-exceeded" $false
    $minCreatedAtUtc       = [System.DateTime]::UtcNow - [System.TimeSpan]::FromMinutes($queuedMinutesExceeded)

    # Fetch the GITHUB_PAT and query the GitHub REST API for the RunAsAdministrator
    # information, specifically the [created_at] property.
    #
    # The relevant REST APIs are:
    #
    #   https://docs.github.com/en/rest/reference/actions#get-a-workflow-run
    #   https://docs.github.com/en/rest/reference/actions#cancel-a-workflow-run

    $GITHUB_PAT = Get-SecretPassword "GITHUB_PAT"
    $runUri     = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    $headers    = 
    @{
        "authorization" = "Bearer $GITHUB_PAT"
        "accept"        = "application/vnd.github.v3+json"
    }

    $runJson      = $(Invoke-WebRequest -Method GET -Uri $runUri -UserAgent "neonforge.com/0" -Headers $headers)
    $runDetails   = ConvertFrom-Json $runJson
    $createdAtUtc = $runDetails.created_at

    if ($createdAtUtc -le $minCreatedAtUtc)
    {
        # The run was queued for too long, so cancel it.

        Invoke-WebRequest -Method POST -Uri "$runUri/cancel" -UserAgent "neonforge.com/0" -Headers $headers

        # Sleep long enough for the runner to terminate the workflow.

        Start-Sleep -Seconds 3600
    }
}
catch
{
    Write-ActionException $_
    exit 1
}
