package com.olimeeter.fuel.models;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Domain-specific user profile linked to Keycloak identity.
 * <p>
 * Authentication and role management are handled entirely by Keycloak.
 * This entity stores only domain-specific fields (facility, quota config).
 * Roles are read from JWT realm_access.roles claim per request — no role column here.
 * <p>
 * Auto-provisioned on first authenticated API call via UserProvisioningService.
 */
@Entity
@Table(name = "users")
public class User {

    /** Keycloak user ID (sub claim from JWT) — primary key */
    @Id
    @Column(name = "keycloak_sub", nullable = false, length = 255)
    private String keycloakSub;

    /** Username from Keycloak (preferred_username claim) */
    @Column(name = "keycloak_username", nullable = false, unique = true, length = 100)
    private String keycloakUsername;

    /** Email from Keycloak (email claim) */
    @Column(name = "keycloak_email", nullable = false, unique = true, length = 100)
    private String keycloakEmail;

    @Column(name = "full_name", length = 200)
    private String fullName;

    /** Facility assignment — nullable until admin completes profile */
    @Column(name = "facility_id")
    private UUID facilityId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "quota_config_json", columnDefinition = "jsonb")
    private Map<String, Object> quotaConfigJson;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "last_login")
    private Instant lastLogin;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // Getters and setters

    public String getKeycloakSub() { return keycloakSub; }
    public void setKeycloakSub(String keycloakSub) { this.keycloakSub = keycloakSub; }

    public String getKeycloakUsername() { return keycloakUsername; }
    public void setKeycloakUsername(String keycloakUsername) { this.keycloakUsername = keycloakUsername; }

    public String getKeycloakEmail() { return keycloakEmail; }
    public void setKeycloakEmail(String keycloakEmail) { this.keycloakEmail = keycloakEmail; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public UUID getFacilityId() { return facilityId; }
    public void setFacilityId(UUID facilityId) { this.facilityId = facilityId; }

    public Map<String, Object> getQuotaConfigJson() { return quotaConfigJson; }
    public void setQuotaConfigJson(Map<String, Object> quotaConfigJson) { this.quotaConfigJson = quotaConfigJson; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public Instant getLastLogin() { return lastLogin; }
    public void setLastLogin(Instant lastLogin) { this.lastLogin = lastLogin; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
