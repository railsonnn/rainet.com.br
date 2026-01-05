%dw 2.0

/**
 * Consolidates PPPoE data from secrets and active connections
 * @param secrets - Array of PPP secrets from MikroTik
 * @param active - Array of active PPP connections from MikroTik
 * @return Array of consolidated PPPoE data with online status and traffic info
 */
fun consolidatePPPoEData(secrets, active) = 
  secrets map (secret) -> do {
    var activeConnection = (active filter ($.name == secret.name))[0]
    var isOnline = activeConnection != null
    ---
    {
      username: secret.name,
      plan_profile: secret.profile default "",
      comment: secret.comment default "",
      online: isOnline,
      (if (isOnline)
        {
          ip_address: activeConnection.address default "",
          uptime: activeConnection.uptime default "",
          rx_bytes: activeConnection."rx-byte" default 0,
          tx_bytes: activeConnection."tx-byte" default 0
        }
      else {})
    }
  }