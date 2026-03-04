package com.olimeeter.fuel.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Authenticates ESP32 devices via X-Device-Key header.
 * Only applies to device-specific endpoints (measurements, relay control).
 * Keycloak is NOT used for device auth.
 */
@Component
public class DeviceApiKeyFilter extends OncePerRequestFilter {

    private static final String DEVICE_KEY_HEADER = "X-Device-Key";
    private static final String DEVICE_ID_HEADER = "Device-ID";

    @Value("${app.device-api-key}")
    private String expectedApiKey;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = request.getRequestURI();

        if (isDeviceEndpoint(path)) {
            String apiKey = request.getHeader(DEVICE_KEY_HEADER);
            String deviceId = request.getHeader(DEVICE_ID_HEADER);

            if (apiKey != null && apiKey.equals(expectedApiKey) && deviceId != null) {
                var authorities = List.of(new SimpleGrantedAuthority("ROLE_DEVICE"));
                var authentication = new UsernamePasswordAuthenticationToken(
                        "device:" + deviceId, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
            // If no valid device key, fall through — permitAll endpoints won't need auth,
            // but the controller can check for the DEVICE role
        }

        filterChain.doFilter(request, response);
    }

    private boolean isDeviceEndpoint(String path) {
        return path.startsWith("/api/v1/measurements")
                || (path.startsWith("/api/v1/devices/") && path.contains("/relay/"));
    }
}
