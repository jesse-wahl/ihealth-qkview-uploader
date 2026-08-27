# F5 iHealth QKView Uploader Local Server (PowerShell HttpListener)

param(
    [int]$Port = 8921
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path $scriptDir "public"
$settingsFile = Join-Path $scriptDir "settings.json"

# Kill any previous process listening on $Port
try {
    $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        if ($conn.OwningProcess -and $conn.OwningProcess -ne $PID) {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    }
} catch {}

# Load or Initialize Settings
function Get-AppSettings {
    if (Test-Path $settingsFile) {
        try {
            return Get-Content $settingsFile -Raw | ConvertFrom-Json
        } catch {
            Write-Host "[WARN] Failed to parse settings.json, using defaults." -ForegroundColor Yellow
        }
    }
    return [PSCustomObject]@{
        rawCurlCommand = ""
        clientAccessKey = ""
        clientId = ""
        clientSecret = ""
        tokenEndpoint = "https://identity.account.f5.com/oauth2/v1/token"
        uploadEndpoint = "https://ihealth2-api.f5.com/qkview-analyzer/api/qkviews"
        baseDirectory = "Z:\"
        fallbackUncDirectory = "\\network-share\shares\cases"
        incomingSubdir = "INCOMING"
        visibleInGui = "True"
        userAgent = "F5-iHealth-Uploader/1.0"
    }
}

function Save-AppSettings($settingsObj) {
    $json = $settingsObj | ConvertTo-Json -Depth 5 -Compress
    Set-Content -Path $settingsFile -Value $json -Encoding UTF8
}

# Helper to send clean JSON response
function Send-JsonResponse($response, $data, [int]$statusCode = 200) {
    $json = ConvertTo-Json -InputObject $data -Compress -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.StatusCode = $statusCode
    $response.ContentType = "application/json; charset=utf-8"
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
}

# Generate F5 Bearer Token via OAuth Endpoint
function Get-F5BearerToken($settings) {
    $accessKey = $settings.clientAccessKey
    if ([string]::IsNullOrWhiteSpace($accessKey) -and $settings.clientId -and $settings.clientSecret) {
        $rawKey = "$($settings.clientId):$($settings.clientSecret)"
        $accessKey = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rawKey))
    }

    if ([string]::IsNullOrWhiteSpace($accessKey)) {
        return @{ success = $false; error = "Client Access Key is not configured. Please open Settings." }
    }

    $tokenUrl = $settings.tokenEndpoint
    $curlArgs = @(
        "-s", "-X", "POST",
        "-H", "Accept: application/json",
        "-H", "Authorization: Basic $accessKey",
        "-H", "Content-Type: application/x-www-form-urlencoded",
        "-d", "grant_type=client_credentials&scope=ihealth",
        "$tokenUrl"
    )

    try {
        $resultStr = & "C:\Windows\System32\curl.exe" $curlArgs 2>&1 | Out-String
        if ($resultStr -match "access_token") {
            $jsonRes = $resultStr | ConvertFrom-Json
            return @{
                success = $true
                bearerToken = [string]$jsonRes.access_token
                expiresIn = [string]$jsonRes.expires_in
            }
        } else {
            return @{ success = $false; error = "Failed to obtain Bearer Token: $resultStr" }
        }
    } catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# Format file size for UI
function Format-FileSize([long]$bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N0} KB" -f ($bytes / 1KB) }
    return "$bytes Bytes"
}

# Start HttpListener with automatic retry
$listener = New-Object System.Net.HttpListener
$url = "http://localhost:$Port/"
$listener.Prefixes.Add($url)

for ($tryNum = 1; $tryNum -le 5; $tryNum++) {
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        foreach ($conn in $connections) {
            if ($conn.OwningProcess -and $conn.OwningProcess -ne $PID) {
                Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Milliseconds 500

        $listener.Start()
        break
    } catch {
        if ($tryNum -eq 5) { throw $_ }
        Start-Sleep -Seconds 1
    }
}

try {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  F5 iHealth QKView Uploader Local Server Started!" -ForegroundColor Cyan
    Write-Host "  URL: $url" -ForegroundColor Yellow
    Write-Host "  Press Ctrl+C in terminal to stop server." -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Green

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        # Enable CORS
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        if ($method -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        # Helper to read JSON request body
        $bodyText = ""
        if ($request.HasEntityBody) {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $bodyText = $reader.ReadToEnd()
            $reader.Close()
        }

        # Route Handling
        try {
            if ($path -eq "/api/settings" -and $method -eq "GET") {
                $settings = Get-AppSettings
                Send-JsonResponse $response $settings
            }
            elseif ($path -eq "/api/settings" -and $method -eq "POST") {
                $newSettings = $bodyText | ConvertFrom-Json
                Save-AppSettings $newSettings
                Send-JsonResponse $response @{ success = $true }
            }
            elseif ($path -eq "/api/test-token" -and $method -eq "POST") {
                $reqData = $bodyText | ConvertFrom-Json
                $settings = Get-AppSettings
                if ($reqData.clientAccessKey) { $settings.clientAccessKey = $reqData.clientAccessKey }
                if ($reqData.tokenEndpoint) { $settings.tokenEndpoint = $reqData.tokenEndpoint }

                $tokenRes = Get-F5BearerToken $settings
                Send-JsonResponse $response $tokenRes
            }
            elseif ($path -eq "/api/scan-case" -and $method -eq "POST") {
                $reqData = $bodyText | ConvertFrom-Json
                $caseNum = [string]$reqData.caseNumber
                $settings = Get-AppSettings

                $primaryPath = Join-Path $settings.baseDirectory "$caseNum\$($settings.incomingSubdir)"
                $fallbackPath = Join-Path $settings.fallbackUncDirectory "$caseNum\$($settings.incomingSubdir)"

                $targetPath = $null
                if (Test-Path $primaryPath) {
                    $targetPath = $primaryPath
                } elseif (Test-Path $fallbackPath) {
                    $targetPath = $fallbackPath
                } elseif (Test-Path (Join-Path $settings.baseDirectory $caseNum)) {
                    $targetPath = Join-Path $settings.baseDirectory $caseNum
                } elseif (Test-Path (Join-Path $settings.fallbackUncDirectory $caseNum)) {
                    $targetPath = Join-Path $settings.fallbackUncDirectory $caseNum
                }

                if (-not $targetPath) {
                    Send-JsonResponse $response @{ success = $false; error = "Directory not found for case #$caseNum. Checked paths: $primaryPath and $fallbackPath" }
                } else {
                    # Discover qkview files
                    $fileItems = @(Get-ChildItem -Path $targetPath -Recurse -File -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -like "*.qkview" -or $_.Name -like "*.tar.gz" -or $_.Name -like "*.tar" })

                    $fileList = @()
                    foreach ($item in $fileItems) {
                        if ($item) {
                            $rel = $item.FullName.Substring($targetPath.Length).TrimStart('\', '/')
                            $fileList += [PSCustomObject]@{
                                fileName = [string]$item.Name
                                filePath = [string]$item.FullName
                                relativePath = [string]$rel
                                sizeBytes = [long]$item.Length
                                sizeFormatted = [string](Format-FileSize $item.Length)
                                lastModified = [string]($item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
                                status = "pending"
                            }
                        }
                    }

                    $resObj = [PSCustomObject]@{
                        success = $true
                        scannedPath = [string]$targetPath
                        files = $fileList
                    }

                    Send-JsonResponse $response $resObj
                }
            }
            elseif ($path -eq "/api/upload-file" -and $method -eq "POST") {
                $reqData = $bodyText | ConvertFrom-Json
                $caseNum = [string]$reqData.caseNumber
                $filePath = [string]$reqData.filePath
                $settings = Get-AppSettings

                if (-not (Test-Path $filePath)) {
                    Send-JsonResponse $response @{ success = $false; error = "Local file not found: $filePath" }
                } else {
                    # Obtain Bearer token
                    $tokenRes = Get-F5BearerToken $settings
                    if (-not $tokenRes.success) {
                        Send-JsonResponse $response @{ success = $false; error = $tokenRes.error }
                    } else {
                        $bearerToken = $tokenRes.bearerToken
                        $uploadUrl = $settings.uploadEndpoint
                        $userAg = $settings.userAgent
                        $visible = $settings.visibleInGui

                        Write-Host "[UPLOAD] Uploading file to F5 iHealth..." -ForegroundColor Cyan
                        Write-Host "  -> File: $filePath" -ForegroundColor Gray
                        Write-Host "  -> Case #: $caseNum" -ForegroundColor Yellow
                        Write-Host "  -> Parameter: f5_support_case=$caseNum" -ForegroundColor Green

                        # Construct multipart curl upload command
                        $curlArgs = @(
                            "-s", "-X", "POST",
                            "-H", "Authorization: Bearer $bearerToken",
                            "-H", "Accept: application/vnd.f5.ihealth.api",
                            "--user-agent", "$userAg",
                            "-F", "qkview=@$filePath",
                            "-F", "visible_in_gui=$visible",
                            "-F", "f5_support_case=$caseNum",
                            "$uploadUrl"
                        )

                        $outputStr = & "C:\Windows\System32\curl.exe" $curlArgs 2>&1 | Out-String

                        # Check response
                        $isSuccess = ($outputStr -match "OK" -or $outputStr -match "qkview_id" -or $outputStr -match "200" -or $outputStr -match "202")
                        $resObj = [PSCustomObject]@{
                            success = $isSuccess
                            output = [string]$outputStr
                            error = if ($isSuccess) { $null } else { "iHealth upload response: $outputStr" }
                        }

                        Send-JsonResponse $response $resObj
                    }
                }
            }
            else {
                # Static File Server
                $relPath = $path.TrimStart('/')
                if ([string]::IsNullOrWhiteSpace($relPath)) { $relPath = "index.html" }
                $localFilePath = Join-Path $publicDir $relPath

                if (Test-Path $localFilePath -PathType Leaf) {
                    $ext = [System.IO.Path]::GetExtension($localFilePath).ToLower()
                    $contentType = switch ($ext) {
                        ".html" { "text/html; charset=utf-8" }
                        ".css"  { "text/css" }
                        ".js"   { "application/javascript" }
                        ".json" { "application/json" }
                        ".png"  { "image/png" }
                        ".svg"  { "image/svg+xml" }
                        default { "application/octet-stream" }
                    }

                    $fileBytes = [System.IO.File]::ReadAllBytes($localFilePath)
                    $response.ContentType = $contentType
                    $response.ContentLength64 = $fileBytes.Length
                    $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
                } else {
                    $response.StatusCode = 404
                    $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
                    $response.OutputStream.Write($msg, 0, $msg.Length)
                }
            }
        } catch {
            Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
            Send-JsonResponse $response @{ success = $false; error = "Server error: $($_.Exception.Message)" } 500
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Stop()
    Write-Host "Server stopped." -ForegroundColor Gray
}
