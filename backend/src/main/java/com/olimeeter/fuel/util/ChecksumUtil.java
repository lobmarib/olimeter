package com.olimeeter.fuel.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class ChecksumUtil {

    private ChecksumUtil() {}

    /**
     * Compute SHA-256 hex digest of the given payload string.
     */
    public static String sha256(String payload) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(payload.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    /**
     * Validate that the provided checksum matches the SHA-256 of the payload.
     */
    public static boolean validate(String payload, String expectedChecksum) {
        if (payload == null || expectedChecksum == null) {
            return false;
        }
        String actual = sha256(payload);
        return actual.equalsIgnoreCase(expectedChecksum);
    }
}
