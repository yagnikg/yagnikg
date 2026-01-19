CREATE OR REPLACE PACKAGE BODY pkg_oci_object_storage AS
    /*
    ============================================================================
    Package Body: pkg_oci_object_storage
    ============================================================================
    */

    -- Private function to get credential details
    FUNCTION get_credential_details (
        p_credential_name IN VARCHAR2
    ) RETURN oci_credentials%ROWTYPE IS
        l_cred oci_credentials%ROWTYPE;
    BEGIN
        SELECT *
        INTO l_cred
        FROM oci_credentials
        WHERE credential_name = p_credential_name
        AND is_active = 'Y';

        RETURN l_cred;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'OCI Credential not found: ' || p_credential_name);
    END get_credential_details;

    -- ========================================================================
    FUNCTION get_oci_region_endpoint (
        p_region IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        -- Return Object Storage endpoint for the region
        RETURN 'https://objectstorage.' || LOWER(p_region) || '.oraclecloud.com';
    END get_oci_region_endpoint;

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
    ) IS
        l_cred              oci_credentials%ROWTYPE;
        l_endpoint          VARCHAR2(500);
        l_url               VARCHAR2(4000);
        l_response          CLOB;
        l_object_name       VARCHAR2(1000);
        l_namespace         VARCHAR2(256);
    BEGIN
        -- Get credentials
        l_cred := get_credential_details(p_credential_name);

        -- Build object name with timestamp for uniqueness
        l_object_name := 'documents/' ||
                        TO_CHAR(SYSTIMESTAMP, 'YYYY/MM/DD') || '/' ||
                        TO_CHAR(SYSTIMESTAMP, 'HH24MISS_') ||
                        p_file_name;

        l_namespace := l_cred.compartment_ocid; -- Or get from tenancy

        -- Build URL
        l_endpoint := get_oci_region_endpoint(l_cred.region);
        l_url := l_endpoint || '/n/' || l_namespace ||
                 '/b/' || p_bucket_name ||
                 '/o/' || UTL_URL.ESCAPE(l_object_name, TRUE);

        -- Use APEX_WEB_SERVICE to upload
        -- Note: This requires OCI Web Credentials to be set up in APEX
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := gc_content_type_pdf;

        l_response := apex_web_service.make_rest_request(
            p_url               => l_url,
            p_http_method       => 'PUT',
            p_body_blob         => p_file_content,
            p_credential_static_id => p_credential_name
        );

        -- Check response
        IF apex_web_service.g_status_code = 200 THEN
            -- Insert document metadata
            INSERT INTO pdf_documents (
                document_name,
                document_title,
                description,
                oci_object_name,
                oci_bucket_name,
                oci_namespace,
                file_size_bytes,
                uploaded_by,
                created_by
            ) VALUES (
                p_file_name,
                NVL(p_document_title, p_file_name),
                p_description,
                l_object_name,
                p_bucket_name,
                l_namespace,
                DBMS_LOB.GETLENGTH(p_file_content),
                NVL(V('APP_USER'), USER),
                NVL(V('APP_USER'), USER)
            ) RETURNING document_id INTO p_document_id;

            p_status := 'SUCCESS';
            p_message := 'Document uploaded successfully';
        ELSE
            p_status := 'ERROR';
            p_message := 'Upload failed with status: ' || apex_web_service.g_status_code;
            p_document_id := NULL;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Error uploading document: ' || SQLERRM;
            p_document_id := NULL;
    END upload_pdf_to_oci;

    -- ========================================================================
    FUNCTION get_par_for_viewing (
        p_document_id       IN NUMBER,
        p_credential_name   IN VARCHAR2 DEFAULT 'OCI_CRED',
        p_duration_minutes  IN NUMBER DEFAULT 5
    ) RETURN VARCHAR2 IS
        l_cred              oci_credentials%ROWTYPE;
        l_doc               pdf_documents%ROWTYPE;
        l_endpoint          VARCHAR2(500);
        l_url               VARCHAR2(4000);
        l_request_body      CLOB;
        l_response          CLOB;
        l_par_url           VARCHAR2(4000);
        l_expiry_time       TIMESTAMP;
    BEGIN
        -- Get document details
        SELECT *
        INTO l_doc
        FROM pdf_documents
        WHERE document_id = p_document_id
        AND is_active = 'Y';

        -- Get credentials
        l_cred := get_credential_details(p_credential_name);

        -- Calculate expiry time
        l_expiry_time := SYSTIMESTAMP + NUMTODSINTERVAL(p_duration_minutes, 'MINUTE');

        -- Build PAR request URL
        l_endpoint := get_oci_region_endpoint(l_cred.region);
        l_url := l_endpoint || '/n/' || l_doc.oci_namespace ||
                 '/b/' || l_doc.oci_bucket_name || '/p/';

        -- Build request body for PAR creation
        l_request_body := '{
            "accessType": "ObjectRead",
            "name": "PAR_' || p_document_id || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS') || '",
            "objectName": "' || l_doc.oci_object_name || '",
            "timeExpires": "' || TO_CHAR(l_expiry_time, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '"
        }';

        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url               => l_url,
            p_http_method       => 'POST',
            p_body              => l_request_body,
            p_credential_static_id => p_credential_name
        );

        IF apex_web_service.g_status_code = 200 THEN
            -- Parse response to get PAR URL
            l_par_url := JSON_VALUE(l_response, '$.accessUri');

            -- Log access
            log_document_access(
                p_document_id   => p_document_id,
                p_access_type   => 'VIEW',
                p_user_name     => V('APP_USER'),
                p_ip_address    => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR'),
                p_user_agent    => OWA_UTIL.GET_CGI_ENV('HTTP_USER_AGENT')
            );

            RETURN l_endpoint || l_par_url;
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Failed to create PAR: ' || l_response);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Document not found or inactive: ' || p_document_id);
    END get_par_for_viewing;

    -- ========================================================================
    FUNCTION get_pdf_content (
        p_document_id       IN NUMBER,
        p_credential_name   IN VARCHAR2 DEFAULT 'OCI_CRED'
    ) RETURN BLOB IS
        l_cred              oci_credentials%ROWTYPE;
        l_doc               pdf_documents%ROWTYPE;
        l_endpoint          VARCHAR2(500);
        l_url               VARCHAR2(4000);
        l_response          BLOB;
    BEGIN
        -- Get document details
        SELECT *
        INTO l_doc
        FROM pdf_documents
        WHERE document_id = p_document_id
        AND is_active = 'Y';

        -- Get credentials
        l_cred := get_credential_details(p_credential_name);

        -- Build URL
        l_endpoint := get_oci_region_endpoint(l_cred.region);
        l_url := l_endpoint || '/n/' || l_doc.oci_namespace ||
                 '/b/' || l_doc.oci_bucket_name ||
                 '/o/' || UTL_URL.ESCAPE(l_doc.oci_object_name, TRUE);

        -- Fetch the PDF
        l_response := apex_web_service.make_rest_request_b(
            p_url               => l_url,
            p_http_method       => 'GET',
            p_credential_static_id => p_credential_name
        );

        IF apex_web_service.g_status_code = 200 THEN
            -- Log access
            log_document_access(
                p_document_id   => p_document_id,
                p_access_type   => 'VIEW',
                p_user_name     => V('APP_USER'),
                p_ip_address    => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR'),
                p_user_agent    => OWA_UTIL.GET_CGI_ENV('HTTP_USER_AGENT')
            );

            -- Update view count
            UPDATE pdf_documents
            SET view_count = view_count + 1,
                last_viewed_date = SYSTIMESTAMP
            WHERE document_id = p_document_id;

            RETURN l_response;
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Failed to fetch PDF: Status ' || apex_web_service.g_status_code);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Document not found or inactive: ' || p_document_id);
    END get_pdf_content;

    -- ========================================================================
    PROCEDURE log_document_access (
        p_document_id       IN NUMBER,
        p_access_type       IN VARCHAR2,
        p_user_name         IN VARCHAR2 DEFAULT NULL,
        p_ip_address        IN VARCHAR2 DEFAULT NULL,
        p_user_agent        IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO pdf_document_access_log (
            document_id,
            user_name,
            access_type,
            ip_address,
            user_agent,
            session_id
        ) VALUES (
            p_document_id,
            NVL(p_user_name, V('APP_USER')),
            p_access_type,
            p_ip_address,
            p_user_agent,
            V('APP_SESSION')
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_document_access;

    -- ========================================================================
    FUNCTION get_document_list RETURN SYS_REFCURSOR IS
        l_cursor SYS_REFCURSOR;
    BEGIN
        OPEN l_cursor FOR
            SELECT
                document_id,
                document_name,
                document_title,
                description,
                file_size_bytes,
                uploaded_by,
                uploaded_date,
                view_count,
                last_viewed_date
            FROM pdf_documents
            WHERE is_active = 'Y'
            ORDER BY uploaded_date DESC;

        RETURN l_cursor;
    END get_document_list;

    -- ========================================================================
    PROCEDURE delete_document (
        p_document_id       IN NUMBER,
        p_hard_delete       IN BOOLEAN DEFAULT FALSE
    ) IS
    BEGIN
        IF p_hard_delete THEN
            -- Hard delete - remove from database
            DELETE FROM pdf_document_access_log WHERE document_id = p_document_id;
            DELETE FROM pdf_documents WHERE document_id = p_document_id;
        ELSE
            -- Soft delete - mark as inactive
            UPDATE pdf_documents
            SET is_active = 'N',
                updated_by = NVL(V('APP_USER'), USER),
                updated_date = SYSTIMESTAMP
            WHERE document_id = p_document_id;
        END IF;
    END delete_document;

END pkg_oci_object_storage;
/
