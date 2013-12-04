
###################################################################################################
function iHubDownload ($release_base, $license_base, $DST_DIR) {
    $SRC_DIR = (Get-ChildItem "$release_base\DEV-*" | Sort-Object | Select-Object -last 1).FullName
    $DATE = $SRC_DIR -replace ".*-DEV", ""

    $SRC = (Get-ChildItem $SRC_DIR -Recurse -Filter ActuateBIRTiHub.zip).FullName
    
    $DST_FILE = "ActuateBIRTiHub${DATE}"
    $DST = "${DST_DIR}\${DST_FILE}.zip"
    Get-ChildItem $SRC

    if (Test-Path $DST) {
        "`nNOTE: $DST already exists."
        exit 0
    }
    Copy-Item $SRC $DST
    Get-ChildItem $DST

    unzip -q (cygpath $DST) -d (cygpath $DST_DIR\$DST_FILE)
    ls $DST_DIR\$DST_FILE

    $LIC_ORIG = "$DST_DIR\$DST_FILE\iHub\shared\config\acserverlicense.xml"
    if (-not (Test-Path "$LIC_ORIG.orig")) {
        mv $LIC_ORIG "$LIC_ORIG.orig"
        cp "$license_base\acserverlicense-autotest.xml" $LIC_ORIG
    }
    ls "$LIC_ORIG*" | Select-String "UsageType|ExpirationDate" | %{ $_.Path + ":" + $_.LineNumber + "`t" + $_.Line}
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