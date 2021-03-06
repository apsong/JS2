# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$csv = "I:\【数据管理】\人员信息总表_Summary.csv"
$SUMMARY = (import-csv $csv)
"${csv}: " + $SUMMARY.Count
#$HASH.Values | Where-Object { $_.Name -eq "万红卫" }


# Creating excel object
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$now = (Get-Date -UFormat "%Y%m%d")
$nowtime = (Get-Date -UFormat "%Y%m%d-%H%M%S")
    
Get-ChildItem "I:\【数据管理】\报名表\*" -Include *.xls, *.xlsx | ForEach-Object -process {
    $file = $_
    $file.FullName
    $workbook = $excel.Workbooks.Open($file)
    $NameRow=4;  $NameCol=2; $PhoneRow1=7; $PhoneRow2=8; $PhoneCol=8; $EmailRow=6; 
    if ($workbook.Worksheets.Count -eq 1) { #Old format
        $EmailCol=7; $FofaRow=12; $FofaCol=2; $ShuyuanRow=13; $ShuyuanCol=3; $XfslRow=14; $XfslCol=4; $PtslRow=14; $PtslCol=8
    } else { #New format
        $EmailCol=5; $FofaRow=13; $FofaCol=2; $ShuyuanRow=14; $ShuyuanCol=2; $XfslRow=15; $XfslCol=4; $PtslRow=15; $PtslCol=8
    }
    
    $worksheet = $workbook.Worksheets.Item(1)
    
    $Name = ($worksheet.Cells.Item($NameRow,$NameCol).Value() -replace " ", "")
    $Phone1 = $worksheet.Cells.Item($PhoneRow1,$PhoneCol).Value()
    $Phone2 = $worksheet.Cells.Item($PhoneRow2,$PhoneCol).Value()
    $Email = $worksheet.Cells.Item($EmailRow,$EmailCol).Value(); if ($Email.Length -lt 5) { $Email = "INVALID_EMAIL" }
    $WORD = $worksheet.Cells.Item($FofaRow,$FofaCol).Value();    if ($WORD -eq $null) { $WORD = 0 } else { $WORD = $WORD.Length }
    $WORD2 = $worksheet.Cells.Item($ShuyuanRow,$ShuyuanCol).Value();   if ($WORD2 -eq $null) { $WORD2 = 0 } else { $WORD2 = $WORD2.Length }

    $match = @($SUMMARY | Where-Object { $_.Name -eq $Name -and ($_.Phone -eq $Phone1 -or $_.Phone -eq $Phone2 -or $_.Email -like "*${Email}*") })
    $XFSL,$PTSL = ($match | Measure-Object -Sum XFSL,PTSL | %{$_.Sum})
    if ($XFSL -eq $null -or $PTSL -eq $null) {
        $XFSL = 0
        $PTSL = 0
    }
    if ($XFSL -lt 2 -or $PTSL -lt 1) {    
        $similar = @($SUMMARY | Where-Object { $_.Name -eq $Name -or $_.Phone -eq $Phone1 -or $_.Phone -eq $Phone2 -or $_.Email -like "*${Email}*" })
        if ($match.Count -gt 0) {
            "( $Name && ( $Phone1 || $Phone2 || $Email ) ).Count : " + $match.Count
            $match
        }
        if ($similar.Count -gt $match.Count) {
            "( $Name || $Phone1 || $Phone2 || $Email ).Count : " + $similar.Count
            $similar | Where-Object { $match -notcontains $_ }
        }
    }
    
    $worksheet.Cells.Item($XfslRow,$XfslCol) = $XFSL
    $worksheet.Cells.Item($PtslRow,$PtslCol) = $PTSL
    $FirstDate = ($match | Sort-Object -Property FirstDate | Select-Object -First 1).FirstDate; if ($FirstDate -eq $null -or $FirstDate -eq "") { $FirstDate = 0 }
    $LastDate = ($match | Sort-Object -Property LastDate | Select-Object -Last 1).LastDate; if ($LastDate -eq $null -or $LastDate -eq "") { $LastDate = 0 }
    $worksheet.Cells.Item($ShuyuanRow,$ShuyuanCol).WrapText = $True
    $worksheet.Cells.Item($PtslRow,$PtslCol).HorizontalAlignment = -4108

    $first = (Get-Date -UFormat "%Y%m%d" -Date $FirstDate)
    $last = (Get-Date -UFormat "%Y%m%d" -Date $LastDate)
    $newName = $Name + $file.Extension; if ($file.Name -like "*(松江)*") { $newName = "(松江)$newName" }
    if ($WORD -lt 250 -or $WORD2 -eq 0) {
        $dest = $file.DirectoryName + "\不足字数[${first}_${last}_pt${PTSL}_xf${XFSL}_${WORD}_${WORD2}][${nowtime}]$newName"
    } elseif ($XFSL -lt 2 -or $PTSL -lt 1) {
        $dest = $file.DirectoryName + "\不足沙龙[${first}_${last}_pt${PTSL}_xf${XFSL}_${WORD}_${WORD2}][${nowtime}]$newName"
    } else {
        $dest = $file.DirectoryName + ".合格\[${nowtime}]$newName"
    }
    "`t`t`t`t`t`t`t`t-> $dest"
    
    $workbook.Save()
    $workbook.Close()
    $file.MoveTo($dest)
}
$excel.Quit()
$a = Release-Ref($excel)


if (1) {
    Get-ChildItem I:\【数据管理】\报名表.合格\*.zip | rm
    $files = (Get-ChildItem I:\【数据管理】\报名表.合格\*.xls*)
    if ($files.Count -gt 0) {
        $zip = "I:\【数据管理】\报名表.合格\[${now}]_菩提书院初级修学报名表" + $files.Count + "份.zip"
        d:\bin\7z a $zip $files
    }
}