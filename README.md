### Essentials Online Installer

powershell.exe -ExecutionPolicy Bypass -Verb RunAs

cd "C:\"

iwr -useb "https://raw.githubusercontent.com/Delorean12DMC/toolset/refs/heads/main/essentials.ps1" | iex
