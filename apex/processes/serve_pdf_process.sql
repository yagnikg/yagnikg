-- ============================================================================
-- APEX Application Process: Serve PDF for Viewing
-- ============================================================================
-- This process should be created as an "On Demand" Application Process
-- Name: SERVE_PDF
-- Point: Ajax Callback
-- ============================================================================

DECLARE
    l_document_id   NUMBER;
    l_pdf_content   BLOB;
    l_doc_name      VARCHAR2(500);
    l_mime_type     VARCHAR2(100);
    l_file_size     NUMBER;
BEGIN
    -- Get document ID from request
    l_document_id := TO_NUMBER(apex_application.g_x01);

    -- Validate user has access (add your authorization logic here)
    -- Example: Check if user has VIEW privilege
    /*
    IF NOT has_document_access(l_document_id, V('APP_USER'), 'VIEW') THEN
        HTP.P('Unauthorized');
        RETURN;
    END IF;
    */

    -- Get document metadata
    SELECT document_name, mime_type, file_size_bytes
    INTO l_doc_name, l_mime_type, l_file_size
    FROM pdf_documents
    WHERE document_id = l_document_id
    AND is_active = 'Y';

    -- Fetch PDF content from OCI
    l_pdf_content := pkg_oci_object_storage.get_pdf_content(
        p_document_id     => l_document_id,
        p_credential_name => 'OCI_CRED'
    );

    -- Set response headers
    -- IMPORTANT: Using 'inline' prevents download dialog
    OWA_UTIL.MIME_HEADER(l_mime_type, FALSE);
    HTP.P('Content-Length: ' || DBMS_LOB.GETLENGTH(l_pdf_content));
    HTP.P('Content-Disposition: inline; filename="' || l_doc_name || '"');
    HTP.P('Cache-Control: no-cache, no-store, must-revalidate');
    HTP.P('Pragma: no-cache');
    HTP.P('Expires: 0');
    -- Prevent embedding in iframes from other domains
    HTP.P('X-Frame-Options: SAMEORIGIN');
    -- Disable content type sniffing
    HTP.P('X-Content-Type-Options: nosniff');
    OWA_UTIL.HTTP_HEADER_CLOSE;

    -- Output PDF content
    WPG_DOCLOAD.DOWNLOAD_FILE(l_pdf_content);

    -- Stop APEX processing
    apex_application.stop_apex_engine;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        HTP.P('Document not found');
    WHEN OTHERS THEN
        HTP.P('Error: ' || SQLERRM);
END;
