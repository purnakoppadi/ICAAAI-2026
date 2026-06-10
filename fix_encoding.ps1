$ErrorActionPreference = 'Stop'

$files = Get-ChildItem -Path . -Include *.html, *.css, *.js, *.txt, *.json -Recurse -File | Where-Object { $_.FullName -notmatch '\\(node_modules|vendor|\.git)\\' }

$replacements = [ordered]@{
    "â€”" = "—"
    "â€“" = "–"
    "â€œ" = "“"
    "â€" = "”"
    "â€" = "”"
    "â€˜" = "‘"
    "â€™" = "’"
    "â†’" = "→"
    "âœ…" = "✅"
    "âœ–" = "✖"
    "Â°" = "°"
    "Â©" = "©"
}

# For NBSP it might be "Â" + [char]160, let's also just replace literal "Â "
$nbsp_corruption = "Â" + [char]160

$fixesCount = 0
$details = @()

foreach ($file in $files) {
    # Read raw bytes to avoid Powershell mangling, then decode as UTF8
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    
    if ([string]::IsNullOrEmpty($content)) { continue }
    
    $modified = $false
    
    foreach ($key in $replacements.Keys) {
        if ($content.Contains($key)) {
            # count occurrences
            $count = ([regex]::Matches($content, [regex]::Escape($key))).Count
            $fixesCount += $count
            
            $content = $content.Replace($key, $replacements[$key])
            $details += [PSCustomObject]@{ File = $file.Name; Corrupted = $key; Corrected = $replacements[$key]; Count = $count }
            $modified = $true
        }
    }
    
    if ($content.Contains($nbsp_corruption)) {
        $count = ([regex]::Matches($content, [regex]::Escape($nbsp_corruption))).Count
        $fixesCount += $count
        $content = $content.Replace($nbsp_corruption, " ")
        $details += [PSCustomObject]@{ File = $file.Name; Corrupted = "Â+NBSP"; Corrected = "Space"; Count = $count }
        $modified = $true
    }
    
    if ($modified) {
        # Save as UTF-8 without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
    }
}

Write-Host "--- SUMMARY ---"
Write-Host "Total fixes applied: $fixesCount"
$details | Group-Object -Property File, Corrupted, Corrected | Select-Object Name, @{Name='Total';Expression={($_.Group | Measure-Object Count -Sum).Sum}} | Format-Table -AutoSize
