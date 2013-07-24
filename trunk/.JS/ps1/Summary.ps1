# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$XLS = (Get-ChildItem I:\【数据管理】\人员信息总表*.xlsx | Sort-Object | Select-Object -last 1).FullName
$CSV = $XLS.Replace(".xlsx", ".csv")
$SUMMARY = "I:\【数据管理】\人员信息总表_Summary.csv"

if (1) {
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$xlCSV = 6
$workbook = $excel.Workbooks.Open($xls) 
$worksheet = $workbook.Worksheets.Item(1)
$worksheet.Hyperlinks.Delete()
$workbook.Save()
$worksheet.SaveAs($csv, $xlCSV)
$excel.Quit()

$a = Release-Ref($worksheet)
$a = Release-Ref($workbook)
$a = Release-Ref($excel)

# Switch to Unicode
$temp = (Get-Content $csv)
$temp | Out-File $csv -Encoding Unicode
}


$HASH = @{}
$row = 0
$header = "Name","Phone","Email","Date","Address","Subject","Action","Applied","Sent","Received","Uploaded"
import-csv $CSV -header $header | select-object -skip 1 | ForEach-Object -process {
    $_.Date = (Get-Date -UFormat "%Y/%m/%d" $_.Date)
    $_.Name = $_.Name.Replace(" ", "")
    
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
            FirstDate = $_.Date
            LastDate = $_.Date
            Applied = $_.Applied
            Sent = $_.Sent
            Received = $_.Received
        }
        if ($xfsl + $ptsl -eq 0) { $person.FirstDate = $null; $person.LastDate = $null }
        $HASH[$ID] = $person
    } else {
        #if ($person.Name -eq "忻汉能") { $_; $person; }
        
        $person.XFSL += $xfsl
        $person.PTSL += $ptsl
        if ($_.Email -ne $null -and $_.Email -ne "") {
            if ($person.Email -ne $null -and $person.Email -ne "" -and $person.Email.IndexOf($_.Email) -lt 0) {
                $person.Email += "|" + $_.Email
                $ID + ": " + $person.Email
            } else {
                $person.Email = $_.Email
            }
        }
        if ($xfsl + $ptsl -gt 0 -and ($person.FirstDate -gt $_.Date -or $person.FirstDate -eq $null)) { $person.FirstDate = $_.Date }
        if ($xfsl + $ptsl -gt 0 -and $person.LastDate -lt $_.Date) { $person.LastDate = $_.Date }
        if ($_.Applied -eq "是") { $person.Applied = "是" }
        if ($_.Sent -eq "是") { $person.Sent = "是" }
        if ($_.Received -eq "是") { $person.Received = "是" }
        
        #if ($person.Name -eq "忻汉能") { $_; $person }
    }
    $row++
}
"[$row rows are processed, " + $HASH.Count + " rows are generated.]"
$HASH.values | ?{ $_.LastDate -ne $null} | Select-Object Name,Phone,Applied,Email,FirstDate,LastDate,XFSL,PTSL,Sent,Received `
        | export-csv -noTypeInformation -encoding Unicode $SUMMARY