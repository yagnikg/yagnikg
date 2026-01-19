-- ============================================================================
-- OCI Web Credentials Setup for Oracle APEX
-- ============================================================================
-- This script creates the necessary web credentials in APEX for
-- authenticating with OCI Object Storage using API Key authentication
-- ============================================================================

-- ============================================================================
-- Step 1: Create Web Credentials in APEX
-- ============================================================================
-- Run this as APEX administrator or in your APEX workspace

BEGIN
    -- Delete existing credential if exists
    BEGIN
        APEX_CREDENTIAL.DROP_CREDENTIAL(
            p_credential_static_id => 'OCI_CRED'
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- Create OCI API Key credential
    APEX_CREDENTIAL.CREATE_CREDENTIAL(
        p_credential_static_id => 'OCI_CRED',
        p_credential_name      => 'OCI Object Storage Credentials',
        p_credential_type      => APEX_CREDENTIAL.C_TYPE_OCI,
        p_tenant_id            => 'ocid1.tenancy.oc1..your-tenancy-ocid',
        p_user_id              => 'ocid1.user.oc1..your-user-ocid',
        p_fingerprint          => 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99',
        p_private_key          => '-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...your-private-key-content...
-----END RSA PRIVATE KEY-----'
    );

    COMMIT;
END;
/

-- ============================================================================
-- Step 2: Grant Access to Web Credentials (if using shared credentials)
-- ============================================================================

/*
BEGIN
    APEX_CREDENTIAL.GRANT_ACCESS(
        p_credential_static_id => 'OCI_CRED',
        p_grantee              => 'YOUR_APEX_WORKSPACE'
    );
END;
/
*/

-- ============================================================================
-- Alternative: Using Oracle Resource Principal (for OCI environments)
-- ============================================================================
-- If your APEX instance runs on OCI (OCI Autonomous Database), you can use
-- Resource Principal authentication which doesn't require API keys

/*
BEGIN
    APEX_CREDENTIAL.CREATE_CREDENTIAL(
        p_credential_static_id => 'OCI_RESOURCE_PRINCIPAL',
        p_credential_name      => 'OCI Resource Principal',
        p_credential_type      => APEX_CREDENTIAL.C_TYPE_OCI_NATIVE
    );
END;
/
*/

-- ============================================================================
-- Step 3: Test the Credentials
-- ============================================================================
-- Run this to verify the credentials work

DECLARE
    l_response CLOB;
    l_url      VARCHAR2(500) := 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/';
BEGIN
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url                  => l_url,
        p_http_method          => 'GET',
        p_credential_static_id => 'OCI_CRED'
    );

    DBMS_OUTPUT.PUT_LINE('Status: ' || APEX_WEB_SERVICE.G_STATUS_CODE);
    DBMS_OUTPUT.PUT_LINE('Response: ' || SUBSTR(l_response, 1, 500));
END;
/

-- ============================================================================
-- Notes:
-- ============================================================================
-- 1. Replace the OCID values with your actual OCI tenancy and user OCIDs
-- 2. Replace the fingerprint with your API key fingerprint
-- 3. Replace the private key content with your actual RSA private key
-- 4. Ensure proper network access from APEX to OCI Object Storage endpoints
-- 5. Configure appropriate IAM policies in OCI to allow the user to access
--    the Object Storage bucket
--
-- Required OCI IAM Policy:
-- Allow user <user-name> to manage objects in compartment <compartment-name>
-- where target.bucket.name = '<bucket-name>'
-- ============================================================================
