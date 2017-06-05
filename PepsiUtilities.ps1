function Get-AbsolutePath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]
    $Path
  )
  process {
    $Path | ForEach-Object {
      $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
    }
  }
}



function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}



function List-Files {
#  Get-ChildItem -Recurse -force | ? {$_.Fullname -NotMatch "\\\.git"} | 
#     select $(Resolve-path FullName -Relative), Length, LastWriteTime

  (Get-ChildItem -Recurse -force | ? {$_ -NotMatch "^\.git"} | resolve-path -Relative) |
      Out-File filelist.lst -Encoding ASCII
}



# Replace background image of WinPE - dealing with ownership & access rights
$replaceWinPEwallpaper = {

    echo "winPepsi = ${winPepsi}"

    $_wallpaper = "${winPepsi}\Windows\System32\winpe.jpg"
    $_Account = New-Object -TypeName System.Security.Principal.NTAccount `
                -ArgumentList 'BUILTIN\Administrators';
    $_bgImage = Get-Item $_wallpaper
    $_Acl = Get-Acl -Path $_bgImage.FullName
    $_Acl.SetOwner($_Account)

    $_colRights =       [System.Security.AccessControl.FileSystemRights]"Read, Write, Delete"
    $_InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None 
    $_PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    $_objType =         [System.Security.AccessControl.AccessControlType]::Allow 
    $_objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
               ($_Account, $_colRights, $_InheritanceFlag, $_PropagationFlag, $_objType) 
    $_Acl.AddAccessRule($_objACE) 

    Set-Acl -Path $_bgImage.FullName -AclObject $_Acl
    Copy-Item "${PSScriptRoot}\winpe.jpg" $_wallpaper -Force

}