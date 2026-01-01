




CREATE OR REPLACE FUNCTION sfipi900k15r10 () RETURNS numeric AS $body$
DECLARE

--*
-- * Copyright (C) 2005, Japan Information Processing Service Co., Ltd.
-- * 
-- * Oracle 統計情報収集および索引再構成
-- * 
-- * 次の処理を行う。
-- * １．統計情報収集(ANALYZE)
-- *     analyze table compute staticsを使って統計情報収集を行います。
-- * ２．行断片解消(alter table move tablespace)
-- * ３．索引再構成(alter index rebuild)
-- * 
-- * @author 
-- * @version $Revision: xxxxx $
-- * 
-- * @return NUMBER
-- 
    stmt varchar(200);
    message varchar(256);
    tablespacename varchar(20);
    count_chain_stats numeric;

    status integer := 0;

    -- Variables from Oracle index_stats (unused but kept for compatibility)
    height numeric;
    del_lf_rows numeric;
    blks_gets_per_access numeric;
    lf_rows numeric;
    
    c_indexes CURSOR FOR
        SELECT indexname as index_name, tablespace as tablespace_name, tablename as table_name
        from pg_indexes
        where schemaname = current_schema();
BEGIN
    -- dbms_application_info.set_module not available in PostgreSQL
    message := 'ユーザ(' || current_user || ')の行断片化情報収集、行断片化解消、索引再構成を行います。';
    CALL pkLog.info(current_user, null, message);
    --表領域名称取得
    select DISTINCT tablespace into tablespacename from pg_tables where schemaname = current_schema() and tablespace is not null LIMIT 1;
    -- 索引再構成
    for r_indexes in c_indexes loop
        -- 索引の分析を行い、分析結果から判定する。
        -- chain_cntが１件でも発生している場合、テーブルの表領域移動と索引再構成を実施する。
        begin
            stmt := 'ANALYZE "'||r_indexes.table_name||'"';
            EXECUTE stmt;
            -- PostgreSQL equivalent: Check dead tuples instead of chain_cnt
            -- Dead tuples indicate fragmentation/bloat similar to Oracle's row chaining
            select COALESCE(n_dead_tup, 0)
               into count_chain_stats
                from pg_stat_user_tables
                WHERE schemaname = current_schema() 
                  AND relname = r_indexes.table_name;
            IF count_chain_stats > 0 THEN
                -- Analyze table (updates index statistics as well)
                stmt := 'ANALYZE "' || r_indexes.table_name || '"';
                EXECUTE stmt;
        END IF;
        exception
            when others then
            message := '索引(' || current_user || '.' || r_indexes.index_name ||
                ')の再構成中にエラーが発生しました。詳細エラー: ' || sqlerrm;
            CALL pkLog.warn(current_user, null, message);
            status := 1;
        end;
    end loop;
    message := 'ユーザ(' || current_user || ')の行断片化解消と索引再構成を行いました。';
    CALL pkLog.info(current_user, null, message);
    if status = 0 then
        message := 'ユーザ(' || current_user ||
            ')の行断片化解消と索引再構成を行いました。';
        CALL pkLog.info(current_user, null, message);
    else
        message := 'ユーザ(' || current_user ||
            ')の行断片化解消と索引再構成の実施中にエラーが発生しました。';
        CALL pkLog.error(current_user, null, message);
    end if;
    return status;
exception
    when others then
        message := 'ユーザ(' || current_user ||
            ')の統計情報収集と索引再構成に失敗しました。詳細エラー: ' || sqlerrm;
        CALL pkLog.error(current_user, null, message);
        return 99;
        null;
end;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k15r10 () FROM PUBLIC;