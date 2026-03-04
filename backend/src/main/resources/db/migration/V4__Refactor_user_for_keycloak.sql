-- V4: Refactor users table for Keycloak integration
-- Authentication and roles are now managed by Keycloak.
-- The users table stores only domain-specific profile data.

-- Step 1: Drop ALL foreign key constraints that reference users(id)
ALTER TABLE facilities DROP CONSTRAINT IF EXISTS fk_facilities_manager;
ALTER TABLE dispensing_requests DROP CONSTRAINT IF EXISTS dispensing_requests_user_id_fkey;
ALTER TABLE dispensing_records DROP CONSTRAINT IF EXISTS dispensing_records_user_id_fkey;
ALTER TABLE quota_limit_rules DROP CONSTRAINT IF EXISTS quota_limit_rules_applies_to_user_id_fkey;
ALTER TABLE ble_session_logs DROP CONSTRAINT IF EXISTS ble_session_logs_mobile_user_id_fkey;
ALTER TABLE mobile_proxy_permissions DROP CONSTRAINT IF EXISTS mobile_proxy_permissions_user_id_fkey;
ALTER TABLE mobile_proxy_permissions DROP CONSTRAINT IF EXISTS mobile_proxy_permissions_granted_by_user_id_fkey;

-- Step 2: Add new Keycloak columns
ALTER TABLE users ADD COLUMN keycloak_sub VARCHAR(255);
ALTER TABLE users ADD COLUMN keycloak_username VARCHAR(100);
ALTER TABLE users ADD COLUMN keycloak_email VARCHAR(100);

-- Step 3: Populate new columns from existing data
UPDATE users SET keycloak_sub = CAST(id AS VARCHAR), keycloak_username = username, keycloak_email = email;

-- Step 4: Make facility_id nullable (auto-provisioned users won't have facility yet)
ALTER TABLE users ALTER COLUMN facility_id DROP NOT NULL;

-- Step 5: Drop old auth columns
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
ALTER TABLE users DROP COLUMN IF EXISTS role;

-- Step 6: Drop the old user_role enum type (no longer needed)
DROP TYPE IF EXISTS user_role;

-- Step 7: Drop old PK and username/email columns, replace with keycloak_sub PK
ALTER TABLE users DROP CONSTRAINT users_pkey;
ALTER TABLE users DROP COLUMN id;
ALTER TABLE users DROP COLUMN username;
ALTER TABLE users DROP COLUMN email;

-- Step 8: Set keycloak_sub as new PK
ALTER TABLE users ADD PRIMARY KEY (keycloak_sub);
ALTER TABLE users ALTER COLUMN keycloak_sub SET NOT NULL;
ALTER TABLE users ALTER COLUMN keycloak_username SET NOT NULL;
ALTER TABLE users ALTER COLUMN keycloak_email SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT uk_users_keycloak_username UNIQUE (keycloak_username);
ALTER TABLE users ADD CONSTRAINT uk_users_keycloak_email UNIQUE (keycloak_email);

-- Step 9: Convert user_id columns in other tables from UUID to VARCHAR
-- and populate with keycloak_sub values (which were copied from old UUID id)
ALTER TABLE dispensing_requests ALTER COLUMN user_id TYPE VARCHAR(255);
ALTER TABLE dispensing_records ALTER COLUMN user_id TYPE VARCHAR(255);
ALTER TABLE quota_limit_rules ALTER COLUMN applies_to_user_id TYPE VARCHAR(255);
ALTER TABLE ble_session_logs ALTER COLUMN mobile_user_id TYPE VARCHAR(255);
ALTER TABLE mobile_proxy_permissions ALTER COLUMN user_id TYPE VARCHAR(255);
ALTER TABLE mobile_proxy_permissions ALTER COLUMN granted_by_user_id TYPE VARCHAR(255);

-- Step 10: Re-create all foreign keys referencing users(keycloak_sub)
ALTER TABLE dispensing_requests ADD CONSTRAINT fk_dispensing_requests_user
    FOREIGN KEY (user_id) REFERENCES users(keycloak_sub);
ALTER TABLE dispensing_records ADD CONSTRAINT fk_dispensing_records_user
    FOREIGN KEY (user_id) REFERENCES users(keycloak_sub);
ALTER TABLE quota_limit_rules ADD CONSTRAINT fk_quota_rules_user
    FOREIGN KEY (applies_to_user_id) REFERENCES users(keycloak_sub);
ALTER TABLE ble_session_logs ADD CONSTRAINT fk_ble_sessions_user
    FOREIGN KEY (mobile_user_id) REFERENCES users(keycloak_sub);
ALTER TABLE mobile_proxy_permissions ADD CONSTRAINT fk_proxy_permissions_user
    FOREIGN KEY (user_id) REFERENCES users(keycloak_sub);
ALTER TABLE mobile_proxy_permissions ADD CONSTRAINT fk_proxy_permissions_granted_by
    FOREIGN KEY (granted_by_user_id) REFERENCES users(keycloak_sub);

-- Step 11: Re-add facility manager FK with VARCHAR type
ALTER TABLE facilities ALTER COLUMN manager_user_id TYPE VARCHAR(255);
ALTER TABLE facilities ADD CONSTRAINT fk_facilities_manager
    FOREIGN KEY (manager_user_id) REFERENCES users(keycloak_sub);

-- Step 12: Update indexes
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_users_username;
CREATE INDEX idx_users_keycloak_username ON users(keycloak_username);
