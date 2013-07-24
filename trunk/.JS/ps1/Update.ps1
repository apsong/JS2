# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

###################################################################################################
$XLS = (Get-ChildItem I:\【数据管理】\人员信息总表*.xlsx | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xlsx", ".csv")
$SUMMARY = "I:\【数据管理】\人员信息总表_Summary.csv"
$NextPTSL = "I:\【数据管理】\人员信息总表_NextPTSL.csv"
$NextXFSL = "I:\【数据管理】\人员信息总表_NextXFSL.csv"

###################################################################################################
$PTSLs = (Import-Csv I:\【数据管理】\人员信息总表-20130714.csv | ?{$_.沙龙主题 -eq "菩提沙龙" } | %{ Get-Date -UFormat "%Y/%m/%d" $_.参加沙龙时间 } | sort -Unique)
$PTSLs
$Last2PTSL = ($PTSLs | Select-Object -Index ($PTSLs.Count-2))
"`nLast2PTSL:"
$Last2PTSL

Import-Csv $SUMMARY | ?{$_.LastDate -gt $Last2PTSL -and $_.PTSL -eq 0} | sort LastDate | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent `
    | export-csv -noTypeInformation -encoding Unicode $NextPTSL
    
$LastMonth = (Get-Date -UFormat "%Y/%m/%d" ((Get-Date) - (New-TimeSpan -Days 30)))
Import-Csv $SUMMARY | ?{$_.LastDate -gt $LastMonth } | sort LastDate | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent `
    | export-csv -noTypeInformation -encoding Unicode $NextXFSL
        
###################################################################################################
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$workbook = $excel.Workbooks.Open($XLS) 

###################################################################################################
$workbook.Worksheets | ?{$_.Name -like "下次*沙龙(*)"} | %{ $_.Delete()} 

function NewSheet($workbook, $name, $file) {
    $newSheet = $workbook.Worksheets.Add()
    $newSheet.Name = $name
    $newSheet.Move([System.Reflection.Missing]::Value, $workbook.WorkSheets.Item($workbook.WorkSheets.Count))
    $connector = $newSheet.QueryTables.Add("TEXT;" + $file, $newSheet.Range("A1"))
    $newSheet.QueryTables.Item($connector.name).TextFileCommaDelimiter = $true
    $newSheet.QueryTables.Item($connector.name).TextFileParseType = 1
    [void]$newSheet.QueryTables.Item($connector.name).Refresh()
    $newSheet.QueryTables.Item($connector.name).Delete()

    $newSheet.Cells.Item(1, 1) = "姓名"
    $newSheet.Cells.Item(1, 2) = "电话"
    $newSheet.Cells.Item(1, 3) = "报名书院"
    $newSheet.Cells.Item(1, 4) = "Email"
    $newSheet.Cells.Item(1, 5) = "上次沙龙日期"
    $newSheet.Cells.Item(1, 6) = "学佛沙龙次数"
    $newSheet.Cells.Item(1, 7) = "菩提沙龙次数"
    $newSheet.Cells.Item(1, 8) = "已发报名表"

    [void]$newSheet.UsedRange.EntireColumn.AutoFit()
    $newSheet.Range("C:C").HorizontalAlignment = -4108
    $newSheet.Range("F:H").HorizontalAlignment = -4108
    [void]$newSheet.Range("1:1").AutoFilter([System.Reflection.Missing]::Value, [System.Reflection.Missing]::Value)
    $newSheet.Application.ActiveWindow.SplitRow = 1;
    $newSheet.Application.ActiveWindow.FreezePanes = $True;
    
    $a = Release-Ref($newSheet)
}
NewSheet $workbook (Get-Date -UFormat "下次学佛沙龙(>%Y-%m-%d)" $LastMonth) $NextXFSL
NewSheet $workbook (Get-Date -UFormat "下次菩提沙龙(>%Y-%m-%d)" $Last2PTSL) $NextPTSL

###################################################################################################
$workbook.Worksheets.Item(1).Activate()
$workbook.Save()
$excel.Quit()

$a = Release-Ref($workbook)
$a = Release-Ref($excel)