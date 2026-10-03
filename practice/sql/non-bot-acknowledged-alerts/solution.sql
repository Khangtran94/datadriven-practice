alert_events
  .filter((F.col('ack_by') != 'alice') | (F.col('ack_by').isNull()))
  .orderBy('fired_at')
