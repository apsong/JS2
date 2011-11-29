
###################################################################################################
function iHubDownload ($release_base, $license_base, $DST_DIR) {
    $SRC_DIR = (Get-ChildItem "$release_base\DEV-*" | Sort-Object | Select-Object -last 1).FullName
    $DATE = $SRC_DIR -replace ".*-DEV", ""

    #$CSV = $XLS.Replace(".xlsx", ".csv")
    $SRC = "${SRC_DIR}\iHub3\modules\ActuateBIRTiHub.zip"

    $DST_NAME = "ActuateBIRTiHub${DATE}"
    $DST = "${DST_DIR}\${DST_NAME}.zip"
    Get-ChildItem $SRC

    if (Test-Path $DST) {
        "`nINFO: $DST already exists."
        exit 0
    }
    Copy-Item $SRC $DST
    Get-ChildItem $DST

    unzip -q $DST -d $DST_DIR\$DST_NAME
    ls $DST_DIR\$DST_NAME

    $LIC_ORIG = "$DST_DIR\$DST_NAME\iHub\shared\config\acserverlicense.xml"
    if (-not (Test-Path "$LIC_ORIG.orig")) {
        mv $LIC_ORIG "$LIC_ORIG.orig"
        cp "$license_base\acserverlicense-autotest.xml" $LIC_ORIG
    }
    ls "$LIC_ORIG*"
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