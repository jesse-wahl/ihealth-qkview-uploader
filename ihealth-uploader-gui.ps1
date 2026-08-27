# F5 iHealth QKView Uploader - Standalone Desktop GUI Application

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsFile = Join-Path $scriptDir "settings.json"

function Get-AppSettings {
    if (Test-Path $settingsFile) {
        try { return Get-Content $settingsFile -Raw | ConvertFrom-Json } catch {}
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

function Save-AppSettings($settings) {
    $json = $settings | ConvertTo-Json -Depth 5
    Set-Content -Path $settingsFile -Value $json -Encoding UTF8
}

function Get-F5BearerToken($settings) {
    $accessKey = $settings.clientAccessKey
    if ([string]::IsNullOrWhiteSpace($accessKey) -and $settings.clientId -and $settings.clientSecret) {
        $rawKey = "$($settings.clientId):$($settings.clientSecret)"
        $accessKey = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rawKey))
    }

    if ([string]::IsNullOrWhiteSpace($accessKey)) {
        return @{ success = $false; error = "Client Access Key is not configured in Settings." }
    }

    $curlArgs = @(
        "-s", "-X", "POST",
        "-H", "Accept: application/json",
        "-H", "Authorization: Basic $accessKey",
        "-H", "Content-Type: application/x-www-form-urlencoded",
        "-d", "grant_type=client_credentials&scope=ihealth",
        "$($settings.tokenEndpoint)"
    )

    try {
        $resultStr = & "C:\Windows\System32\curl.exe" $curlArgs 2>&1 | Out-String
        if ($resultStr -match "access_token") {
            $jsonRes = $resultStr | ConvertFrom-Json
            return @{ success = $true; bearerToken = $jsonRes.access_token }
        } else {
            return @{ success = $false; error = "Failed to generate token: $resultStr" }
        }
    } catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# Create Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "F5 iHealth QKView Case Uploader (K000135241)"
$form.Size = New-Object System.Drawing.Size(940, 650)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# Header Panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = "Top"
$headerPanel.Height = 65
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$form.Controls.Add($headerPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "F5 iHealth QKView Case Uploader"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(139, 92, 246)
$lblTitle.Location = New-Object System.Drawing.Point(16, 12)
$lblTitle.AutoSize = $true
$headerPanel.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Automated QKView discovery and upload based on F5 Article K000135241"
$lblSub.ForeColor = [System.Drawing.Color]::LightGray
$lblSub.Location = New-Object System.Drawing.Point(18, 38)
$lblSub.AutoSize = $true
$headerPanel.Controls.Add($lblSub)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "⚙ Settings"
$btnSettings.Size = New-Object System.Drawing.Size(110, 34)
$btnSettings.Location = New-Object System.Drawing.Point(800, 16)
$btnSettings.BackColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$btnSettings.ForeColor = [System.Drawing.Color]::White
$btnSettings.FlatStyle = "Flat"
$headerPanel.Controls.Add($btnSettings)

# Controls Panel
$ctrlPanel = New-Object System.Windows.Forms.Panel
$ctrlPanel.Dock = "Top"
$ctrlPanel.Height = 60
$ctrlPanel.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 12)
$form.Controls.Add($ctrlPanel)

$lblCase = New-Object System.Windows.Forms.Label
$lblCase.Text = "Case #:"
$lblCase.Location = New-Object System.Drawing.Point(16, 18)
$lblCase.AutoSize = $true
$ctrlPanel.Controls.Add($lblCase)

$txtCase = New-Object System.Windows.Forms.TextBox
$txtCase.Text = "00412345"
$txtCase.Location = New-Object System.Drawing.Point(75, 15)
$txtCase.Size = New-Object System.Drawing.Size(120, 28)
$txtCase.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$txtCase.ForeColor = [System.Drawing.Color]::White
$ctrlPanel.Controls.Add($txtCase)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "🔍 Scan Directory"
$btnScan.Location = New-Object System.Drawing.Point(205, 13)
$btnScan.Size = New-Object System.Drawing.Size(130, 32)
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(139, 92, 246)
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$ctrlPanel.Controls.Add($btnScan)

$btnUploadAll = New-Object System.Windows.Forms.Button
$btnUploadAll.Text = "🚀 Upload All QKViews"
$btnUploadAll.Location = New-Object System.Drawing.Point(345, 13)
$btnUploadAll.Size = New-Object System.Drawing.Size(160, 32)
$btnUploadAll.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$btnUploadAll.ForeColor = [System.Drawing.Color]::White
$btnUploadAll.FlatStyle = "Flat"
$btnUploadAll.Enabled = $false
$ctrlPanel.Controls.Add($btnUploadAll)

# DataGridView for Files
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = "Top"
$grid.Height = 280
$grid.BackgroundColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$grid.ForeColor = [System.Drawing.Color]::Black
$grid.AllowUserToAddRows = $false
$grid.SelectionMode = "FullRowSelect"
$grid.AutoSizeColumnsMode = "Fill"

[void]$grid.Columns.Add("fileName", "File Name")
[void]$grid.Columns.Add("relativePath", "Subpath")
[void]$grid.Columns.Add("sizeFormatted", "Size")
[void]$grid.Columns.Add("lastModified", "Last Modified")
[void]$grid.Columns.Add("status", "Status")
[void]$grid.Columns.Add("filePath", "Full Path")

$form.Controls.Add($grid)

# Log TextBox
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Dock = "Fill"
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(2, 6, 23)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(74, 222, 128)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

# Log Helper
function Write-Log($msg) {
    $timeStr = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$timeStr] $msg`r`n")
}

# Scan Event
$script:discoveredFiles = @()
$btnScan.Add_Click({
    $caseNum = $txtCase.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($caseNum)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a case number.", "Error", "OK", "Error")
        return
    }

    Write-Log "Scanning for case #$caseNum..."
    $settings = Get-AppSettings
    $primaryPath = Join-Path $settings.baseDirectory "$caseNum\$($settings.incomingSubdir)"
    $fallbackPath = Join-Path $settings.fallbackUncDirectory "$caseNum\$($settings.incomingSubdir)"

    $targetPath = $null
    if (Test-Path $primaryPath) { $targetPath = $primaryPath }
    elseif (Test-Path $fallbackPath) { $targetPath = $fallbackPath }

    if (-not $targetPath) {
        Write-Log "[ERROR] Directory not found for case #$caseNum. Checked: $primaryPath"
        [System.Windows.Forms.MessageBox]::Show("Directory not found for case #$caseNum", "Path Error", "OK", "Warning")
        return
    }

    $grid.Rows.Clear()
    $files = Get-ChildItem -Path $targetPath -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "*.qkview" -or $_.Name -like "*.tar.gz" }

    $script:discoveredFiles = $files
    Write-Log "Found $($files.Count) QKView file(s) in $targetPath"

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($targetPath.Length).TrimStart('\')
        $sizeStr = "{0:N1} MB" -f ($f.Length / 1MB)
        [void]$grid.Rows.Add($f.Name, $rel, $sizeStr, $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), "Pending", $f.FullName)
    }

    $btnUploadAll.Enabled = ($files.Count -gt 0)
})

# Upload Event
$btnUploadAll.Add_Click({
    $caseNum = $txtCase.Text.Trim()
    $settings = Get-AppSettings

    Write-Log "Requesting OAuth token for upload..."
    $tokenRes = Get-F5BearerToken $settings
    if (-not $tokenRes.success) {
        Write-Log "[ERROR] Token generation failed: $($tokenRes.error)"
        [System.Windows.Forms.MessageBox]::Show($tokenRes.error, "Token Error", "OK", "Error")
        return
    }

    $bearerToken = $tokenRes.bearerToken
    Write-Log "[SUCCESS] OAuth Bearer token acquired. Starting uploads..."

    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        $row = $grid.Rows[$i]
        $filePath = $row.Cells["filePath"].Value
        $fileName = $row.Cells["fileName"].Value

        $row.Cells["status"].Value = "Uploading..."
        Write-Log "Uploading $fileName..."

        $curlArgs = @(
            "-s", "-X", "POST",
            "-H", "Authorization: Bearer $bearerToken",
            "-H", "Accept: application/vnd.f5.ihealth.api",
            "--user-agent", "$($settings.userAgent)",
            "-F", "qkview=@$filePath",
            "-F", "visible_in_gui=$($settings.visibleInGui)",
            "-F", "f5_support_case=$caseNum",
            "$($settings.uploadEndpoint)"
        )

        $output = & "C:\Windows\System32\curl.exe" $curlArgs 2>&1 | Out-String
        if ($output -match "OK" -or $output -match "qkview_id" -or $output -match "200") {
            $row.Cells["status"].Value = "Uploaded"
            Write-Log "[SUCCESS] $fileName uploaded successfully!"
        } else {
            $row.Cells["status"].Value = "Failed"
            Write-Log "[FAILED] $fileName: $output"
        }
    }
    Write-Log "All upload tasks completed."
})

# Settings Dialog Event
$btnSettings.Add_Click({
    $settings = Get-AppSettings
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Application Settings"
    $dlg.Size = New-Object System.Drawing.Size(560, 480)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"

    # cURL Import Section
    $lblCurl = New-Object System.Windows.Forms.Label
    $lblCurl.Text = "Paste Generated cURL Command from iHealth Portal:"
    $lblCurl.Location = New-Object System.Drawing.Point(20, 15)
    $lblCurl.AutoSize = $true
    $dlg.Controls.Add($lblCurl)

    $txtCurl = New-Object System.Windows.Forms.TextBox
    $txtCurl.Text = $settings.rawCurlCommand
    $txtCurl.Multiline = $true
    $txtCurl.ScrollBars = "Vertical"
    $txtCurl.Location = New-Object System.Drawing.Point(20, 38)
    $txtCurl.Size = New-Object System.Drawing.Size(500, 60)
    $dlg.Controls.Add($txtCurl)

    $btnParse = New-Object System.Windows.Forms.Button
    $btnParse.Text = "Auto-Parse cURL Command"
    $btnParse.Location = New-Object System.Drawing.Point(20, 104)
    $btnParse.Size = New-Object System.Drawing.Size(180, 28)
    $btnParse.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
    $btnParse.ForeColor = [System.Drawing.Color]::White
    $btnParse.FlatStyle = "Flat"
    $dlg.Controls.Add($btnParse)

    $lblKey = New-Object System.Windows.Forms.Label
    $lblKey.Text = "Client Access Key (Base64):"
    $lblKey.Location = New-Object System.Drawing.Point(20, 145)
    $lblKey.AutoSize = $true
    $dlg.Controls.Add($lblKey)

    $txtKey = New-Object System.Windows.Forms.TextBox
    $txtKey.Text = $settings.clientAccessKey
    $txtKey.Location = New-Object System.Drawing.Point(20, 168)
    $txtKey.Size = New-Object System.Drawing.Size(500, 26)
    $dlg.Controls.Add($txtKey)

    $lblEndpoint = New-Object System.Windows.Forms.Label
    $lblEndpoint.Text = "OAuth Token Endpoint URL:"
    $lblEndpoint.Location = New-Object System.Drawing.Point(20, 205)
    $lblEndpoint.AutoSize = $true
    $dlg.Controls.Add($lblEndpoint)

    $txtEndpoint = New-Object System.Windows.Forms.TextBox
    $txtEndpoint.Text = $settings.tokenEndpoint
    $txtEndpoint.Location = New-Object System.Drawing.Point(20, 228)
    $txtEndpoint.Size = New-Object System.Drawing.Size(500, 26)
    $dlg.Controls.Add($txtEndpoint)

    $lblBase = New-Object System.Windows.Forms.Label
    $lblBase.Text = "Base Drive Path:"
    $lblBase.Location = New-Object System.Drawing.Point(20, 265)
    $lblBase.AutoSize = $true
    $dlg.Controls.Add($lblBase)

    $txtBase = New-Object System.Windows.Forms.TextBox
    $txtBase.Text = $settings.baseDirectory
    $txtBase.Location = New-Object System.Drawing.Point(20, 288)
    $txtBase.Size = New-Object System.Drawing.Size(500, 26)
    $dlg.Controls.Add($txtBase)

    $btnParse.Add_Click({
        $raw = $txtCurl.Text.Trim()
        if ($raw -match "authorization:\s*basic\s+([a-zA-Z0-9+/=]+)") {
            $txtKey.Text = $Matches[1].Trim()
        }
        if ($raw -match "https:\/\/[^\s'"]+") {
            $txtEndpoint.Text = $Matches[0].Trim()
        }
        [System.Windows.Forms.MessageBox]::Show("cURL command parsed successfully!", "Import", "OK", "Information")
    })

    $btnSaveDlg = New-Object System.Windows.Forms.Button
    $btnSaveDlg.Text = "Save Settings"
    $btnSaveDlg.Location = New-Object System.Drawing.Point(400, 380)
    $btnSaveDlg.Size = New-Object System.Drawing.Size(120, 32)
    $btnSaveDlg.DialogResult = "OK"
    $dlg.Controls.Add($btnSaveDlg)

    if ($dlg.ShowDialog() -eq "OK") {
        $settings.rawCurlCommand = $txtCurl.Text.Trim()
        $settings.clientAccessKey = $txtKey.Text.Trim()
        $settings.tokenEndpoint = $txtEndpoint.Text.Trim()
        $settings.baseDirectory = $txtBase.Text.Trim()
        Save-AppSettings $settings
        Write-Log "Settings updated."
    }
})

Write-Log "F5 iHealth QKView Case Uploader Desktop App ready."
[void]$form.ShowDialog()
