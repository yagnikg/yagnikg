CREATE OR REPLACE PACKAGE pkg_oci_object_storage AS
    /*
    ============================================================================
    Package: pkg_oci_object_storage
    Description: OCI Object Storage integration for PDF document management

    This package provides functionality to:
    - Upload PDF files to OCI Object Storage
    - Generate Pre-Authenticated Requests (PARs) for secure access
    - Fetch PDF content for viewing
    - Manage document metadata

    Author: Oracle APEX PDF Viewer Solution
    ============================================================================
    */

    -- Constants
    gc_default_par_duration CONSTANT NUMBER := 5;  -- PAR validity in minutes
    gc_content_type_pdf     CONSTANT VARCHAR2(50) := 'application/pdf';

    -- Types
    TYPE t_par_response IS RECORD (
        par_url         VARCHAR2(4000),
        par_id          VARCHAR2(256),
        time_created    TIMESTAMP,
        time_expires    TIMESTAMP,
        access_type     VARCHAR2(50)
    );

    -- ========================================================================
    -- Procedure: upload_pdf_to_oci
    -- Description: Uploads a PDF file to OCI Object Storage
    -- ========================================================================
    PROCEDURE upload_pdf_to_oci (
        p_file_content      IN BLOB,
        p_file_name         IN VARCHAR2,
        p_bucket_name       IN VARCHAR2,
        p_credential_name   IN VARCHAR2 DEFAULT 'OCI_CRED',
        p_document_title    IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL,
        p_document_id       OUT NUMBER,
        p_status            OUT VARCHAR2,
        p_message           OUT VARCHAR2
    );

    -- ========================================================================
    -- Function: get_par_for_viewing
    -- Description: Generates a Pre-Authenticated Request URL for viewing
    --              PAR is time-limited and read-only
    -- ========================================================================
    FUNCTION get_par_for_viewing (
        p_document_id       IN NUMBER,
        p_credential_name   IN VARCHAR2 DEFAULT 'OCI_CRED',
        p_duration_minutes  IN NUMBER DEFAULT 5
    ) RETURN VARCHAR2;

    -- ========================================================================
    -- Function: get_pdf_content
    -- Description: Fetches PDF content directly from OCI Object Storage
    --              Returns as BLOB for inline viewing
    -- ========================================================================
    FUNCTION get_pdf_content (
        p_document_id       IN NUMBER,
        p_credential_name   IN VARCHAR2 DEFAULT 'OCI_CRED'
    ) RETURN BLOB;

    -- ========================================================================
    -- Procedure: log_document_access
    -- Description: Logs document access for audit trail
    -- ========================================================================
    PROCEDURE log_document_access (
        p_document_id       IN NUMBER,
        p_access_type       IN VARCHAR2,
        p_user_name         IN VARCHAR2 DEFAULT NULL,
        p_ip_address        IN VARCHAR2 DEFAULT NULL,
        p_user_agent        IN VARCHAR2 DEFAULT NULL
    );

    -- ========================================================================
    -- Function: get_document_list
    -- Description: Returns list of active documents for the viewer
    -- ========================================================================
    FUNCTION get_document_list RETURN SYS_REFCURSOR;

    -- ========================================================================
    -- Procedure: delete_document
    -- Description: Soft deletes a document (sets is_active to 'N')
    -- ========================================================================
    PROCEDURE delete_document (
        p_document_id       IN NUMBER,
        p_hard_delete       IN BOOLEAN DEFAULT FALSE
    );

    -- ========================================================================
    -- Function: get_oci_region_endpoint
    -- Description: Returns the Object Storage endpoint for a region
    -- ========================================================================
    FUNCTION get_oci_region_endpoint (
        p_region            IN VARCHAR2
    ) RETURN VARCHAR2;

END pkg_oci_object_storage;
/
