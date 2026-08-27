// F5 iHealth QKView Uploader Frontend Logic

document.addEventListener('DOMContentLoaded', () => {
  // UI Element Selectors
  const caseNumberInput = document.getElementById('case-number-input');
  const btnScanCase = document.getElementById('btn-scan-case');
  const targetPathDisplay = document.getElementById('target-path-display');
  
  const statFileCount = document.getElementById('stat-file-count');
  const statTotalSize = document.getElementById('stat-total-size');
  const statUploadedCount = document.getElementById('stat-uploaded-count');

  const fileTableBody = document.getElementById('file-table-body');
  const checkSelectAll = document.getElementById('check-select-all');
  const btnUploadAll = document.getElementById('btn-upload-all');

  const progressContainer = document.getElementById('progress-container');
  const progressStatusText = document.getElementById('progress-status-text');
  const progressPercentage = document.getElementById('progress-percentage');
  const progressBarFill = document.getElementById('progress-bar-fill');

  const logConsole = document.getElementById('log-console');
  const btnCopyLog = document.getElementById('btn-copy-log');
  const btnClearLog = document.getElementById('btn-clear-log');

  const connectionStatusBadge = document.getElementById('connection-status-badge');
  const connectionStatusText = document.getElementById('connection-status-text');

  // Modal Elements
  const settingsModal = document.getElementById('settings-modal');
  const btnOpenSettings = document.getElementById('btn-open-settings');
  const btnCloseModal = document.getElementById('btn-close-modal');
  const btnCancelSettings = document.getElementById('btn-cancel-settings');
  const btnSaveSettings = document.getElementById('btn-save-settings');
  const btnTestToken = document.getElementById('btn-test-token');
  const btnToggleKeyVisibility = document.getElementById('btn-toggle-key-visibility');

  const cfgCurlCommand = document.getElementById('cfg-curl-command');
  const btnParseCurl = document.getElementById('btn-parse-curl');
  const parseStatusMsg = document.getElementById('parse-status-msg');

  const cfgClientAccessKey = document.getElementById('cfg-client-access-key');
  const cfgClientId = document.getElementById('cfg-client-id');
  const cfgClientSecret = document.getElementById('cfg-client-secret');
  const cfgTokenEndpoint = document.getElementById('cfg-token-endpoint');
  const cfgUploadEndpoint = document.getElementById('cfg-upload-endpoint');
  const cfgBaseDirectory = document.getElementById('cfg-base-directory');
  const cfgFallbackUnc = document.getElementById('cfg-fallback-unc');
  const cfgIncomingSubdir = document.getElementById('cfg-incoming-subdir');
  const cfgVisibleGui = document.getElementById('cfg-visible-gui');

  // App State
  let currentSettings = {};
  let currentFiles = [];
  let isUploading = false;
  let uploadStartTime = null;

  // Initialize App
  init();

  async function init() {
    setupEventListeners();
    await loadSettings();
    updateTargetPathDisplay();
  }

  function setupEventListeners() {
    btnOpenSettings.addEventListener('click', openSettingsModal);
    btnCloseModal.addEventListener('click', closeSettingsModal);
    btnCancelSettings.addEventListener('click', closeSettingsModal);
    btnSaveSettings.addEventListener('click', saveSettings);
    btnTestToken.addEventListener('click', testTokenConnection);
    btnToggleKeyVisibility.addEventListener('click', toggleKeyVisibility);
    btnParseCurl.addEventListener('click', parseAndImportCurlCommand);

    btnScanCase.addEventListener('click', scanCaseDirectory);
    caseNumberInput.addEventListener('keyup', (e) => {
      updateTargetPathDisplay();
      if (e.key === 'Enter') scanCaseDirectory();
    });

    checkSelectAll.addEventListener('change', (e) => {
      const checkboxes = document.querySelectorAll('.file-checkbox');
      checkboxes.forEach(cb => cb.checked = e.target.checked);
    });

    btnUploadAll.addEventListener('click', startUploadBatch);
    btnCopyLog.addEventListener('click', copyLogsToClipboard);
    btnClearLog.addEventListener('click', clearLogConsole);
  }

  function updateTargetPathDisplay() {
    const caseNum = caseNumberInput.value.trim() || '00412345';
    const baseDir = currentSettings.baseDirectory || 'Z:\\';
    const subdir = currentSettings.incomingSubdir || 'INCOMING';
    targetPathDisplay.textContent = `${baseDir}${caseNum}\\${subdir}`;
  }

  function log(message, type = 'info') {
    const timeStr = new Date().toLocaleTimeString();
    const line = document.createElement('div');
    line.className = `log-line log-${type}`;
    line.innerHTML = `[<span class="log-time">${timeStr}</span>] ${escapeHtml(message)}`;
    logConsole.appendChild(line);
    logConsole.scrollTop = logConsole.scrollHeight;
  }

  function escapeHtml(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function clearLogConsole() {
    logConsole.innerHTML = '';
    log('Log console cleared.', 'info');
  }

  function copyLogsToClipboard() {
    const text = logConsole.innerText;
    navigator.clipboard.writeText(text).then(() => {
      log('Logs copied to clipboard.', 'success');
    }).catch(err => {
      log(`Failed to copy logs: ${err}`, 'error');
    });
  }

  // Load Settings from API
  async function loadSettings() {
    try {
      const res = await fetch('/api/settings');
      if (res.ok) {
        const text = await res.text();
        currentSettings = JSON.parse(text);
        populateSettingsForm(currentSettings);
        checkTokenStatus();
        log('Settings loaded successfully.', 'info');
      }
    } catch (err) {
      log(`Failed to connect to local uploader server: ${err.message}`, 'error');
    }
  }

  function populateSettingsForm(s) {
    cfgCurlCommand.value = s.rawCurlCommand || '';
    cfgClientAccessKey.value = s.clientAccessKey || '';
    cfgClientId.value = s.clientId || '';
    cfgClientSecret.value = s.clientSecret || '';
    cfgTokenEndpoint.value = s.tokenEndpoint || 'https://identity.account.f5.com/oauth2/v1/token';
    cfgUploadEndpoint.value = s.uploadEndpoint || 'https://ihealth2-api.f5.com/qkview-analyzer/api/qkviews';
    cfgBaseDirectory.value = s.baseDirectory || 'Z:\\';
    cfgFallbackUnc.value = s.fallbackUncDirectory || '\\\\olympus\\shares\\CDS\\Global';
    cfgIncomingSubdir.value = s.incomingSubdir || 'INCOMING';
    cfgVisibleGui.value = s.visibleInGui || 'True';
  }

  function checkTokenStatus() {
    if (currentSettings.clientAccessKey && currentSettings.clientAccessKey.trim().length > 0) {
      connectionStatusBadge.className = 'status-badge badge-success';
      connectionStatusText.textContent = 'Token Key Ready';
    } else {
      connectionStatusBadge.className = 'status-badge badge-warning';
      connectionStatusText.textContent = 'Token Not Configured';
    }
  }

  // Modal handlers
  function openSettingsModal() {
    populateSettingsForm(currentSettings);
    settingsModal.classList.remove('hidden');
  }

  function closeSettingsModal() {
    settingsModal.classList.add('hidden');
  }

  function toggleKeyVisibility() {
    if (cfgClientAccessKey.type === 'password') {
      cfgClientAccessKey.type = 'text';
      btnToggleKeyVisibility.textContent = 'Hide';
    } else {
      cfgClientAccessKey.type = 'password';
      btnToggleKeyVisibility.textContent = 'Show';
    }
  }

  // Auto Parse cURL Command
  function parseAndImportCurlCommand() {
    const rawCurl = cfgCurlCommand.value.trim();
    if (!rawCurl) {
      parseStatusMsg.textContent = '❌ Please paste a cURL command first.';
      parseStatusMsg.style.color = '#ef4444';
      return;
    }

    let parsedKey = null;
    let parsedUrl = null;

    // Extract Authorization Basic header
    const basicRegex = /-H\s+['"]authorization:\s*basic\s+([^'"]+)['"]/i;
    const basicMatch = rawCurl.match(basicRegex) || rawCurl.match(/authorization:\s*basic\s+([a-zA-Z0-9+/=]+)/i);
    if (basicMatch && basicMatch[1]) {
      parsedKey = basicMatch[1].trim();
    }

    // Extract Token Endpoint URL
    const urlRegex = /--(?:url|request\s+POST\s+--url)\s+['"]?([^'"]\S+)['"]?/i;
    const urlMatch = rawCurl.match(urlRegex) || rawCurl.match(/https:\/\/[^\s'"]+/i);
    if (urlMatch && urlMatch[1]) {
      parsedUrl = urlMatch[1].trim();
    } else if (urlMatch && urlMatch[0]) {
      parsedUrl = urlMatch[0].trim();
    }

    if (parsedKey) {
      cfgClientAccessKey.value = parsedKey;

      try {
        const decoded = atob(parsedKey);
        if (decoded.includes(':')) {
          const parts = decoded.split(':');
          cfgClientId.value = parts[0];
          cfgClientSecret.value = parts.slice(1).join(':');
        }
      } catch (e) {}

      if (parsedUrl) {
        cfgTokenEndpoint.value = parsedUrl;
      }

      parseStatusMsg.textContent = '✅ Credentials & Endpoint imported successfully!';
      parseStatusMsg.style.color = '#10b981';
      log('Successfully parsed F5 iHealth cURL command. Client Access Key imported.', 'success');
    } else {
      parseStatusMsg.textContent = '⚠️ Could not find Authorization: Basic key in cURL command.';
      parseStatusMsg.style.color = '#f59e0b';
      log('Could not extract Basic Authorization key from pasted cURL command.', 'warn');
    }
  }

  async function saveSettings() {
    const updated = {
      rawCurlCommand: cfgCurlCommand.value.trim(),
      clientAccessKey: cfgClientAccessKey.value.trim(),
      clientId: cfgClientId.value.trim(),
      clientSecret: cfgClientSecret.value.trim(),
      tokenEndpoint: cfgTokenEndpoint.value.trim(),
      uploadEndpoint: cfgUploadEndpoint.value.trim(),
      baseDirectory: cfgBaseDirectory.value.trim(),
      fallbackUncDirectory: cfgFallbackUnc.value.trim(),
      incomingSubdir: cfgIncomingSubdir.value.trim(),
      visibleInGui: cfgVisibleGui.value,
      userAgent: 'F5-iHealth-Uploader/1.0'
    };

    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updated)
      });
      if (res.ok) {
        currentSettings = updated;
        checkTokenStatus();
        updateTargetPathDisplay();
        log('Application settings saved successfully.', 'success');
        closeSettingsModal();
      } else {
        log('Failed to save settings to server.', 'error');
      }
    } catch (err) {
      log(`Error saving settings: ${err.message}`, 'error');
    }
  }

  async function testTokenConnection() {
    btnTestToken.disabled = true;
    btnTestToken.textContent = 'Testing...';
    log('Testing OAuth Bearer Token generation with F5 Identity Endpoint...', 'info');

    const tempSettings = {
      clientAccessKey: cfgClientAccessKey.value.trim(),
      clientId: cfgClientId.value.trim(),
      clientSecret: cfgClientSecret.value.trim(),
      tokenEndpoint: cfgTokenEndpoint.value.trim()
    };

    try {
      const res = await fetch('/api/test-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(tempSettings)
      });
      const text = await res.text();
      const data = JSON.parse(text);

      if (data.success) {
        log(`Token validation SUCCESS! Bearer token retrieved: ${data.bearerToken.substring(0, 16)}...`, 'success');
        alert('✅ OAuth Token Authentication Successful!\nBearer token generated automatically and valid for 30 minutes.');
      } else {
        log(`Token validation FAILED: ${data.error}`, 'error');
        alert(`❌ OAuth Authentication Failed:\n${data.error}`);
      }
    } catch (err) {
      log(`Token test exception: ${err.message}`, 'error');
      alert(`❌ Connection error: ${err.message}`);
    } finally {
      btnTestToken.disabled = false;
      btnTestToken.textContent = 'Test Token Connection';
    }
  }

  // Case Directory Scanner
  async function scanCaseDirectory() {
    const caseNum = caseNumberInput.value.trim();
    if (!caseNum) {
      alert('Please enter a valid F5 support case number.');
      return;
    }

    btnScanCase.disabled = true;
    btnScanCase.innerHTML = 'Scanning...';
    log(`Scanning target incoming directory for case #${caseNum}...`, 'info');

    try {
      const res = await fetch('/api/scan-case', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ caseNumber: caseNum })
      });
      
      const rawText = await res.text();
      let data;
      try {
        data = JSON.parse(rawText);
      } catch (parseErr) {
        log(`Case scan error: ${parseErr.message} (Raw response: ${rawText.substring(0, 80)})`, 'error');
        btnScanCase.disabled = false;
        btnScanCase.innerHTML = `<span>Scan Directory</span>`;
        return;
      }

      if (data.success) {
        currentFiles = Array.isArray(data.files) ? data.files : (data.files ? [data.files] : []);
        renderFileList(currentFiles);
        updateStats();
        log(`Found ${currentFiles.length} QKView file(s) in path: ${data.scannedPath}`, 'success');
      } else {
        currentFiles = [];
        renderFileList([]);
        updateStats();
        log(`Scan failed: ${data.error}`, 'warn');
      }
    } catch (err) {
      log(`Case scan error: ${err.message}`, 'error');
    } finally {
      btnScanCase.disabled = false;
      btnScanCase.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"></circle>
          <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
        </svg>
        <span>Scan Directory</span>
      `;
    }
  }

  function renderFileList(files) {
    fileTableBody.innerHTML = '';

    if (!files || files.length === 0) {
      btnUploadAll.disabled = true;
      fileTableBody.innerHTML = `
        <tr class="empty-row">
          <td colspan="7">
            <div class="empty-state">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path>
              </svg>
              <p>No QKView files found in case directory.</p>
            </div>
          </td>
        </tr>
      `;
      return;
    }

    btnUploadAll.disabled = false;

    files.forEach((f, idx) => {
      const tr = document.createElement('tr');
      tr.dataset.index = idx;

      let tagClass = 'tag-pending';
      let tagText = 'Pending';
      if (f.status === 'uploading') { tagClass = 'tag-uploading'; tagText = 'Uploading...'; }
      else if (f.status === 'success') { tagClass = 'tag-success'; tagText = 'Uploaded'; }
      else if (f.status === 'error') { tagClass = 'tag-error'; tagText = 'Failed'; }

      tr.innerHTML = `
        <td><input type="checkbox" class="file-checkbox" data-index="${idx}" checked /></td>
        <td><strong>${escapeHtml(f.fileName)}</strong></td>
        <td><code>${escapeHtml(f.relativePath || '.')}</code></td>
        <td>${escapeHtml(f.sizeFormatted)}</td>
        <td>${escapeHtml(f.lastModified || 'N/A')}</td>
        <td><span class="tag ${tagClass}" id="tag-status-${idx}">${tagText}</span></td>
        <td>
          <button class="btn btn-small btn-secondary btn-upload-single" data-index="${idx}">Upload</button>
        </td>
      `;

      fileTableBody.appendChild(tr);
    });

    document.querySelectorAll('.btn-upload-single').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const index = parseInt(e.currentTarget.dataset.index);
        uploadSingleFile(index);
      });
    });
  }

  function updateStats() {
    statFileCount.textContent = currentFiles.length;
    
    let totalBytes = currentFiles.reduce((acc, f) => acc + (f.sizeBytes || 0), 0);
    let totalMB = (totalBytes / (1024 * 1024)).toFixed(1);
    statTotalSize.textContent = `${totalMB} MB`;

    let uploaded = currentFiles.filter(f => f.status === 'success').length;
    statUploadedCount.textContent = uploaded;
  }

  // Upload Logic
  async function uploadSingleFile(index) {
    if (isUploading) return;
    const file = currentFiles[index];
    if (!file) return;

    await processUploadQueue([file], [index]);
  }

  async function startUploadBatch() {
    if (isUploading) return;

    const selectedIndices = [];
    document.querySelectorAll('.file-checkbox:checked').forEach(cb => {
      selectedIndices.push(parseInt(cb.dataset.index));
    });

    if (selectedIndices.length === 0) {
      alert('Please select at least one QKView file to upload.');
      return;
    }

    const targetFiles = selectedIndices.map(i => currentFiles[i]);
    await processUploadQueue(targetFiles, selectedIndices);
  }

  async function processUploadQueue(filesToUpload, indices) {
    isUploading = true;
    btnUploadAll.disabled = true;
    progressContainer.classList.remove('hidden');
    uploadStartTime = Date.now();

    const caseNum = caseNumberInput.value.trim();
    let successCount = 0;
    let failCount = 0;

    log(`Starting upload process for ${filesToUpload.length} QKView file(s)...`, 'info');

    for (let i = 0; i < filesToUpload.length; i++) {
      const file = filesToUpload[i];
      const idx = indices[i];

      file.status = 'uploading';
      updateRowStatus(idx, 'uploading', 'Uploading...');
      
      const pct = Math.round(((i) / filesToUpload.length) * 100);
      updateOverallProgress(pct, `Uploading file ${i + 1} of ${filesToUpload.length}: ${file.fileName}`);

      log(`[${i + 1}/${filesToUpload.length}] Uploading ${file.fileName} (${file.sizeFormatted}) to case #${caseNum}...`, 'info');

      try {
        const res = await fetch('/api/upload-file', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            caseNumber: caseNum,
            filePath: file.filePath
          })
        });
        const text = await res.text();
        const result = JSON.parse(text);

        if (result.success) {
          file.status = 'success';
          updateRowStatus(idx, 'success', 'Uploaded');
          successCount++;
          log(`[SUCCESS] ${file.fileName} uploaded to iHealth successfully.`, 'success');
        } else {
          file.status = 'error';
          updateRowStatus(idx, 'error', 'Failed');
          failCount++;
          log(`[FAILED] Upload of ${file.fileName} failed: ${result.error}`, 'error');
        }
      } catch (err) {
        file.status = 'error';
        updateRowStatus(idx, 'error', 'Failed');
        failCount++;
        log(`[ERROR] Network error during upload of ${file.fileName}: ${err.message}`, 'error');
      }

      updateStats();
    }

    updateOverallProgress(100, `Upload completed. Success: ${successCount}, Failed: ${failCount}`);
    log(`Batch upload process finished. Success: ${successCount}, Failed: ${failCount}.`, successCount > 0 ? 'success' : 'warn');

    isUploading = false;
    btnUploadAll.disabled = false;
  }

  function updateRowStatus(index, status, text) {
    const tag = document.getElementById(`tag-status-${index}`);
    if (tag) {
      tag.className = `tag tag-${status}`;
      tag.textContent = text;
    }
  }

  function updateOverallProgress(pct, statusText) {
    progressBarFill.style.width = `${pct}%`;
    progressPercentage.textContent = `${pct}%`;
    progressStatusText.textContent = statusText;
  }
});
