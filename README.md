# F5 iHealth QKView Case Uploader

An automated, user-friendly utility designed to discover `.qkview` diagnostic files in F5 support case incoming directories and upload them directly to F5 iHealth, linked to the specified support case.

This application is built based on F5 Knowledge Base Article **[K000135241: Uploading QKView files to support cases using the iHealth API](https://my.f5.com/manage/s/article/K000135241)**.

---

## 🌟 Key Features

* **⚡ Quick cURL Credentials Importer**: Simply copy the *"Request to obtain the Bearer access token"* `curl` command from the iHealth portal and paste it into the app — credentials and API token endpoints are parsed automatically.
* **🔍 Automated Case Directory Scanning**: Scans case incoming folders (e.g. `Z:\<case_number>\INCOMING` or network share paths) recursively for `.qkview`, `.tar.gz`, and `.tar` files.
* **🔑 Automatic OAuth Token Management**: Automatically exchanges your credentials for a 30-minute OAuth Bearer token without requiring manual CLI `curl` executions.
* **🚀 Batch & Single Upload Engine**: Uploads files directly to F5 iHealth with multipart form parameters (`f5_support_case`, `visible_in_gui=True`, `qkview=@file`).
* **📊 Dual Interface**:
  * **Modern Web Dashboard**: Glassmorphic UI with real-time stats, upload progress meters, and activity log stream (`http://localhost:8921/`).
  * **Native Windows Desktop App**: Standalone Windows Form GUI (`ihealth-uploader-gui.ps1`) for desktop execution without a browser.

---

## 🛠 Prerequisites & F5 Documentation

1. **Windows OS**: Windows 10/11 or Windows Server with PowerShell 5.1+.
2. **F5 iHealth API Credentials**:
   * Refer to **[F5 Article K000130498](https://my.f5.com/)** for instructions on generating API credentials in your iHealth web portal (*Settings > API Tokens > Generate New Credentials*).
   * Refer to **[F5 Article K000135241](https://my.f5.com/manage/s/article/K000135241)** for details on uploading QKView files to support cases via the iHealth API.

---

## 📥 Installation

### Option 1: Download as ZIP
1. Click the **Code** button on GitHub and select **Download ZIP**.
2. Extract the ZIP archive to a folder on your computer (e.g., `C:\Tools\ihealth-qkview-uploader`).

### Option 2: Clone Repository via Git
Open Command Prompt or PowerShell and clone the repository:
```bash
git clone https://github.com/your-org/ihealth-qkview-uploader.git
cd ihealth-qkview-uploader
```

---

## 🚀 Quick Start & Usage Instructions

### 1. Launch the Application
Double-click [`run-app.bat`](run-app.bat) or run it from Command Prompt / PowerShell:
```cmd
run-app.bat
```
*This starts the local backend server and automatically opens **`http://localhost:8921/`** in your default web browser.*

### 2. Configure Credentials (First-Time Setup)
1. Click **Settings** in the top-right header of the web interface.
2. In the **⚡ Quick Import** box, paste the full `curl` command copied from the iHealth portal settings window:
   ```bash
   curl --request POST --url https://identity.account.f5.com/oauth2/... -H "authorization: Basic MTIzNDU..."
   ```
3. Click **Auto-Parse & Import Credentials**.
4. Click **Save Settings**.
   *(Your credentials will be saved locally in `settings.json` which is ignored by Git).*

### 3. Scan & Upload QKViews
1. Enter your F5 support case number (e.g., `00412345`) in the search bar and click **Scan Directory**.
2. The application will locate all `.qkview` files in the target directory (including subfolders).
3. Select the files you wish to upload and click **Upload All QKViews to iHealth**.
4. Monitor live progress, elapsed time, and status log entries.

---

## 💻 Alternative: Standalone Windows Desktop GUI

If you prefer running a desktop application without opening a web browser, execute the standalone Windows Forms app in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File "ihealth-uploader-gui.ps1"
```

---

## 📁 Project File Structure

| File | Description |
|---|---|
| [`run-app.bat`](run-app.bat) | Batch launcher to start the server and open the web browser. |
| [`server.ps1`](server.ps1) | PowerShell REST API server providing local endpoints (`/api/scan-case`, `/api/test-token`, `/api/upload-file`). |
| [`public/index.html`](public/index.html) | Web application user interface layout. |
| [`public/style.css`](public/style.css) | Custom CSS stylesheet with glassmorphic dark theme and glowing indicators. |
| [`public/app.js`](public/app.js) | Frontend interactive logic for cURL parsing, case scanning, and upload progress. |
| [`ihealth-uploader-gui.ps1`](ihealth-uploader-gui.ps1) | Standalone Windows Forms desktop GUI app. |
| [`.gitignore`](.gitignore) | Ensures local `settings.json` is never committed to Git. |
| [`settings.json.example`](settings.json.example) | Clean template configuration file for initial distribution. |

---

## 🔒 Security & Privacy

* **Local Credentials Only**: API tokens and client secrets are stored exclusively in your local `settings.json` file.
* **Git Excluded**: `settings.json` is listed in `.gitignore` to prevent committing sensitive keys to public or shared repositories.

---

## 📄 References & Links

* **[MyF5 Support Portal](https://my.f5.com)**
* **[F5 iHealth Portal](https://ihealth.f5.com)**
* **[F5 KB Article K000135241](https://my.f5.com/manage/s/article/K000135241)**: Uploading QKView files to support cases using the iHealth API
* **[F5 KB Article K000130498](https://my.f5.com/)**: Generating iHealth API Token Credentials
