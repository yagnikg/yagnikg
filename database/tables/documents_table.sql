-- ============================================================================
-- Document Management Tables for OCI Object Storage PDF Viewer
-- ============================================================================

-- Table to store document metadata
CREATE TABLE pdf_documents (
    document_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_name       VARCHAR2(500) NOT NULL,
    document_title      VARCHAR2(500),
    description         CLOB,
    oci_object_name     VARCHAR2(1000) NOT NULL,  -- Object name in OCI bucket
    oci_bucket_name     VARCHAR2(256) NOT NULL,
    oci_namespace       VARCHAR2(256) NOT NULL,
    file_size_bytes     NUMBER,
    mime_type           VARCHAR2(100) DEFAULT 'application/pdf',
    uploaded_by         VARCHAR2(256),
    uploaded_date       TIMESTAMP DEFAULT SYSTIMESTAMP,
    is_active           VARCHAR2(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
    view_count          NUMBER DEFAULT 0,
    last_viewed_date    TIMESTAMP,
    created_by          VARCHAR2(256),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_by          VARCHAR2(256),
    updated_date        TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX idx_pdf_docs_active ON pdf_documents(is_active);
CREATE INDEX idx_pdf_docs_uploaded ON pdf_documents(uploaded_date DESC);
CREATE INDEX idx_pdf_docs_bucket ON pdf_documents(oci_bucket_name, oci_object_name);

-- Table to store OCI credentials (encrypted)
CREATE TABLE oci_credentials (
    credential_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    credential_name     VARCHAR2(256) NOT NULL UNIQUE,
    tenancy_ocid        VARCHAR2(500) NOT NULL,
    user_ocid           VARCHAR2(500) NOT NULL,
    fingerprint         VARCHAR2(100) NOT NULL,
    private_key         CLOB NOT NULL,  -- Store encrypted
    region              VARCHAR2(50) NOT NULL,
    compartment_ocid    VARCHAR2(500),
    is_active           VARCHAR2(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
    created_by          VARCHAR2(256),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_by          VARCHAR2(256),
    updated_date        TIMESTAMP
);

-- Table to track document access logs
CREATE TABLE pdf_document_access_log (
    log_id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id         NUMBER NOT NULL REFERENCES pdf_documents(document_id),
    user_name           VARCHAR2(256),
    access_type         VARCHAR2(50),  -- 'VIEW', 'DOWNLOAD_ATTEMPT'
    ip_address          VARCHAR2(50),
    user_agent          VARCHAR2(1000),
    access_date         TIMESTAMP DEFAULT SYSTIMESTAMP,
    session_id          VARCHAR2(256)
);

CREATE INDEX idx_access_log_doc ON pdf_document_access_log(document_id);
CREATE INDEX idx_access_log_date ON pdf_document_access_log(access_date DESC);

-- Comments
COMMENT ON TABLE pdf_documents IS 'Stores metadata for PDF documents stored in OCI Object Storage';
COMMENT ON TABLE oci_credentials IS 'Stores OCI API credentials for Object Storage access';
COMMENT ON TABLE pdf_document_access_log IS 'Audit log for document access tracking';

COMMENT ON COLUMN pdf_documents.oci_object_name IS 'The object name/path in OCI Object Storage bucket';
COMMENT ON COLUMN pdf_documents.oci_bucket_name IS 'OCI Object Storage bucket name';
COMMENT ON COLUMN pdf_documents.oci_namespace IS 'OCI tenancy namespace';
