import Keycloak from "keycloak-js";

const keycloak = new Keycloak({
  url: import.meta.env.VITE_KEYCLOAK_URL ?? "http://localhost:8180",
  realm: import.meta.env.VITE_KEYCLOAK_REALM ?? "olimeeter",
  clientId: import.meta.env.VITE_KEYCLOAK_CLIENT_ID ?? "olimeeter-app",
});

let initialized = false;

/** Initialize Keycloak and redirect to login if not authenticated */
export async function initKeycloak(): Promise<boolean> {
  if (initialized) return keycloak.authenticated ?? false;

  const authenticated = await keycloak.init({
    onLoad: "login-required",
    pkceMethod: "S256",
    checkLoginIframe: false,
  });

  initialized = true;

  if (authenticated) {
    // Auto-refresh token before expiry
    setInterval(async () => {
      try {
        await keycloak.updateToken(30);
      } catch {
        keycloak.login();
      }
    }, 10_000);
  }

  return authenticated;
}

/** Get current access token (for API calls) */
export function getToken(): string | undefined {
  return keycloak.token;
}

/** Get parsed token claims */
export function getTokenParsed() {
  return keycloak.tokenParsed;
}

/** Get username from token */
export function getUsername(): string | undefined {
  return keycloak.tokenParsed?.preferred_username;
}

/** Get user's realm roles */
export function getRoles(): string[] {
  return keycloak.tokenParsed?.realm_access?.roles ?? [];
}

/** Check if user has a specific role */
export function hasRole(role: string): boolean {
  return getRoles().includes(role);
}

/** Logout and redirect to Keycloak logout page */
export function logout(): void {
  keycloak.logout({ redirectUri: window.location.origin });
}

/** Force token refresh */
export async function refreshToken(): Promise<boolean> {
  try {
    return await keycloak.updateToken(-1);
  } catch {
    return false;
  }
}

export { keycloak };
