param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$book = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path))
function Read-Entry($entry) {
  $reader = [IO.StreamReader]::new($entry.Open())
  try {
    $xml = [xml]::new()
    $xml.XmlResolver = $null
    $xml.LoadXml($reader.ReadToEnd())
    return $xml
  } finally { $reader.Dispose() }
}
try {
  $strings = @()
  if ($book.GetEntry('xl/sharedStrings.xml')) {
    $strings = @((Read-Entry $book.GetEntry('xl/sharedStrings.xml')).SelectNodes('//*[local-name()="si"]') | ForEach-Object { $_.InnerText })
  }
  $rows = @()
  foreach ($entry in $book.Entries | Where-Object { $_.FullName -match '^xl/worksheets/sheet\d+\.xml$' }) {
    foreach ($row in (Read-Entry $entry).SelectNodes('//*[local-name()="sheetData"]/*[local-name()="row"]')) {
      $cells = [ordered]@{ sheet = $entry.FullName; row = [int]$row.r }
      foreach ($cell in $row.SelectNodes('./*[local-name()="c"]')) {
        # Formula cells are exported as data, never evaluated.
        $v = $cell.SelectSingleNode('./*[local-name()="v"]')
        $value = if ($cell.t -eq 's') { $strings[[int]$v.InnerText] }
          elseif ($cell.t -eq 'inlineStr') { $cell.SelectSingleNode('./*[local-name()="is"]').InnerText }
          elseif ($v) { $v.InnerText } else { '' }
        $cells[($cell.r -replace '\d', '')] = $value.Trim()
      }
      $rows += $cells
    }
  }
  [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), (ConvertTo-Json -InputObject $rows -Depth 8), [Text.UTF8Encoding]::new($false))
  Write-Output "Exported $($rows.Count) workbook rows for review. No question banks changed."
} finally { $book.Dispose() }
