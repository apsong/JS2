# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$XLS = (Get-ChildItem I:\�����ݹ���\test*.xlsx | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xlsx", ".csv")
$SUMMARY = "I:\�����ݹ���\��Ա��Ϣ�ܱ�_Summary.csv"
$NextPTSL = "I:\�����ݹ���\��Ա��Ϣ�ܱ�_NextPTSL.csv"

###################################################################################################
$PTSLs = (Import-Csv I:\�����ݹ���\��Ա��Ϣ�ܱ�-20130714.csv | ?{$_.ɳ������ -eq "����ɳ��" } | %{ Get-Date -UFormat "%Y/%m/%d" $_.�μ�ɳ��ʱ�� } | sort -Unique)
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
$workbook.Worksheets | ?{$_.Name -like "�´�*ɳ��(*)"} | %{ $_.Delete()} 
$ptslSheet= $workbook.Worksheets.Add()
$ptslSheet.Name = (Get-Date -UFormat "�´�����ɳ��(%y%m%d-%H%M%S)")
$ptslSheet.Move([System.Reflection.Missing]::Value, $workbook.WorkSheets.Item($workbook.WorkSheets.Count))
$ptslSheet.QueryTables.Add("TEXT;I:\�����ݹ���\��Ա��Ϣ�ܱ�_Summary.csv", $ptslSheet.Range("`$A`$1"))
$ptslSheet.Cells.Item(1, 1) = "����"
$ptslSheet.Cells.Item(1, 2) = "�绰"
$ptslSheet.Cells.Item(1, 3) = "������Ժ"
$ptslSheet.Cells.Item(1, 4) = "Email"
$ptslSheet.Cells.Item(1, 5) = "�ϴ�ɳ������"
$ptslSheet.Cells.Item(1, 6) = "ѧ��ɳ������"
$ptslSheet.Cells.Item(1, 7) = "����ɳ������"
$ptslSheet.Cells.Item(1, 8) = "�ѷ�������"

#$workbook.Worksheets.Item(1).Activate()
$workbook.Save()
sleep(2)
$excel.Quit()

$a = Release-Ref($ptslSheet)
$a = Release-Ref($workbook)
$a = Release-Ref($excel)