<#
.SYNOPSIS
CRL publishing automation
Written by Tyler Applebaum.
Version 0.1

.DESCRIPTION
Generates a new CRL, copies it to the correct location for client access.

.INPUTS
System.String

.OUTPUTS
CRL file; e-mail.

.EXAMPLE
.\Generate-NewCRL.ps1
#>

Function script:Get-CAInfo {
$script:CertDir = "C:\Windows\System32\certsrv\CertEnroll"
  $script:CANames = @{
    #Hostname as key, CA name as value
    "IssuingCA1" = "IssuingCA"
    "PolicyCA" = "Policy-CA"
  }
  $script:CRLFolders = @{
    "IssuingCA1" = "C:\PKI"
    "PolicyCA" = "C:\inetpub\wwwroot\PKI"
  }
$script:CAName = $CANames.$env:ComputerName
Write-Verbose "CA name set to $CAName" -Verbose
$script:CRLFolder = $CRLFolders.$env:ComputerName
Write-Verbose "CRL folder set to $CRLFolder" -Verbose
} #End Get-CAInfo

Function script:New-CRL {
  If (Test-Path "$CertDir\$CAName.crl") {
    Write-Verbose "Existing CRL Found" -Verbose
    $script:CRLDate = Get-ChildItem "$CertDir\$CAName.crl" | Select LastWriteTime
    If ($CRLDate.LastWriteTime -lt (Get-Date).AddDays(-14)) {
      $SavedCRLName = $CAName + "_" + $CRLDate.LastWriteTime.ToLongDateString() + ".crl"
      Rename-Item -Path $CertDir\$CAName.crl -NewName $CertDir\$SavedCRLName #Save CRL in case the SHTF
      certutil -CRL #Publish a new CRL if the CRL is more than 14 days old
    }
    Else {
      Write-Verbose "CRL too new; not overwriting" -Verbose
      Write-Verbose "CRL date modified is $CRLDate.LastWriteTime" -Verbose
    }
      If (Test-Path "$CertDir\$CAName.crl") { #Verify new CRL was generated
        Write-Verbose "New CRL Generated" -Verbose
        Copy-Item "$CertDir\$CAName.crl" $CRLFolder
      }
      Else {
        Write-Verbose "New CRL not generated" -Verbose
      }
  }
  Else {
    Write-Verbose "Existing $CertDir or CRL not found" -Verbose
    Write-Verbose "Ensure account running script has access to $CertDir" -Verbose
  }
} #End New-CRL

Function script:Test-NewCRL {
  $script:NewCRLDate = Get-ChildItem "$CRLFolder\$CAName.crl" | Select LastWriteTime
}

Function Send-Report {
  $MailMessage = @{
  To = "PKI Admin <pkiadmin@yourdomain.org>"
  From = "PKI Admin <pkiadmin@yourdomain.org>"
  Subject = "CRL Publishing Script"
  Body = "CRL publish date: $($NewCRLDate.LastWriteTime). Please check $CRLFolder on $env:ComputerName to verify that $CAName.crl exists and is current."
  SMTPserver = "relay.yourdomain.org"
  }
  Send-MailMessage @MailMessage
} #End Send-Report

. Get-CAInfo
. New-CRL
. Test-NewCRL
. Send-Report
