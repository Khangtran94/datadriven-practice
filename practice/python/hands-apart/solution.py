def clock_angle(hour: int, minute: int) -> float:
  ### each minute, minute increase 360 / 60 degree = 6 degree
  ### each hour, hour increase  (360/12) = 30 degree
  hour_angle = hour * 30 + minute * 0.5
  minute_angle = minute * 6  
  return min(abs(hour_angle - minute_angle), 360 - abs(hour_angle - minute_angle))
