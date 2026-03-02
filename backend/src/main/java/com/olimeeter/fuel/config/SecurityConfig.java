package com.olimeeter.fuel.config;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Device endpoints use header-based auth (Device-ID)
                        .requestMatchers("/api/v1/measurements").permitAll()
                        // Admin endpoints require admin role
                        .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                        // All other API endpoints require authentication
                        .requestMatchers("/api/v1/**").authenticated()
                        // Actuator and health
                        .requestMatchers("/actuator/**").permitAll()
                        .anyRequest().permitAll()
                )
                .addFilterBefore(jwtAuthenticationFilter(), UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecretKey jwtSecretKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
    }

    @Bean
    public JwtAuthenticationFilter jwtAuthenticationFilter() {
        return new JwtAuthenticationFilter(jwtSecretKey());
    }

    public static class JwtAuthenticationFilter extends OncePerRequestFilter {

        private final SecretKey secretKey;

        public JwtAuthenticationFilter(SecretKey secretKey) {
            this.secretKey = secretKey;
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request,
                                        HttpServletResponse response,
                                        FilterChain filterChain) throws ServletException, IOException {
            String header = request.getHeader("Authorization");
            if (header != null && header.startsWith("Bearer ")) {
                String token = header.substring(7);
                try {
                    Claims claims = Jwts.parser()
                            .verifyWith(secretKey)
                            .build()
                            .parseSignedClaims(token)
                            .getPayload();

                    String userId = claims.getSubject();
                    String role = claims.get("role", String.class);

                    List<SimpleGrantedAuthority> authorities = List.of(
                            new SimpleGrantedAuthority("ROLE_" + role.toUpperCase())
                    );

                    var authentication = new UsernamePasswordAuthenticationToken(
                            userId, null, authorities);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                } catch (Exception e) {
                    SecurityContextHolder.clearContext();
                }
            }
            filterChain.doFilter(request, response);
        }
    }
}
