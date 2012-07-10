module OverSIP::SIP

  ### SIP timer values.
  #
  # RTT Estimate (RFC 3261 17.1.2.1).
  T1          = 0.5
  # The maximum retransmit interval for non-INVITE requests and INVITE
  # responses (RFC 3261 17.1.2.2).
  T2          = 4
  # Maximum duration a message will remain in the network (RFC 3261 17.1.2.2).
  T4          = 5
  # INVITE request retransmit interval, for UDP only (RFC 3261 17.1.1.2).
  TIMER_A     = T1  # initially T1.
  # INVITE transaction timeout timer (RFC 3261 17.1.1.2).
  TIMER_B     = 64*T1
  # Proxy INVITE transaction timeout (RFC 3261 16.6 bullet 11).
  TIMER_C     = 180  # > 3min.
  # NOTE: This is a custom timer we use for INVITE server transactions in order to avoid they never end.
  TIMER_C2    = TIMER_C + 2
  # Wait time for response retransmits (RFC 3261 17.1.1.2).
  TIMER_D_UDP = 32  # > 32s for UDP.
  TIMER_D_TCP = 0   # 0s for TCP/SCTP.
  # Non-INVITE request retransmit interval, UDP only (RFC 3261 17.1.2.2).
  TIMER_E     = T1  # initially T1
  # Non-INVITE transaction timeout timer.
  TIMER_F     = 64*T1
  # INVITE response retransmit interval (RFC 3261 17.2.1).
  TIMER_G     = T1  # initially T1.
  # Wait time for ACK receipt (RFC 3261 17.2.1).
  TIMER_H     = 64*T1
  # Wait time for ACK retransmits (RFC 3261 17.2.1).
  TIMER_I_UDP = T4  # T4 for UDP.
  TIMER_I_TCP = 0   # 0s for TCP/SCTP.
  # Wait time for non-INVITE requests (RFC 3261 17.2.2).
  TIMER_J_UDP = 64*T1  # 64*T1 for UDP.
  TIMER_J_TCP = 0      # 0s for TCP/SCTP.
  # Wait time for response retransmits (RFC 3261 17.1.2.2).
  TIMER_K_UDP = T4  # T4 for UDP.
  TIMER_K_TCP = 0   # 0s for TCP/SCTP.
  # Wait time for accepted INVITE request retransmits (RFC 6026 17.2.1).
  TIMER_L     = 64*T1
  # Wait time for retransmission of 2xx to INVITE or additional 2xx from
  # other branches of a forked INVITE (RFC 6026 17.1.1).
  TIMER_M     = 64*T1

  ### Custom values.
  #
  # Interval waiting in a non INVITE server transaction before sending 100
  # (RFC 4320 - Section 4.1).
  INT1        = T2 + 1
  # Interval waiting in a non INVITE server transaction before assuming
  # timeout (RFC 4320 - Section 4.2).
  INT2        = TIMER_F - INT1

end
