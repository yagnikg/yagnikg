-- ============================================================================
-- APEX Page: Admin PDF Upload (Page 10)
-- ============================================================================
-- This page allows administrators to upload PDF files to OCI Object Storage
-- ============================================================================

-- Page Items Required:
-- P10_FILE          - File Browse (for PDF upload)
-- P10_DOCUMENT_TITLE - Text Field
-- P10_DESCRIPTION   - Text Area
-- P10_BUCKET_NAME   - Select List or Text Field (OCI Bucket name)

-- ============================================================================
-- Page Process: Upload PDF to OCI (After Submit)
-- ============================================================================
-- Process Name: Upload_PDF_To_OCI
-- Type: PL/SQL Code
-- Point: Processing - After Submit
-- When Button Pressed: UPLOAD (or your button name)
-- ============================================================================

DECLARE
    l_file_content      BLOB;
    l_file_name         VARCHAR2(500);
    l_mime_type         VARCHAR2(100);
    l_document_id       NUMBER;
    l_status            VARCHAR2(50);
    l_message           VARCHAR2(4000);
BEGIN
    -- Get uploaded file from APEX collection
    FOR rec IN (
        SELECT filename, blob_content, mime_type
        FROM apex_application_temp_files
        WHERE name = :P10_FILE
    ) LOOP
        l_file_content := rec.blob_content;
        l_file_name := rec.filename;
        l_mime_type := rec.mime_type;
    END LOOP;

    -- Validate file is PDF
    IF l_mime_type != 'application/pdf' THEN
        apex_error.add_error(
            p_message          => 'Only PDF files are allowed.',
            p_display_location => apex_error.c_inline_in_notification
        );
        RETURN;
    END IF;

    -- Validate file size (e.g., max 50MB)
    IF DBMS_LOB.GETLENGTH(l_file_content) > 52428800 THEN
        apex_error.add_error(
            p_message          => 'File size exceeds 50MB limit.',
            p_display_location => apex_error.c_inline_in_notification
        );
        RETURN;
    END IF;

    -- Upload to OCI Object Storage
    pkg_oci_object_storage.upload_pdf_to_oci(
        p_file_content    => l_file_content,
        p_file_name       => l_file_name,
        p_bucket_name     => :P10_BUCKET_NAME,
        p_credential_name => 'OCI_CRED',
        p_document_title  => :P10_DOCUMENT_TITLE,
        p_description     => :P10_DESCRIPTION,
        p_document_id     => l_document_id,
        p_status          => l_status,
        p_message         => l_message
    );

    IF l_status = 'SUCCESS' THEN
        -- Success message
        apex_application.g_print_success_message :=
            'Document uploaded successfully. Document ID: ' || l_document_id;

        -- Clear form
        :P10_FILE := NULL;
        :P10_DOCUMENT_TITLE := NULL;
        :P10_DESCRIPTION := NULL;
    ELSE
        -- Error
        apex_error.add_error(
            p_message          => l_message,
            p_display_location => apex_error.c_inline_in_notification
        );
    END IF;
END;

-- ============================================================================
-- Interactive Report: Document List
-- ============================================================================
-- Region Type: Interactive Report
-- Source SQL:
-- ============================================================================

SELECT
    document_id,
    document_name,
    document_title,
    description,
    ROUND(file_size_bytes / 1024, 2) AS file_size_kb,
    uploaded_by,
    TO_CHAR(uploaded_date, 'DD-MON-YYYY HH24:MI') AS uploaded_date,
    view_count,
    is_active,
    CASE
        WHEN is_active = 'Y' THEN
            '<a href="f?p=' || :APP_ID || ':20:' || :APP_SESSION ||
            '::NO::P20_DOCUMENT_ID:' || document_id || '" class="t-Button t-Button--small t-Button--primary">
            <span class="fa fa-eye"></span> View</a>'
        ELSE
            '<span class="t-Badge t-Badge--warning">Inactive</span>'
    END AS actions
FROM pdf_documents
ORDER BY uploaded_date DESC;

-- ============================================================================
-- Page Validation: Check File Selected
-- ============================================================================
-- Validation Name: File_Required
-- Type: PL/SQL Function (returning Boolean)
-- Associated Item: P10_FILE
-- ============================================================================

RETURN :P10_FILE IS NOT NULL;

-- Error Message: Please select a PDF file to upload.
