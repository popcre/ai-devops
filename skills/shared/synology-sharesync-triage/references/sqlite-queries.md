# SQLite Queries

## Pairing

```sql
select id, server_name, server_ip, server_port, linked, status, error, package_version
from connection_table;

select id, conn_id, share_name, view_id, status, error, is_daemon_enable, sync_direction
from session_table
where share_name = 'mac';

select * from server_view_table where name = 'mac';
```

## History

```sql
pragma table_info(history_table);

select * from history_table
where path like '%HSR68PNUT02_LICENSING SHEET.pdf%'
limit 20;
```

## Exact-path repair

Replace the example only with the path already proven by logs and a read query.

```sql
select count(*) as before_count from history_table where path = '/exact/full/path';
delete from history_table where path = '/exact/full/path';
select count(*) as after_count from history_table where path = '/exact/full/path';
```
