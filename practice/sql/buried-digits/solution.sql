SELECT
  svc_name,
  CAST(
    REPLACE(
      REPLACE(
        REPLACE(version, 'v', ''),
        '.',
        ''
        ),
      '-',
      ''
      )
    AS INTEGER
    ) AS version_num
FROM deploy_logs
WHERE env_name = 'staging'
