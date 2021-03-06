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
$Summary2 = "I:\【数据管理】\人员信息总表_Summary2.csv"
$NextPTSL = "I:\【数据管理】\人员信息总表_NextPTSL.csv"
$NextXFSL = "I:\【数据管理】\人员信息总表_NextXFSL.csv"

### Load Approved #################################################################################
$HASH = @{}
Get-Item "I:\【数据管理】\报名表.已交修学处\*.csv" | ForEach-Object -process {
    Import-Csv $_ | %{
        if ($_.Phone1 -ne "") { $HASH[$_.Phone1] = $True }
        if ($_.Phone2 -ne "") { $HASH[$_.Phone2] = $True }
    }
}
###################################################################################################
$LastSL = (Import-Csv $CSV | %{ Get-Date -UFormat "%Y/%m/%d" $_.参加沙龙时间 } | sort -Unique -Descending | Select-Object -First 1)

### All Summary ###
Import-Csv $SUMMARY | ?{$_.Phone.Length -eq 11} | sort Phone | %{
        if ($_.Phone -ne $__lastPhone -and $HASH[$_.Phone] -ne $True) { $_ }
        $__lastPhone = $_.Phone
    } | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent | export-csv -noTypeInformation -encoding Unicode $Summary2

### Next XFSL ###
$LastMonth = (Get-Date -UFormat "%Y/%m/%d" ((Get-Date $LastSL) - (New-TimeSpan -Days 30)))
Import-Csv $SUMMARY | ?{$_.LastDate -gt $LastMonth -and $_.Phone.Length -eq 11} | sort Phone | %{
        if ($_.Phone -ne $__lastPhone -and $HASH[$_.Phone] -ne $True) { $_ }
        $__lastPhone = $_.Phone
    } | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent | export-csv -noTypeInformation -encoding Unicode $NextXFSL

### Next PTSL ###
$LastQuarter = (Get-Date -UFormat "%Y/%m/%d" ((Get-Date $LastSL) - (New-TimeSpan -Days 90)))
Import-Csv $SUMMARY | ?{$_.LastDate -gt $LastQuarter -and $_.Phone.Length -eq 11 -and $_.PTSL -eq 0} | sort Phone | %{
        if ($_.Phone -ne $__lastPhone) { $_ }
        $__lastPhone = $_.Phone
    } | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent | export-csv -noTypeInformation -encoding Unicode $NextPTSL

### Unsent? ###    
Import-Csv $SUMMARY | ?{$_.Applied -eq "是" -and $_.Sent -ne "是" -and $_.PTSL -gt 0}

###################################################################################################
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$workbook = $excel.Workbooks.Open($XLS) 

###################################################################################################
$workbook.Worksheets | ?{$_.Name -like "下次*沙龙(*)" -or $_.Name -eq "Summary"} | %{ $_.Delete()} 

function NewSheet($workbook, $name, $file) {
    $newSheet = $workbook.Worksheets.Add()
    $newSheet.Name = $name
    $newSheet.Move([System.Reflection.Missing]::Value, $workbook.WorkSheets.Item($workbook.WorkSheets.Count))
    
    # Data->From Text: $file,   To "$A$1"
    $connector = $newSheet.QueryTables.Add("TEXT;" + $file, $newSheet.Range("A1"))
    $connector.TextFileCommaDelimiter = $true
    $connector.TextFileParseType = 1
    [void]$connector.Refresh()
    $connector.Delete()
    #$newSheet.QueryTables.Item($connector.name).TextFileCommaDelimiter = $true
    #$newSheet.QueryTables.Item($connector.name).TextFileParseType = 1
    #[void]$newSheet.QueryTables.Item($connector.name).Refresh()
    #$newSheet.QueryTables.Item($connector.name).Delete()
    
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
NewSheet $workbook "Summary" $Summary2
NewSheet $workbook (Get-Date -UFormat "下次学佛沙龙(>%Y-%m-%d)" $LastMonth) $NextXFSL
NewSheet $workbook (Get-Date -UFormat "下次菩提沙龙(>%Y-%m-%d)" $LastQuarter) $NextPTSL

###################################################################################################
$workbook.Worksheets.Item(1).Activate()
$workbook.Save()
$excel.Quit()

$a = Release-Ref($workbook)
$a = Release-Ref($excel)