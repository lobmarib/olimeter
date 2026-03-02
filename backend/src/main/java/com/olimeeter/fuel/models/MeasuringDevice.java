package com.olimeeter.fuel.models;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "measuring_devices",
       uniqueConstraints = @UniqueConstraint(columnNames = {"device_name", "facility_id"}))
public class MeasuringDevice {

    public enum ConnectivityStatus {
        online_wifi, online_ble, offline, unknown
    }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "device_name", nullable = false, length = 100)
    private String deviceName;

    @Column(name = "facility_id", nullable = false)
    private UUID facilityId;

    @Column(name = "device_model", length = 50)
    private String deviceModel;

    @Column(name = "firmware_version", length = 20)
    private String firmwareVersion;

    @Column(name = "mac_address", unique = true, length = 17)
    private String macAddress;

    @Column(name = "ble_uuid", unique = true, length = 36)
    private String bleUuid;

    @Column(name = "tank_capacity_liters", nullable = false, precision = 10, scale = 2)
    private BigDecimal tankCapacityLiters;

    @Column(name = "current_queue_depth", nullable = false)
    private int currentQueueDepth = 0;

    @Column(name = "last_communication_at")
    private Instant lastCommunicationAt;

    @Column(name = "last_wifi_connection_at")
    private Instant lastWifiConnectionAt;

    @Column(name = "last_ble_contact_at")
    private Instant lastBleContactAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "connectivity_status", nullable = false, columnDefinition = "connectivity_status")
    private ConnectivityStatus connectivityStatus = ConnectivityStatus.unknown;

    @Column(name = "battery_percent")
    private Integer batteryPercent;

    @Column(name = "signal_strength_dbm")
    private Integer signalStrengthDbm;

    @Column(name = "is_paused", nullable = false)
    private boolean paused = false;

    @Column(name = "location_lat", precision = 10, scale = 8)
    private BigDecimal locationLat;

    @Column(name = "location_lng", precision = 11, scale = 8)
    private BigDecimal locationLng;

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

    public String getDeviceName() { return deviceName; }
    public void setDeviceName(String deviceName) { this.deviceName = deviceName; }

    public UUID getFacilityId() { return facilityId; }
    public void setFacilityId(UUID facilityId) { this.facilityId = facilityId; }

    public String getDeviceModel() { return deviceModel; }
    public void setDeviceModel(String deviceModel) { this.deviceModel = deviceModel; }

    public String getFirmwareVersion() { return firmwareVersion; }
    public void setFirmwareVersion(String firmwareVersion) { this.firmwareVersion = firmwareVersion; }

    public String getMacAddress() { return macAddress; }
    public void setMacAddress(String macAddress) { this.macAddress = macAddress; }

    public String getBleUuid() { return bleUuid; }
    public void setBleUuid(String bleUuid) { this.bleUuid = bleUuid; }

    public BigDecimal getTankCapacityLiters() { return tankCapacityLiters; }
    public void setTankCapacityLiters(BigDecimal tankCapacityLiters) { this.tankCapacityLiters = tankCapacityLiters; }

    public int getCurrentQueueDepth() { return currentQueueDepth; }
    public void setCurrentQueueDepth(int currentQueueDepth) { this.currentQueueDepth = currentQueueDepth; }

    public Instant getLastCommunicationAt() { return lastCommunicationAt; }
    public void setLastCommunicationAt(Instant lastCommunicationAt) { this.lastCommunicationAt = lastCommunicationAt; }

    public Instant getLastWifiConnectionAt() { return lastWifiConnectionAt; }
    public void setLastWifiConnectionAt(Instant lastWifiConnectionAt) { this.lastWifiConnectionAt = lastWifiConnectionAt; }

    public Instant getLastBleContactAt() { return lastBleContactAt; }
    public void setLastBleContactAt(Instant lastBleContactAt) { this.lastBleContactAt = lastBleContactAt; }

    public ConnectivityStatus getConnectivityStatus() { return connectivityStatus; }
    public void setConnectivityStatus(ConnectivityStatus connectivityStatus) { this.connectivityStatus = connectivityStatus; }

    public Integer getBatteryPercent() { return batteryPercent; }
    public void setBatteryPercent(Integer batteryPercent) { this.batteryPercent = batteryPercent; }

    public Integer getSignalStrengthDbm() { return signalStrengthDbm; }
    public void setSignalStrengthDbm(Integer signalStrengthDbm) { this.signalStrengthDbm = signalStrengthDbm; }

    public boolean isPaused() { return paused; }
    public void setPaused(boolean paused) { this.paused = paused; }

    public BigDecimal getLocationLat() { return locationLat; }
    public void setLocationLat(BigDecimal locationLat) { this.locationLat = locationLat; }

    public BigDecimal getLocationLng() { return locationLng; }
    public void setLocationLng(BigDecimal locationLng) { this.locationLng = locationLng; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
