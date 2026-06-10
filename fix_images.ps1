$ErrorActionPreference = 'Stop'

$files = Get-ChildItem -Path . -Include *.html, *.css, *.js -Recurse -File | Where-Object { $_.FullName -notmatch '\\(node_modules|vendor|\.git)\\' }

$images = Get-ChildItem -Path img -Recurse -File
$imgMap = @{}
foreach ($img in $images) {
    # Generate relative path with forward slashes
    $relPath = ($img.FullName.Substring((Get-Location).Path.Length + 1)).Replace('\', '/')
    $imgMap[$relPath.ToLower()] = $relPath
}

$fixesCount = 0
$brokenPaths = @()
$correctedPaths = @()

foreach ($file in $files) {
    $content = Get-Content -Raw -Path $file.FullName
    if ($null -eq $content) { continue }
    
    $modified = $false
    
    # Simple regex for matching img paths
    # Matches 'img/' followed by anything that isn't a quote or space until an extension
    $matches = [regex]::Matches($content, 'img/[^"''\s\?#]+?\.(jpg|jpeg|png|gif|webp|svg|JPG|JPEG|PNG|GIF|WEBP|SVG)', 'IgnoreCase')
    
    # Need to be careful to unique them, so we don't replace multiple times incorrectly and mess up counts
    # But Replace() replaces all instances anyway. So let's unique the matches for this file.
    $uniqueRefs = $matches | Select-Object -ExpandProperty Value -Unique
    
    foreach ($refPath in $uniqueRefs) {
        $lowerRef = $refPath.ToLower()
        
        if ($imgMap.ContainsKey($lowerRef)) {
            $correctPath = $imgMap[$lowerRef]
            if ($refPath -cne $correctPath) {
                # Direct string replacement
                # Using Replace with string will replace all occurrences in the file
                $content = $content.Replace($refPath, $correctPath)
                $brokenPaths += $refPath
                $correctedPaths += $correctPath
                $fixesCount++
                $modified = $true
            }
        } else {
            # Write-Host "Warning: image reference not found in files: $refPath"
        }
    }
    
    if ($modified) {
        # Using UTF8 encoding to not mess up HTML files
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
    }
}

Write-Host "--- SUMMARY ---"
Write-Host "Total unique fixes applied across files: $fixesCount"
for ($i=0; $i -lt $brokenPaths.Length; $i++) {
    Write-Host ("Fixed: " + $brokenPaths[$i] + " -> " + $correctedPaths[$i])
}
