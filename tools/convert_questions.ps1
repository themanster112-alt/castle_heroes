param([string]$InputDirectory = 'C:\Users\LENOVO\Downloads')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
function Read-XmlEntry($entry) {
  $reader = [IO.StreamReader]::new($entry.Open())
  try { return [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }
}
$outputDirectory = Join-Path $PSScriptRoot '../data'
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
foreach ($source in @(@{ File = 'الاطفال.xlsx'; Collection = 'children_questions' }, @{ File = 'الكبار.xlsx'; Collection = 'adults_questions' })) {
  $stream = [IO.File]::Open((Join-Path $InputDirectory $source.File), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
  $book = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
  try {
    $strings = @()
    $entry = $book.GetEntry('xl/sharedStrings.xml')
    if ($entry) { $xml = Read-XmlEntry $entry; $strings = @($xml.SelectNodes('//*[local-name()="si"]') | ForEach-Object { $_.InnerText }) }
    $sheet = Read-XmlEntry ($book.GetEntry('xl/worksheets/sheet1.xml'))
    $questions = @()
    $ids = @{}
    $errors = @()
    foreach ($row in $sheet.SelectNodes('//*[local-name()="sheetData"]/*[local-name()="row"]')) {
      $cells = @{}
      foreach ($cell in $row.SelectNodes('./*[local-name()="c"]')) {
        $v = $cell.SelectSingleNode('./*[local-name()="v"]')
        $value = if ($v) { $v.InnerText } else { $cell.InnerText }
        if ($cell.t -eq 's') { $value = $strings[[int]$value] }
        if ($cell.t -ne 's' -and $cell.t -ne 'inlineStr' -and $value -match '^(-?\d+)\.0+$') { $value = $Matches[1] }
        $cells[($cell.r -replace '\d','')] = $value.Trim()
      }
      if ($row.r -eq '1') { Write-Output ($source.Collection + ' headers: ' + (($cells.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Value }) -join ', ')); continue }
      if (-not $cells['B']) { continue }
      $options = @($cells['C'], $cells['D'], $cells['E'])
      # Explicit content corrections requested by the owner. Source workbooks stay intact.
      if ($source.Collection -eq 'children_questions' -and $cells['A'] -eq '89') { $options = @('الطباشير', 'القلم', 'الدهان') }
      if ($source.Collection -eq 'adults_questions' -and $cells['A'] -eq '107') { continue }
      $matching = @(0..2 | Where-Object { $options[$_] -ceq $cells['F'] })
      if ($matching.Count -ne 1 -or @($options | Where-Object { -not $_ }).Count -gt 0) { $errors += "Row $($row.r), ID $($cells['A']): $($cells['B']); options: $($options -join ' / '); answer: $($cells['F'])"; continue }
      $id = $cells['A']
      if (-not $id -or $ids.ContainsKey($id)) { $errors += "Row $($row.r): missing or duplicate ID $id"; continue }
      $ids[$id] = $true
      $level = $null
      if ($cells['H']) {
        $parsedLevel = 0
        if (-not [int]::TryParse($cells['H'], [ref]$parsedLevel) -or $parsedLevel -lt 1) { $errors += "Row $($row.r): invalid level"; continue }
        $level = $parsedLevel
      }
      $flag = if ($cells['G']) { $cells['G'] } else { $null }
      if ($flag -and $flag -notmatch '^https://') { $errors += "Row $($row.r): invalid flag URL"; continue }
      $questions += [ordered]@{ id = $id; question = $cells['B']; options = $options; correctOptionIndex = $matching[0]; flagUrl = $flag; level = $level }
    }
    [IO.File]::WriteAllText((Join-Path $outputDirectory ($source.Collection + '.errors.json')), (ConvertTo-Json -InputObject @($errors)), [Text.UTF8Encoding]::new($false))
    if ($errors.Count) { Write-Output ($source.Collection + ' excluded rows: ' + ($errors -join '; ')) }
    $json = ConvertTo-Json -InputObject $questions -Depth 6
    [IO.File]::WriteAllText((Join-Path $outputDirectory ($source.Collection + '.json')), $json, [Text.UTF8Encoding]::new($false))
    Write-Output ($source.Collection + ': ' + $questions.Count + ' questions validated; flags: ' + @($questions | Where-Object { $_.flagUrl }).Count)
  } finally { $book.Dispose() }
}
