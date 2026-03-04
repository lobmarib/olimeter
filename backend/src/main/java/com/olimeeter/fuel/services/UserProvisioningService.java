package com.olimeeter.fuel.services;

import com.olimeeter.fuel.models.User;
import com.olimeeter.fuel.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Auto-creates a local User profile on the first authenticated API call
 * from a Keycloak-authenticated user.
 * <p>
 * Uses JWT claims: sub (user ID), preferred_username, email.
 * The new user has no facility assigned — admin must complete the profile.
 */
@Service
public class UserProvisioningService {

    private static final Logger log = LoggerFactory.getLogger(UserProvisioningService.class);

    private final UserRepository userRepository;

    public UserProvisioningService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional
    public User provisionIfAbsent(Jwt jwt) {
        String sub = jwt.getSubject();
        String username = jwt.getClaimAsString("preferred_username");
        String email = jwt.getClaimAsString("email");

        return userRepository.findByKeycloakSub(sub)
                .map(existing -> {
                    // Update last login and sync any changed Keycloak fields
                    existing.setLastLogin(java.time.Instant.now());
                    if (username != null) existing.setKeycloakUsername(username);
                    if (email != null) existing.setKeycloakEmail(email);
                    return userRepository.save(existing);
                })
                .orElseGet(() -> {
                    log.info("Auto-provisioning new user profile: sub={}, username={}", sub, username);
                    User user = new User();
                    user.setKeycloakSub(sub);
                    user.setKeycloakUsername(username != null ? username : sub);
                    user.setKeycloakEmail(email != null ? email : sub + "@unknown");
                    user.setLastLogin(java.time.Instant.now());
                    // facility_id intentionally null — admin must assign
                    return userRepository.save(user);
                });
    }
}
