# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$XLS = (Get-ChildItem I:\【数据管理】\人员信息总表*.xls | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xls", ".csv")
$SUMMARY = "I:\【数据管理】\人员信息总表.csv"

if (1) {
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$xlCSV = 6
$workbook = $excel.Workbooks.Open($xls) 
$worksheet = $workbook.Worksheets.Item(1)
$worksheet.SaveAs($csv, $xlCSV)
$excel.Quit()

$a = Release-Ref($worksheet)
$a = Release-Ref($workbook)
$a = Release-Ref($excel)

$temp = (Get-Content $csv)
$temp | Out-File $csv -Encoding Unicode
}


$HASH = @{}
$row = 0
$header = "Name","faming","Sex","Phone","Email","Date","Subject","Address","Action","Applied","Sent","Received","Uploaded"
import-csv $CSV -header $header | select-object -skip 1 | ForEach-Object -process {
    if ($_.Action -eq "参加学佛沙龙") {
        $xfsl = 1; $ptsl = 0;
    } elseif ($_.Action -eq "参加菩提沙龙") {
        $xfsl = 0; $ptsl = 1
    } else {
        $xfsl = 0; $ptsl = 0
    }
    
    $ID=$_.Name + $_.Phone
    $_.Email = $_.Email.ToLower()
    $person = $HASH[$ID]
    if ($person -eq $null) {
        $person = new-object psobject -property @{
            Name = $_.Name
            Phone= $_.Phone
            Email= $_.Email
            XFSL = $xfsl
            PTSL = $ptsl
            LastDate = $_.Date
            Applied = $_.Applied
            Sent = $_.Sent
            Received = $_.Received
        }
        if ($xfsl + $ptsl -eq 0) { $person.LastDate = $null }
        $HASH[$ID] = $person
    } else {
        $person.XFSL += $xfsl
        $person.PTSL += $ptsl
        if ($_.Email -ne $null -and $_.Email -ne "" -and $person.Email -ne $null -and $person.Email -ne "" -and $person.Email.IndexOf($_.Email) -lt 0) {
            $person.Email += "|" + $_.Email
            $ID + ": " + $person.Email
        }
        if ($xfsl + $ptsl -gt 0 -and $person.LastDate -lt $_.Date) { $person.LastDate = $_.Date }
        if ($person.Applied -eq $null -and $_.Applied -ne $null) { $person.Applied = $_.Applied }
        if ($person.Sent -eq $null -and $_.Sent -ne $null) { $person.Sent = $_.Sent }
        if ($person.Received -eq $null -and $_.Received -ne $null) { $person.Received = $_.Received }
    }
    $row++
    #$person
}
"[$row rows are processed]"
$HASH.values | Select-Object Name,Phone,Email,XFSL,PTSL,LastDate,Applied,Sent,Received `
        | export-csv -noTypeInformation -encoding Unicode $SUMMARY