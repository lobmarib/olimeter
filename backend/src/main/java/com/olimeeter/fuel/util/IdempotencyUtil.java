package com.olimeeter.fuel.util;

import java.util.UUID;

public final class IdempotencyUtil {

    private IdempotencyUtil() {}

    /**
     * Parse and validate an idempotency key string as UUID.
     * Returns null if the key is null or not a valid UUID.
     */
    public static UUID parse(String idempotencyKey) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return null;
        }
        try {
            return UUID.fromString(idempotencyKey);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /**
     * Generate a new random idempotency key.
     */
    public static UUID generate() {
        return UUID.randomUUID();
    }
}
