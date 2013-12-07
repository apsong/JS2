
###################################################################################################
function iHubDownload ($release_base, $license_base, $DST_DIR) {
    cd $DST_DIR
    
    # 1. Check new build
    $SRC_DIR = (Get-ChildItem "$release_base\DEV-*" | Sort-Object | Select-Object -last 1).FullName
    $SRC = (Get-ChildItem $SRC_DIR -Recurse -Filter ActuateBIRTiHub.zip).FullName
    Get-ChildItem $SRC

    $DATE = $SRC_DIR -replace ".*-DEV", ""
    $DST_FILE = "ActuateBIRTiHub${DATE}"
    
    # 2. Copy new build to local side
    if (Test-Path "$DST_FILE.zip") {
        "`nNOTE: $DST_FILE.zip already exists~~~~~~~~~~~~~~~~~~~~"
    } else {
        Copy-Item $SRC $DST_FILE.zip
    }
    Get-ChildItem $DST_FILE.zip
    
    # 3. Unzip local build
    if (Test-Path $DST_FILE) {
        "`nNOTE: $DST_FILE already exists~~~~~~~~~~~~~~~~~~~~"
    } else {
        #unzip -q (cygpath $DST_DIR\$DST_FILE.zip) -d (cygpath $DST_DIR\$DST_FILE)
        & "7z" x "$DST_FILE.zip" -y -o*
    }
    ls $DST_FILE

    # 4. Update license
    $LIC = "$DST_FILE\iHub\shared\config\acserverlicense.xml"
    if (Test-Path "$LIC.orig") {
        "`nNOTE: $LIC.orig already exists~~~~~~~~~~~~~~~~~~~~"
    } else {
        mv $LIC "$LIC.orig"
        cp "$license_base\acserverlicense-autotest.xml" $LIC
    }
    ls "$LIC*" | Select-String "UsageType|ExpirationDate" | %{ $_.Path + ":" + $_.LineNumber + "`t" + $_.Line}
}

$HOSTNAME = (hostname)
if ($HOSTNAME -eq "birt01-win") {
    iHubDownload "\\fs1-lnx\build2\DailyBuild\Install\Development" `
                 "\\fs1-lnx\build2\DailyBuild\LicenseFile\Development" `
                 "F:\sjin\_AugustaR1_"
} else {
    iHubDownload "\\qaant\ActuateBuild\AugustaR1\iHub3\windows" `
                 "\\qaant\ActuateBuild\LicenseFile\Development" `
                 "P:\_AugustaR1_"
}