%dw 2.0
import * from dw::core::Strings

/**
 * Extracts JWT token from Authorization header
 * @param authHeader - Authorization header value (e.g., "Bearer eyJhbGc...")
 * @return Token string or null if invalid format
 */
fun extractToken(authHeader: String) = 
  if (authHeader startsWith "Bearer ")
    substringAfter(authHeader, "Bearer ")
  else
    null