-- ============================================================================
-- Oracle APEX Secure PDF Viewer - Complete Installation Script
-- ============================================================================
-- Run this script to install all database objects
-- ============================================================================

SET SERVEROUTPUT ON
SET DEFINE OFF

PROMPT ============================================
PROMPT Installing Secure PDF Viewer for Oracle APEX
PROMPT ============================================

PROMPT
PROMPT Step 1: Creating Tables...
PROMPT ============================================
@tables/documents_table.sql

PROMPT
PROMPT Step 2: Creating Package Specification...
PROMPT ============================================
@packages/pkg_oci_object_storage_spec.sql

PROMPT
PROMPT Step 3: Creating Package Body...
PROMPT ============================================
@packages/pkg_oci_object_storage_body.sql

PROMPT
PROMPT ============================================
PROMPT Installation Complete!
PROMPT ============================================
PROMPT
PROMPT Next Steps:
PROMPT 1. Configure OCI Web Credentials in APEX
PROMPT    Edit and run: setup/oci_web_credentials.sql
PROMPT
PROMPT 2. Upload static files to APEX:
PROMPT    - apex/js/secure-pdf-viewer.js
PROMPT    - apex/css/secure-pdf-viewer.css
PROMPT
PROMPT 3. Create APEX pages following the guides in:
PROMPT    - apex/pages/admin_upload_page.sql
PROMPT    - apex/pages/user_view_page.sql
PROMPT
PROMPT 4. Create the SERVE_PDF application process:
PROMPT    - apex/processes/serve_pdf_process.sql
PROMPT
PROMPT See APEX_OCI_PDF_VIEWER.md for detailed instructions
PROMPT ============================================

SET DEFINE ON
