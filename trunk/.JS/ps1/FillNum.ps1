# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$HASH = @{}
$csv = "I:\【数据管理】\人员信息总表.csv"
import-csv $csv | ForEach-Object -process {
    $HASH[$_.Name + $_.Phone] = $_
}
"${csv}: " + $HASH.Count
#$HASH.Values | Where-Object { $_.Name -eq "万红卫" }


# Creating excel object
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

Get-ChildItem "I:\【数据管理】\报名表" -Recurse -Include *.xls | ForEach-Object -process {
    $file = $_
    
    $workbook = $excel.Workbooks.Open($file)
    if ($workbook.Worksheets.Count -eq 1) { #Old format
        $NameRow=4;  $NameCol=2; $PhoneCol=8; $FofaRow=12; $FofaCol=2; $ShuyuanRow=13; $ShuyuanCol=3; $XfslRow=14; $XfslCol=4; $PtslRow=14; $PtslCol=8
    } else { #New format
        $NameRow=4;  $NameCol=2; $PhoneCol=8; $FofaRow=13; $FofaCol=2; $ShuyuanRow=14; $ShuyuanCol=2; $XfslRow=15; $XfslCol=4; $PtslRow=15; $PtslCol=8
    }
    
    $worksheet = $workbook.Worksheets.Item(1)
    $XFSL = 0
    $PTSL = 0
    
    $WORD = $worksheet.Cells.Item($FofaRow,$FofaCol).Value();    if ($WORD -eq $null) { $WORD = 0 } else { $WORD = $WORD.Length }
    $WORD2 = $worksheet.Cells.Item($ShuyuanRow,$ShuyuanCol).Value();   if ($WORD2 -eq $null) { $WORD2 = 0 } else { $WORD2 = $WORD2.Length }
    foreach ($PhoneRow in 7..8) {
        $ID = $worksheet.Cells.Item($NameRow,$NameCol).Value() + $worksheet.Cells.Item($PhoneRow,$PhoneCol).Value()
        if ($HASH[$ID] -ne $null) {
            $XFSL = $HASH[$ID].XFSL
            $PTSL = $HASH[$ID].PTSL
            $worksheet.Cells.Item($XfslRow,$XfslCol) = $XFSL
            $worksheet.Cells.Item($PtslRow,$PtslCol) = $PTSL
            break
        }
    }
    $LastDate = $HASH[$ID].LastDate; if ($LastDate -eq $null -or $LastDate -eq "") { $LastDate = 0 }
    
    $now = (Get-Date -UFormat "%Y%m%d")
    $last = (Get-Date -UFormat "%Y%m%d" -Date $LastDate)
    if ($WORD -lt 250 -or $WORD2 -eq 0) {
        $dest = $file.DirectoryName + ".不足字数\[${last}_pt${PTSL}_xf${XFSL}_${WORD}_${WORD2}]" + ($file.name -replace '\[.*\]', "")
    } elseif ($XFSL -eq 0 -or $PTSL -eq 0) {
        $dest = $file.DirectoryName + ".不足沙龙\[${last}_pt${PTSL}_xf${XFSL}_${WORD}_${WORD2}]" + ($file.name -replace '\[.*\]', "")
    } else {
        $dest = $file.DirectoryName + ".合格\[${now}]" + ($file.name -replace '\[.*\]', "")
    }
    $file.name + " -> $dest"
    $worksheet.Cells.Item($ShuyuanRow,$ShuyuanCol).WrapText = $True
    $worksheet.Cells.Item($PtslRow,$PtslCol).HorizontalAlignment = -4108
    
    $workbook.Save()
    $workbook.Close()
    $file.MoveTo($dest)
}
$excel.Quit()

#Release all the objects used above
$a = Release-Ref($workbook)
$a = Release-Ref($excel)