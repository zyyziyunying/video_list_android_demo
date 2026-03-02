param(
  [string]$PackageName = "com.example.video_list_android_demo",
  [int]$IntervalSec = 5,
  [int]$Samples = 120,
  [int]$DurationSec = 0,
  [string]$OutputDir = "meminfo_reports",
  [string]$DeviceSerial = "",
  [double]$PssSlopeThresholdMbPerMin = 1.5,
  [double]$RssSlopeThresholdMbPerMin = 2.0,
  [double]$MinDeltaMbForLeak = 25.0,
  [int]$MinSamplesForLeakCheck = 12,
  [double]$MinDurationMinForLeakCheck = 3.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-KbValue {
  param(
    [string]$Text,
    [string]$Label
  )

  $escaped = [Regex]::Escape($Label)
  $match = [Regex]::Match(
    $Text,
    "${escaped}:\s+(\d+)",
    [Text.RegularExpressions.RegexOptions]::Multiline
  )
  if (-not $match.Success) {
    throw "Could not find '$Label' in meminfo output."
  }
  return [int]$match.Groups[1].Value
}

function To-Mb {
  param([double]$Kb)
  return [Math]::Round($Kb / 1024.0, 1)
}

function Get-LinearSlope {
  param(
    [double[]]$XValues,
    [double[]]$YValues
  )

  $n = $XValues.Count
  if ($n -lt 2) {
    return 0.0
  }

  $sumX = 0.0
  $sumY = 0.0
  $sumXY = 0.0
  $sumXX = 0.0

  for ($i = 0; $i -lt $n; $i++) {
    $xValue = [double]$XValues[$i]
    $yValue = [double]$YValues[$i]
    $sumX += $xValue
    $sumY += $yValue
    $sumXY += ($xValue * $yValue)
    $sumXX += ($xValue * $xValue)
  }

  $denominator = ($n * $sumXX) - ($sumX * $sumX)
  if ([Math]::Abs($denominator) -lt 1e-9) {
    return 0.0
  }

  return (($n * $sumXY) - ($sumX * $sumY)) / $denominator
}

if ($IntervalSec -le 0) {
  throw "IntervalSec must be greater than 0."
}
if ($Samples -lt 0) {
  throw "Samples cannot be negative."
}
if ($DurationSec -lt 0) {
  throw "DurationSec cannot be negative."
}
if ($Samples -eq 0 -and $DurationSec -eq 0) {
  throw "Set Samples > 0, DurationSec > 0, or both."
}
if ($PssSlopeThresholdMbPerMin -lt 0 -or $RssSlopeThresholdMbPerMin -lt 0) {
  throw "Slope thresholds cannot be negative."
}
if ($MinDeltaMbForLeak -lt 0) {
  throw "MinDeltaMbForLeak cannot be negative."
}
if ($MinSamplesForLeakCheck -lt 3) {
  throw "MinSamplesForLeakCheck must be >= 3."
}
if ($MinDurationMinForLeakCheck -le 0) {
  throw "MinDurationMinForLeakCheck must be greater than 0."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseOutput = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
  $OutputDir
}
else {
  Join-Path $scriptRoot $OutputDir
}

$sessionName = "{0}_{1}" -f $PackageName, (Get-Date -Format "yyyyMMdd_HHmmss")
$sessionDir = Join-Path $baseOutput $sessionName
New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null

$csvPath = Join-Path $sessionDir "metrics.csv"
$rawPath = Join-Path $sessionDir "raw_meminfo.log"
$summaryPath = Join-Path $sessionDir "summary.txt"

"index,timestamp,total_pss_kb,total_rss_kb,total_swap_pss_kb,java_heap_kb,native_heap_kb,graphics_kb" |
  Set-Content -Path $csvPath -Encoding utf8

$samplesData = New-Object System.Collections.Generic.List[object]
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$index = 1

Write-Host "Collecting meminfo for package: $PackageName"
Write-Host "Output: $sessionDir"

while ($true) {
  $elapsedSec = $stopwatch.Elapsed.TotalSeconds
  if ($DurationSec -gt 0 -and $elapsedSec -ge $DurationSec) {
    break
  }
  if ($Samples -gt 0 -and $index -gt $Samples) {
    break
  }

  $adbArgs = @()
  if ($DeviceSerial) {
    $adbArgs += @("-s", $DeviceSerial)
  }
  $adbArgs += @("shell", "dumpsys", "meminfo", $PackageName)

  $rawLines = & adb @adbArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "adb failed with exit code $LASTEXITCODE. Output: $($rawLines -join "`n")"
  }

  $rawText = $rawLines -join "`n"
  if ($rawText -match "No process found for:") {
    throw "Target process is not running. Launch the app first, then retry."
  }
  $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

  $sample = [PSCustomObject]@{
    index             = $index
    timestamp         = $timestamp
    total_pss_kb      = (Get-KbValue -Text $rawText -Label "TOTAL PSS")
    total_rss_kb      = (Get-KbValue -Text $rawText -Label "TOTAL RSS")
    total_swap_pss_kb = (Get-KbValue -Text $rawText -Label "TOTAL SWAP PSS")
    java_heap_kb      = (Get-KbValue -Text $rawText -Label "Java Heap")
    native_heap_kb    = (Get-KbValue -Text $rawText -Label "Native Heap")
    graphics_kb       = (Get-KbValue -Text $rawText -Label "Graphics")
  }
  $samplesData.Add($sample)

  "{0},{1},{2},{3},{4},{5},{6},{7}" -f `
    $sample.index, $sample.timestamp, $sample.total_pss_kb, $sample.total_rss_kb, `
    $sample.total_swap_pss_kb, $sample.java_heap_kb, $sample.native_heap_kb, $sample.graphics_kb |
    Add-Content -Path $csvPath -Encoding utf8

  "===== sample $index @ $timestamp =====`n$rawText`n" | Add-Content -Path $rawPath -Encoding utf8

  "{0,3} {1} PSS={2,6}MB RSS={3,6}MB GFX={4,6}MB SWAP={5,5}MB" -f `
    $sample.index, $sample.timestamp, `
    (To-Mb $sample.total_pss_kb), (To-Mb $sample.total_rss_kb), `
    (To-Mb $sample.graphics_kb), (To-Mb $sample.total_swap_pss_kb) | Write-Host

  $index += 1
  Start-Sleep -Seconds $IntervalSec
}

if ($samplesData.Count -eq 0) {
  throw "No samples collected."
}

$elapsed = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
$pss = $samplesData | Measure-Object -Property total_pss_kb -Minimum -Maximum -Average
$rss = $samplesData | Measure-Object -Property total_rss_kb -Minimum -Maximum -Average
$gfx = $samplesData | Measure-Object -Property graphics_kb -Minimum -Maximum -Average
$swap = $samplesData | Measure-Object -Property total_swap_pss_kb -Minimum -Maximum -Average

$first = $samplesData[0]
$last = $samplesData[$samplesData.Count - 1]
$pssDeltaMb = To-Mb ($last.total_pss_kb - $first.total_pss_kb)
$rssDeltaMb = To-Mb ($last.total_rss_kb - $first.total_rss_kb)

$pssSlopeOverall = 0.0
$rssSlopeOverall = 0.0
$pssSlopeTail = 0.0
$rssSlopeTail = 0.0
$leakVerdict = "insufficient_data"
$leakReason = "Need longer sampling window."

$sampleCount = $samplesData.Count
$totalDurationMin = $elapsed / 60.0

if ($sampleCount -ge 2) {
  $timeStepMin = if ($sampleCount -gt 1 -and $elapsed -gt 0) {
    ($elapsed / ($sampleCount - 1)) / 60.0
  }
  else {
    $IntervalSec / 60.0
  }
  if ($timeStepMin -le 0) {
    $timeStepMin = $IntervalSec / 60.0
  }

  $xMinutes = for ($i = 0; $i -lt $sampleCount; $i++) {
    $i * $timeStepMin
  }
  $pssMb = $samplesData | ForEach-Object { [double]$_.total_pss_kb / 1024.0 }
  $rssMb = $samplesData | ForEach-Object { [double]$_.total_rss_kb / 1024.0 }

  $pssSlopeOverall = [Math]::Round((Get-LinearSlope -XValues $xMinutes -YValues $pssMb), 2)
  $rssSlopeOverall = [Math]::Round((Get-LinearSlope -XValues $xMinutes -YValues $rssMb), 2)

  $tailCount = [Math]::Max([int][Math]::Ceiling($sampleCount / 2.0), 6)
  if ($tailCount -gt $sampleCount) {
    $tailCount = $sampleCount
  }

  $tailStart = $sampleCount - $tailCount
  $xTail = for ($i = 0; $i -lt $tailCount; $i++) {
    $i * $timeStepMin
  }
  $pssTailMb = for ($i = $tailStart; $i -lt $sampleCount; $i++) {
    [double]$samplesData[$i].total_pss_kb / 1024.0
  }
  $rssTailMb = for ($i = $tailStart; $i -lt $sampleCount; $i++) {
    [double]$samplesData[$i].total_rss_kb / 1024.0
  }

  $pssSlopeTail = [Math]::Round((Get-LinearSlope -XValues $xTail -YValues $pssTailMb), 2)
  $rssSlopeTail = [Math]::Round((Get-LinearSlope -XValues $xTail -YValues $rssTailMb), 2)

  if ($sampleCount -lt $MinSamplesForLeakCheck -or $totalDurationMin -lt $MinDurationMinForLeakCheck) {
    $leakVerdict = "insufficient_data"
    $leakReason = "Increase samples or duration for reliable trend detection."
  }
  else {
    $pssRising = (
      $pssSlopeOverall -ge $PssSlopeThresholdMbPerMin -and
      $pssSlopeTail -ge ($PssSlopeThresholdMbPerMin * 0.8) -and
      $pssDeltaMb -ge $MinDeltaMbForLeak
    )
    $rssRising = (
      $rssSlopeOverall -ge $RssSlopeThresholdMbPerMin -and
      $rssSlopeTail -ge ($RssSlopeThresholdMbPerMin * 0.8) -and
      $rssDeltaMb -ge $MinDeltaMbForLeak
    )

    if ($pssRising -or $rssRising) {
      $leakVerdict = "suspected_leak"
      $leakReason = "Slope and delta both exceed thresholds."
    }
    else {
      $leakVerdict = "no_clear_leak"
      $leakReason = "No sustained upward trend above configured thresholds."
    }
  }
}

$summary = @(
  "Memory Sampling Summary",
  "package: $PackageName",
  "samples: $($samplesData.Count)",
  "elapsed_sec: $elapsed",
  ("TOTAL PSS (MB): min={0} avg={1} max={2}" -f (To-Mb $pss.Minimum), (To-Mb $pss.Average), (To-Mb $pss.Maximum)),
  ("TOTAL RSS (MB): min={0} avg={1} max={2}" -f (To-Mb $rss.Minimum), (To-Mb $rss.Average), (To-Mb $rss.Maximum)),
  ("Graphics (MB): min={0} avg={1} max={2}" -f (To-Mb $gfx.Minimum), (To-Mb $gfx.Average), (To-Mb $gfx.Maximum)),
  ("TOTAL SWAP PSS (MB): min={0} avg={1} max={2}" -f (To-Mb $swap.Minimum), (To-Mb $swap.Average), (To-Mb $swap.Maximum)),
  ("PSS delta (last-first): {0} MB" -f $pssDeltaMb),
  ("RSS delta (last-first): {0} MB" -f $rssDeltaMb),
  "",
  "Leak Check",
  ("verdict: {0}" -f $leakVerdict),
  ("reason: {0}" -f $leakReason),
  ("config: pss_slope>={0}MB/min rss_slope>={1}MB/min min_delta>={2}MB min_samples>={3} min_duration>={4}min" -f `
    $PssSlopeThresholdMbPerMin, $RssSlopeThresholdMbPerMin, $MinDeltaMbForLeak, $MinSamplesForLeakCheck, $MinDurationMinForLeakCheck),
  ("PSS slope overall: {0} MB/min" -f $pssSlopeOverall),
  ("PSS slope tail: {0} MB/min" -f $pssSlopeTail),
  ("RSS slope overall: {0} MB/min" -f $rssSlopeOverall),
  ("RSS slope tail: {0} MB/min" -f $rssSlopeTail)
)

$summary | Set-Content -Path $summaryPath -Encoding utf8

Write-Host ""
Write-Host "Done."
Write-Host "- metrics: $csvPath"
Write-Host "- raw logs: $rawPath"
Write-Host "- summary: $summaryPath"
Write-Host "- leak verdict: $leakVerdict"
