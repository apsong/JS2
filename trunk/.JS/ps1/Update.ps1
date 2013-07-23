# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$XLS = (Get-ChildItem I:\【数据管理】\test*.xlsx | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xlsx", ".csv")
$SUMMARY = "I:\【数据管理】\人员信息总表_Summary.csv"
$NextPTSL = "I:\【数据管理】\人员信息总表_NextPTSL.csv"

###################################################################################################
$PTSLs = (Import-Csv I:\【数据管理】\人员信息总表-20130714.csv | ?{$_.沙龙主题 -eq "菩提沙龙" } | %{ Get-Date -UFormat "%Y/%m/%d" $_.参加沙龙时间 } | sort -Unique)
$PTSLs
$Last2PTSL = ($PTSLs | Select-Object -Index ($PTSLs.Count-2))
"`nLast2PTSL:"
$Last2PTSL

Import-Csv $SUMMARY | ?{$_.LastDate -gt $Last2PTSL -and $_.PTSL -eq 0} | sort LastDate | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent `
    | export-csv -noTypeInformation -encoding Unicode $NextPTSL
    
###################################################################################################
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$xlCSV = 6
$workbook = $excel.Workbooks.Open($XLS) 
$workbook.Worksheets | ?{$_.Name -like "下次*沙龙(*)"} | %{ $_.Delete()} 
$ptslSheet= $workbook.Worksheets.Add()
$ptslSheet.Name = (Get-Date -UFormat "下次菩提沙龙(%y%m%d-%H%M%S)")
$ptslSheet.Move([System.Reflection.Missing]::Value, $workbook.WorkSheets.Item($workbook.WorkSheets.Count))
$ptslSheet.QueryTables.Add("TEXT;I:\【数据管理】\人员信息总表_Summary.csv", $ptslSheet.Range("`$A`$1"))
$ptslSheet.Cells.Item(1, 1) = "姓名"
$ptslSheet.Cells.Item(1, 2) = "电话"
$ptslSheet.Cells.Item(1, 3) = "报名书院"
$ptslSheet.Cells.Item(1, 4) = "Email"
$ptslSheet.Cells.Item(1, 5) = "上次沙龙日期"
$ptslSheet.Cells.Item(1, 6) = "学佛沙龙次数"
$ptslSheet.Cells.Item(1, 7) = "菩提沙龙次数"
$ptslSheet.Cells.Item(1, 8) = "已发报名表"

#$workbook.Worksheets.Item(1).Activate()
$workbook.Save()
sleep(2)
$excel.Quit()

$a = Release-Ref($ptslSheet)
$a = Release-Ref($workbook)
$a = Release-Ref($excel)