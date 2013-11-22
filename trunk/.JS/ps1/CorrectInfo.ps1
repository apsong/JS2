# This is a common function i am using which will release excel objects
function Release-Ref ($ref) {
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Creating excel object
$excel = new-object -comobject excel.application 
$excel.Visible = $True 
$excel.DisplayAlerts = $False

$now = (Get-Date -UFormat "%Y%m%d")
    
Get-ChildItem "I:\【数据管理】\报名表.已交修学处\*" | ForEach-Object -process {
    $file = $_
    if ($file.Mode -notlike "d*" -or $file.Name -notmatch "^[0-9]+$") { "return -> " + $file; return }
    
    $file.FullName
    if (Test-Path ($file.FullName + ".csv")) { return }
            
    $ARRAY = @()
    Get-ChildItem $file.FullName -Recurse -Include "*.xls", "*.xlsx" | ForEach-Object -Process {
        $workbook = $excel.Workbooks.Open($_)
        
        $NameRow=4;  $NameCol=2; $PhoneRow1=7; $PhoneRow2=8; $PhoneCol=8; $EmailRow=6; 
        if ($workbook.Worksheets.Count -eq 1) { #Old format
            $EmailCol=7
        } else { #New format
            $EmailCol=5
        }
        
        $worksheet = $workbook.Worksheets.Item(1)
        
        $Name = $worksheet.Cells.Item($NameRow,$NameCol).Value()
        $Phone1 = $worksheet.Cells.Item($PhoneRow1,$PhoneCol).Value() -replace "[^0-9]", ""
        $Phone2 = $worksheet.Cells.Item($PhoneRow2,$PhoneCol).Value() -replace "[^0-9]", ""
        $Email = $worksheet.Cells.Item($EmailRow,$EmailCol).Value(); if ($Email.Length -lt 5) { $Email = "INVALID_EMAIL" }
        $person = new-object psobject -property @{
            Name = $Name
            Phone1= $Phone1
            Phone2= $Phone2
            Email= $Email
            Approved = $True
        }
        $ARRAY += $person
        
        $workbook.Close()
    }
    $ARRAY | export-csv -noTypeInformation -encoding Unicode ($file.FullName + ".csv")
    "`t`t`t`t`t`t`t`t-> " + $file.FullName + ".csv"
}
$excel.Quit()
$a = Release-Ref($excel)

