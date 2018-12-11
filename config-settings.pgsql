
-- All actions in this script must be idempotent.

alter system set autovacuum_max_workers = 20 ;
alter system set autovacuum_vacuum_cost_limit = 2000 ;

\q

-- After we switch to PG 10 or later, we can avoid overwriting changes users may have already made.
select
    exists(select 1 from pg_settings where name = 'autovacuum_max_workers' and source = 'default') as do_max_workers,
    exists(select 1 from pg_settings where name = 'autovacuum_max_cost_limit' and source = 'default') as do_cost_limit
\gset
\if :do_max_workers
    alter system set autovacuum_max_workers = 20 ;
\endif
\if :do_cost_limit
    alter system set autovacuum_vacuum_cost_limit = 2000 ;
\endif

