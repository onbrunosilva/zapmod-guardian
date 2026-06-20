if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -Command ""irm https://raw.githubusercontent.com/onbrunosilva/zapmod-guardian/main/activator.ps1 | iex"""
    exit
}
irm https://raw.githubusercontent.com/onbrunosilva/zapmod-guardian/main/activator.ps1 | iex
