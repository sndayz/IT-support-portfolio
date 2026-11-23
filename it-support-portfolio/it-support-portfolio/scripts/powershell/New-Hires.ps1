<#
.SYNOPSIS
    Creates Active Directory user accounts for new hires from an HR CSV export.

.DESCRIPTION
    Reads new hire details from a CSV file, maps the CSV columns to Active
    Directory attributes and creates each account with New-ADUser. Each user is
    placed in the sub-OU under OU=Staff that matches their Department, enabled,
    and set to change the temporary password at next logon. If one row fails,
    a warning names the user and the script carries on with the next row.

    Expected CSV columns: First Name, Last Name, Job Title, Department.
    The Department value must match an existing sub-OU under OU=Staff.
    Logon name format: firstname.department (e.g. sarah.finance).
    The Company attribute is hard-coded to 'Lab Enterprises'.

.PARAMETER CsvPath
    Path to the CSV export from HR.

.PARAMETER Password
    Temporary password as a SecureString, applied to every account created in
    the run. Prompted for if not supplied. Must meet the domain password policy.

.EXAMPLE
    .\New-Hires.ps1 -CsvPath .\NewHires.csv

.NOTES
    Requires the ActiveDirectory module and rights to create users in the Staff OUs.
    SamAccountName is limited to 20 characters, so long first names or department
    names will fail (the failure is reported and the script continues).
    Tested on: Windows Server 2022, PowerShell 7.
    No credentials are stored in this script.
#>

#Requires -Modules ActiveDirectory

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [securestring]$Password = (Read-Host 'Temporary password' -AsSecureString)
)

# Import-Csv returns one object per row; each column header becomes a property
$users = Import-Csv -Path $CsvPath

# Query AD once, outside the loop
$domain    = Get-ADDomain
$upnSuffix = $domain.DNSRoot    # e.g. lab.local

foreach ($u in $users) {

    # Logon name, e.g. akim.finance
    $sam = "$($u.'First Name').$($u.Department)".ToLower()

    # The CSV headers from HR don't match New-ADUser's parameter names, so this
    # hashtable maps each CSV column to the matching AD attribute.
    # It is passed to New-ADUser with @params (splatting).
    $params = @{
        Name                  = "$($u.'First Name') $($u.'Last Name')"
        DisplayName           = "$($u.'First Name') $($u.'Last Name')"   # shown on the sign-in screen
        GivenName             = $u.'First Name'
        Surname               = $u.'Last Name'
        Title                 = $u.'Job Title'
        Department            = $u.Department
        Company               = 'Lab Enterprises'
        SamAccountName        = $sam                 # pre-Windows 2000 logon name, e.g. LAB\akim.finance
        UserPrincipalName     = "$sam@$upnSuffix"    # modern logon name (user@domain); here it mirrors the logon name
        AccountPassword       = $Password
        ChangePasswordAtLogon = $true
        Enabled               = $true
        Path                  = "OU=$($u.Department),OU=Staff,$($domain.DistinguishedName)"   # e.g. OU=Finance,OU=Staff,DC=lab,DC=local
    }

    # -ErrorAction Stop turns a non-terminating error into a terminating one,
    # so the catch block runs. catch prints a warning with the reason, then the
    # loop moves on to the next user.
    try {
        New-ADUser @params -ErrorAction Stop
        Write-Host "Processed: $sam"
    }
    catch {
        Write-Warning "FAILED: $sam - $($_.Exception.Message)"
    }
}
