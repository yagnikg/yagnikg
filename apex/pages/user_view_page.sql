-- ============================================================================
-- APEX Page: PDF Viewer (Page 20)
-- ============================================================================
-- This page displays PDFs to end users with download restrictions
-- ============================================================================

-- Page Items Required:
-- P20_DOCUMENT_ID   - Hidden Item (passed from document list)
-- P20_PDF_URL       - Hidden Item (computed - holds the PDF URL)

-- ============================================================================
-- Before Header Process: Set PDF URL
-- ============================================================================
-- Process Name: Set_PDF_URL
-- Type: PL/SQL Code
-- Point: Before Header
-- ============================================================================

DECLARE
    l_pdf_url VARCHAR2(4000);
BEGIN
    -- Validate document exists and user has access
    IF :P20_DOCUMENT_ID IS NULL THEN
        apex_util.redirect_url(
            'f?p=' || :APP_ID || ':1:' || :APP_SESSION
        );
        RETURN;
    END IF;

    -- Build URL for the APEX process that serves the PDF
    -- Using APEX callback URL pattern
    l_pdf_url := APEX_PAGE.GET_URL(
        p_application => :APP_ID,
        p_page        => :APP_PAGE_ID,
        p_session     => :APP_SESSION,
        p_request     => 'APPLICATION_PROCESS=SERVE_PDF'
    );

    -- Alternative: Use RESTful service URL if configured
    -- l_pdf_url := :G_REST_BASE_URL || '/pdf/' || :P20_DOCUMENT_ID;

    :P20_PDF_URL := l_pdf_url;
END;

-- ============================================================================
-- Page HTML Header (Include PDF.js and Custom Scripts)
-- ============================================================================
-- Page Properties > HTML Header:
-- ============================================================================

/*
<!-- PDF.js Library -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>

<!-- Custom Secure PDF Viewer -->
<link rel="stylesheet" href="#APP_FILES#css/secure-pdf-viewer.css">
<script src="#APP_FILES#js/secure-pdf-viewer.js"></script>
*/

-- ============================================================================
-- Static Content Region: PDF Viewer Container
-- ============================================================================
-- Region Name: PDF Viewer
-- Type: Static Content
-- Source HTML:
-- ============================================================================

/*
<div id="pdf-viewer-container" style="height: 800px;"></div>
*/

-- ============================================================================
-- Page Load Dynamic Action: Initialize PDF Viewer
-- ============================================================================
-- Name: Initialize_PDF_Viewer
-- Event: Page Load
-- True Action: Execute JavaScript Code
-- ============================================================================

/*
// Get the document ID and initialize viewer
var documentId = apex.item('P20_DOCUMENT_ID').getValue();

if (documentId) {
    SecurePDFViewer.init({
        containerId: 'pdf-viewer-container',
        // Build URL for APEX process call
        pdfUrl: apex.server.url({
            process: 'SERVE_PDF',
            x01: documentId
        }),
        scale: 1.0
    });
} else {
    document.getElementById('pdf-viewer-container').innerHTML =
        '<div class="pdf-error"><p>No document selected.</p></div>';
}
*/

-- ============================================================================
-- Alternative: Using Application Process URL
-- ============================================================================
-- If you prefer using a RESTful endpoint, use this JavaScript instead:
-- ============================================================================

/*
var documentId = apex.item('P20_DOCUMENT_ID').getValue();

if (documentId) {
    // Using the application process
    var pdfUrl = 'f?p=' + $v('pFlowId') + ':0:' + $v('pInstance') +
                 ':APPLICATION_PROCESS=SERVE_PDF:::X01:' + documentId;

    SecurePDFViewer.init({
        containerId: 'pdf-viewer-container',
        pdfUrl: pdfUrl,
        scale: 1.0
    });
}
*/

-- ============================================================================
-- Page CSS (Inline)
-- ============================================================================
-- Page Properties > CSS > Inline:
-- ============================================================================

/*
#pdf-viewer-container {
    width: 100%;
    height: calc(100vh - 200px);
    min-height: 600px;
}

.pdf-header-info {
    padding: 15px;
    background: #f5f5f5;
    border-radius: 4px;
    margin-bottom: 15px;
}

.pdf-header-info h2 {
    margin: 0 0 10px 0;
    color: #333;
}

.pdf-header-info p {
    margin: 0;
    color: #666;
}
*/

-- ============================================================================
-- Document Info Region (Optional)
-- ============================================================================
-- Region Name: Document Info
-- Type: Classic Report
-- Source SQL:
-- ============================================================================

SELECT
    document_title AS "Document Title",
    description AS "Description",
    uploaded_by AS "Uploaded By",
    TO_CHAR(uploaded_date, 'DD-MON-YYYY HH24:MI') AS "Upload Date",
    view_count AS "View Count"
FROM pdf_documents
WHERE document_id = :P20_DOCUMENT_ID
AND is_active = 'Y';

-- ============================================================================
-- Security: Authorization Scheme
-- ============================================================================
-- Create an authorization scheme to control access:
-- Name: Can_View_Documents
-- Scheme Type: PL/SQL Function Returning Boolean
-- ============================================================================

/*
RETURN pkg_oci_object_storage.can_user_view_document(
    p_document_id => :P20_DOCUMENT_ID,
    p_user_name   => :APP_USER
);
*/

-- ============================================================================
-- Logging: After Page Load Process
-- ============================================================================
-- Process Name: Log_Document_View
-- Type: PL/SQL Code
-- Point: After Header
-- ============================================================================

BEGIN
    IF :P20_DOCUMENT_ID IS NOT NULL THEN
        pkg_oci_object_storage.log_document_access(
            p_document_id => :P20_DOCUMENT_ID,
            p_access_type => 'VIEW',
            p_user_name   => :APP_USER,
            p_ip_address  => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR'),
            p_user_agent  => OWA_UTIL.GET_CGI_ENV('HTTP_USER_AGENT')
        );
    END IF;
END;
