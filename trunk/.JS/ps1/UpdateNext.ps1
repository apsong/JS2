# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

###################################################################################################
$XLS = (Get-ChildItem I:\�����ݹ���\��Ա��Ϣ�ܱ�*.xlsx | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xlsx", ".csv")
$SUMMARY = "I:\�����ݹ���\��Ա��Ϣ�ܱ�_Summary.csv"
$NextPTSL = "I:\�����ݹ���\��Ա��Ϣ�ܱ�_NextPTSL.csv"
$NextXFSL = "I:\�����ݹ���\��Ա��Ϣ�ܱ�_NextXFSL.csv"

###################################################################################################
$LastSL = (Import-Csv $CSV | %{ Get-Date -UFormat "%Y/%m/%d" $_.�μ�ɳ��ʱ�� } | sort -Unique -Descending | Select-Object -First 1)

$LastQuarter = (Get-Date -UFormat "%Y/%m/%d" ((Get-Date $LastSL) - (New-TimeSpan -Days 90)))
Import-Csv $SUMMARY | ?{$_.LastDate -gt $LastQuarter -and $_.PTSL -eq 0} | sort LastDate | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent `
    | export-csv -noTypeInformation -encoding Unicode $NextPTSL
    
$LastMonth = (Get-Date -UFormat "%Y/%m/%d" ((Get-Date $LastSL) - (New-TimeSpan -Days 30)))
Import-Csv $SUMMARY | ?{$_.LastDate -gt $LastMonth } | sort LastDate | select Name,Phone,Applied,Email,LastDate,XFSL,PTSL,Sent `
    | export-csv -noTypeInformation -encoding Unicode $NextXFSL

Import-Csv $SUMMARY | ?{$_.Applied -eq "��" -and $_.Sent -ne "��" -and $_.PTSL -gt 0}

###################################################################################################
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$workbook = $excel.Workbooks.Open($XLS) 

###################################################################################################
$workbook.Worksheets | ?{$_.Name -like "�´�*ɳ��(*)"} | %{ $_.Delete()} 

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
    
    $newSheet.Cells.Item(1, 1) = "����"
    $newSheet.Cells.Item(1, 2) = "�绰"
    $newSheet.Cells.Item(1, 3) = "������Ժ"
    $newSheet.Cells.Item(1, 4) = "Email"
    $newSheet.Cells.Item(1, 5) = "�ϴ�ɳ������"
    $newSheet.Cells.Item(1, 6) = "ѧ��ɳ������"
    $newSheet.Cells.Item(1, 7) = "����ɳ������"
    $newSheet.Cells.Item(1, 8) = "�ѷ�������"

    [void]$newSheet.UsedRange.EntireColumn.AutoFit()
    $newSheet.Range("C:C").HorizontalAlignment = -4108
    $newSheet.Range("F:H").HorizontalAlignment = -4108
    [void]$newSheet.Range("1:1").AutoFilter([System.Reflection.Missing]::Value, [System.Reflection.Missing]::Value)
    $newSheet.Application.ActiveWindow.SplitRow = 1;
    $newSheet.Application.ActiveWindow.FreezePanes = $True;
    
    $a = Release-Ref($newSheet)
}
NewSheet $workbook (Get-Date -UFormat "�´�ѧ��ɳ��(>%Y-%m-%d)" $LastMonth) $NextXFSL
NewSheet $workbook (Get-Date -UFormat "�´�����ɳ��(>%Y-%m-%d)" $LastQuarter) $NextPTSL

###################################################################################################
$workbook.Worksheets.Item(1).Activate()
$workbook.Save()
$excel.Quit()

$a = Release-Ref($workbook)
$a = Release-Ref($excel)