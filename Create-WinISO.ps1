function Create-WinISO {
  [CmdletBinding(
    DefaultParameterSetName="ISO",
    SupportsShouldProcess=$True,
    ConfirmImpact="Medium"
  )]
  Param(
    [parameter(Mandatory=$True,
               ValueFromPipeline=$False, 
               Position=0,
               HelpMessage='Path to mounted ISO image')]
    [Alias("MountDir")]
    [string[]]
    $ISOmountPath=".\",

    [parameter(Mandatory=$True,
               ValueFromPipeline=$False, 
               Position=1,
               HelpMessage='Path to result ISO file')]
    [AllowEmptyString()]
    [alias("ISO")]
    [string[]]
    $ISOname
  )

  BEGIN {
    # Create my environment for WADK utilities
    $WADK = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit"
    $env:WADK = $WADK
    $winPE = "${WADK}\Windows Preinstallation Environment"

    # Create "official" environment for running WADK utilities
    $env:WinPERoot = $winPE
    $env:OSCDImgRoot = "${WADK}\Deployment Tools\AMD64\Oscdimg"
    $oscdimg = join-path $env:OSCDImgRoot "\oscdimg.exe"
  }

  PROCESS {
    WRITE-DEBUG "`$ISOmountPath: $ISOmountPath"
    WRITE-DEBUG "`$ISOname: $ISOname"


    $ISOBootSector = join-path $ISOmountPath  "boot\etfsboot.com"
    $ISOefiLoader = join-path $ISOmountPath "efi\Microsoft\boot\efisys.bin"
    WRITE-DEBUG "`$ISOBootSector: $ISOBootSector"
    WRITE-DEBUG "`$ISOefiLoader: $ISOefiLoader"

    $oscdimgParams = '-m', '-o', '-u2', '-udfver102', ('-bootdata:2#p0,e,b' + $ISOBootSector + '#pEF,e,b' + $ISOefiLoader), $ISOmountPath, $ISOname
    WRITE-DEBUG "Command line: oscdimg $($oscdimgParams -join ' ') "

    if ($PSCmdlet.ShouldProcess("Writing ISO image from directory $ISOmountPath to $ISOname")) {
      & $oscdimg $oscdimgParams
    }

  }

  END {}

}