package com.olimeeter.fuel.models;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "quota_limit_rules")
public class QuotaLimitRule {

    public enum RuleType {
        user_specific, role_based, daily, monthly, custom
    }

    public enum TimePeriod {
        daily, monthly
    }

    public enum EnforcementAction {
        reject, warn
    }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "facility_id", nullable = false)
    private UUID facilityId;

    @Enumerated(EnumType.STRING)
    @Column(name = "rule_type", nullable = false, columnDefinition = "quota_rule_type")
    private RuleType ruleType;

    @Column(name = "applies_to_user_id")
    private String appliesToUserId;

    @Column(name = "applies_to_role", length = 50)
    private String appliesToRole;

    @Enumerated(EnumType.STRING)
    @Column(name = "time_period", columnDefinition = "time_period")
    private TimePeriod timePeriod;

    @Column(name = "max_liters", nullable = false, precision = 10, scale = 2)
    private BigDecimal maxLiters;

    @Enumerated(EnumType.STRING)
    @Column(name = "enforcement_action", nullable = false, columnDefinition = "enforcement_action")
    private EnforcementAction enforcementAction = EnforcementAction.reject;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "custom_condition_json", columnDefinition = "jsonb")
    private Map<String, Object> customConditionJson;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private int priority = 0;

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

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getFacilityId() { return facilityId; }
    public void setFacilityId(UUID facilityId) { this.facilityId = facilityId; }

    public RuleType getRuleType() { return ruleType; }
    public void setRuleType(RuleType ruleType) { this.ruleType = ruleType; }

    public String getAppliesToUserId() { return appliesToUserId; }
    public void setAppliesToUserId(String appliesToUserId) { this.appliesToUserId = appliesToUserId; }

    public String getAppliesToRole() { return appliesToRole; }
    public void setAppliesToRole(String appliesToRole) { this.appliesToRole = appliesToRole; }

    public TimePeriod getTimePeriod() { return timePeriod; }
    public void setTimePeriod(TimePeriod timePeriod) { this.timePeriod = timePeriod; }

    public BigDecimal getMaxLiters() { return maxLiters; }
    public void setMaxLiters(BigDecimal maxLiters) { this.maxLiters = maxLiters; }

    public EnforcementAction getEnforcementAction() { return enforcementAction; }
    public void setEnforcementAction(EnforcementAction enforcementAction) { this.enforcementAction = enforcementAction; }

    public Map<String, Object> getCustomConditionJson() { return customConditionJson; }
    public void setCustomConditionJson(Map<String, Object> customConditionJson) { this.customConditionJson = customConditionJson; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public int getPriority() { return priority; }
    public void setPriority(int priority) { this.priority = priority; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
