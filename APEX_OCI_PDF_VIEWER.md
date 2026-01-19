# Oracle APEX Secure PDF Viewer with OCI Object Storage

A secure document viewing solution for Oracle APEX that allows administrators to upload PDF documents to OCI Object Storage while restricting end users to view-only access (no downloads).

## Features

- **Admin PDF Upload**: Upload PDF files directly to OCI Object Storage
- **Secure Viewing**: End users can view PDFs but cannot download them
- **Download Prevention**:
  - No download/print buttons
  - Right-click disabled
  - Keyboard shortcuts (Ctrl+S, Ctrl+P) blocked
  - Content-Disposition set to inline
- **Audit Trail**: All document views are logged
- **Pre-Authenticated Requests**: Time-limited secure URLs for enhanced security
- **Responsive Design**: Works on desktop and mobile devices

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│                 │     │                  │     │                     │
│  Oracle APEX    │────▶│  PL/SQL Package  │────▶│  OCI Object Storage │
│  Application    │     │  (API Handler)   │     │  (PDF Bucket)       │
│                 │◀────│                  │◀────│                     │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
        │                        │
        │                        │
        ▼                        ▼
┌─────────────────┐     ┌──────────────────┐
│  Secure PDF.js  │     │  Oracle Database │
│  Viewer         │     │  (Metadata)      │
└─────────────────┘     └──────────────────┘
```

## Prerequisites

- Oracle APEX 21.2 or higher
- Oracle Database 19c or higher
- OCI Object Storage bucket
- OCI API Key credentials

## Installation

### Step 1: Create Database Objects

Run the following scripts in order:

```sql
-- 1. Create tables
@database/tables/documents_table.sql

-- 2. Create package specification
@database/packages/pkg_oci_object_storage_spec.sql

-- 3. Create package body
@database/packages/pkg_oci_object_storage_body.sql
```

### Step 2: Configure OCI Web Credentials

1. Generate OCI API Key in your OCI Console
2. Update `database/setup/oci_web_credentials.sql` with your credentials:
   - Tenancy OCID
   - User OCID
   - API Key Fingerprint
   - Private Key
3. Run the script in your APEX workspace

### Step 3: Upload Static Files to APEX

1. Go to **Shared Components** > **Static Application Files**
2. Upload:
   - `apex/js/secure-pdf-viewer.js`
   - `apex/css/secure-pdf-viewer.css`

### Step 4: Create APEX Pages

#### Admin Upload Page (Page 10)

1. Create a new page with:
   - File Browse item (`P10_FILE`)
   - Text Field (`P10_DOCUMENT_TITLE`)
   - Text Area (`P10_DESCRIPTION`)
   - Select List (`P10_BUCKET_NAME`)
   - Upload Button

2. Add the page process from `apex/pages/admin_upload_page.sql`

3. Add the Interactive Report for document listing

#### User Viewer Page (Page 20)

1. Create a new page with:
   - Hidden Item (`P20_DOCUMENT_ID`)
   - Static Content region with:
     ```html
     <div id="pdf-viewer-container" style="height: 800px;"></div>
     ```

2. Add to HTML Header:
   ```html
   <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
   <link rel="stylesheet" href="#APP_FILES#css/secure-pdf-viewer.css">
   <script src="#APP_FILES#js/secure-pdf-viewer.js"></script>
   ```

3. Create Page Load Dynamic Action:
   ```javascript
   var documentId = apex.item('P20_DOCUMENT_ID').getValue();

   if (documentId) {
       SecurePDFViewer.init({
           containerId: 'pdf-viewer-container',
           pdfUrl: apex.server.url({
               process: 'SERVE_PDF',
               x01: documentId
           }),
           scale: 1.0
       });
   }
   ```

### Step 5: Create Application Process

1. Go to **Shared Components** > **Application Processes**
2. Create new process:
   - Name: `SERVE_PDF`
   - Point: Ajax Callback
   - Code: Use content from `apex/processes/serve_pdf_process.sql`

## OCI IAM Policy

Add this policy to allow your user to access Object Storage:

```
Allow user <username> to manage objects in compartment <compartment-name> where target.bucket.name = '<bucket-name>'
```

## Security Measures

### Client-Side Protection

| Protection | Description |
|------------|-------------|
| No Download Button | PDF.js viewer configured without download |
| No Print Button | Print functionality removed |
| Right-Click Disabled | Context menu blocked on viewer |
| Keyboard Shortcuts Blocked | Ctrl+S, Ctrl+P intercepted |
| Text Selection Disabled | CSS prevents text selection |
| Print Media Query | Shows warning instead of content |

### Server-Side Protection

| Protection | Description |
|------------|-------------|
| Content-Disposition: inline | Browser displays, doesn't download |
| Time-Limited PAR URLs | URLs expire after configurable minutes |
| Access Logging | All views recorded in database |
| Authorization Checks | Verify user permissions |

## Configuration Options

### Viewer Options

```javascript
SecurePDFViewer.init({
    containerId: 'pdf-viewer-container',  // Container element ID
    pdfUrl: 'url-to-pdf',                 // PDF URL
    scale: 1.0,                           // Initial zoom (0.5 - 3.0)
    maxScale: 3.0,                        // Maximum zoom
    minScale: 0.5                         // Minimum zoom
});
```

### Package Constants

```sql
gc_default_par_duration CONSTANT NUMBER := 5;  -- PAR validity in minutes
```

## API Reference

### pkg_oci_object_storage

#### upload_pdf_to_oci
Uploads a PDF to OCI Object Storage.

```sql
pkg_oci_object_storage.upload_pdf_to_oci(
    p_file_content    IN BLOB,
    p_file_name       IN VARCHAR2,
    p_bucket_name     IN VARCHAR2,
    p_credential_name IN VARCHAR2 DEFAULT 'OCI_CRED',
    p_document_title  IN VARCHAR2 DEFAULT NULL,
    p_description     IN VARCHAR2 DEFAULT NULL,
    p_document_id     OUT NUMBER,
    p_status          OUT VARCHAR2,
    p_message         OUT VARCHAR2
);
```

#### get_par_for_viewing
Generates a time-limited Pre-Authenticated Request URL.

```sql
l_url := pkg_oci_object_storage.get_par_for_viewing(
    p_document_id      => 123,
    p_credential_name  => 'OCI_CRED',
    p_duration_minutes => 5
);
```

#### get_pdf_content
Fetches PDF content as BLOB.

```sql
l_blob := pkg_oci_object_storage.get_pdf_content(
    p_document_id     => 123,
    p_credential_name => 'OCI_CRED'
);
```

## Troubleshooting

### PDF Not Loading

1. Check browser console for JavaScript errors
2. Verify OCI credentials are correctly configured
3. Ensure APEX server can reach OCI endpoints
4. Check document exists and is_active = 'Y'

### 401 Unauthorized from OCI

1. Verify API key is not expired
2. Check fingerprint matches the key
3. Ensure IAM policy grants access
4. Verify correct region endpoint

### CORS Errors

If serving PDF from different domain, configure APEX to proxy requests or use PAR URLs which don't have CORS restrictions.

## Limitations

- Client-side protections can be bypassed by technical users
- Screenshots cannot be prevented
- Browser developer tools can access PDF data
- For highly sensitive documents, consider:
  - Server-side PDF-to-image conversion
  - Digital watermarking
  - DRM solutions

## File Structure

```
.
├── database/
│   ├── tables/
│   │   └── documents_table.sql
│   ├── packages/
│   │   ├── pkg_oci_object_storage_spec.sql
│   │   └── pkg_oci_object_storage_body.sql
│   └── setup/
│       └── oci_web_credentials.sql
├── apex/
│   ├── js/
│   │   └── secure-pdf-viewer.js
│   ├── css/
│   │   └── secure-pdf-viewer.css
│   ├── pages/
│   │   ├── admin_upload_page.sql
│   │   └── user_view_page.sql
│   └── processes/
│       └── serve_pdf_process.sql
└── README.md
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

## Author

Yagnik Gondaliya - [gondaliyayagnik4@gmail.com](mailto:gondaliyayagnik4@gmail.com)
