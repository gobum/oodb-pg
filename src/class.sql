drop schema if exists class cascade;
create schema class;

create table class.id(
  id    varchar(16) primary key,
  id_class name
);

create view id as select id, id_class, xmin as id_ver from class.id;

create or replace function class.construct() returns event_trigger as $$
declare
  rec record;
  class   varchar;
  sql     varchar;
  ss      varchar[];
  body    varchar;
  base    varchar;
  bases   varchar[];
begin
  for rec in select * from pg_event_trigger_ddl_commands() loop
    if rec.schema_name = 'class' and rec.command_tag='CREATE TABLE' then
      class = substring(rec.object_identity from 7);
      sql = regexp_replace(current_query(), '/\*(?:[^*]|\*(?!/))*\*/', '', 'g');
      ss = regexp_split_to_array(sql, '\s*\minherits\M\s*', 'i');
      body = ','||regexp_substr(ss[1], '\(\s*(\S[\S\s]*\S*)\s*\)', 1, 1, 'i', 1);
      if ss[2] is not null then
        base = regexp_replace(regexp_substr(ss[2], '\(([\S\s]*)\)', 1, 1, 'i', 1), '^\s+|\mclass\.|\s+$', '', 'g');
        bases = regexp_split_to_array(lower(base), '\s*,\s*');
        bases = ( select array_agg(table_name)
          from ( select distinct on (bi) table_name
            from ( select table_name, first_value(bi)over(partition by table_name)bi
              from generate_subscripts(bases, 1) bi,
                   information_schema.view_table_usage
              where view_name=bases[bi] and table_name!='id'
            ) ti
          ) tn );
      end if;

      -- 聚集基类的基表
      -- if base is not null then
      -- end if;
      bases[coalesce(array_length(bases, 1),0)+1] = class;

      -- 建类的基表
      execute format(E'drop table class.%s', class);
      sql = format(E'create table %s(id varchar(16) primary key references class.id(id) on update cascade on delete cascade%s)', class, body);
      execute sql;
      execute format(E'alter table %s set schema class', class);

      sql = (with
          -- bases as (select string_to_array('girl,boy', ',') bases),
          bs as (select bases[generate_subscripts(bases,1)] b, generate_subscripts(bases,1) i),
          tfs as ( select b, i, ordinal_position j, column_name fld,
              case when count(*)over(partition by column_name)!=1 then table_name||'_'||column_name end als
            from bs left join information_schema.columns
              on b=table_name and table_schema='class'
                and table_name!='id' and column_name!='id'
          ),
          tcs as (select b, i, j, fld,
              b||'.'||fld||coalesce(' '||als, '') col,
              'new.'||coalesce(als, fld) new,
              'old.'||coalesce(als, fld) old
            from tfs
            order by i, j
          ),
          ts as (select b, i, string_agg(fld, ',') fld, string_agg(col, ',') col, string_agg(new, ',') new, string_agg(old, ',') old
            from tcs
            group by i, b
          ),
          ss as (select col,
              format('join class.%s on id.id=%s.id', b, b) joins,
              format('insert into class.%s values(new.id%s);', b, ','||new) ins,
              case when fld is not null then format('update class.%s set(%s)=(%s) where id=old.id and (%s) is distinct from (%s);', b, fld, new, new, old) end upd
            from ts
            order by i
          ),
          xs as (select string_agg(col, ',') cols, string_agg(joins, E'\n') joins,
              string_agg(ins, E'\n') inss, string_agg(upd, E'\n') upds
            from ss
          ),
          sq as (select
              format(E'create view %s as\nselect id.id%s,id.id_class,id.xmin id_ver\nfrom class.id\n%s;', class, ','||cols, joins) the_view,
              format(E'create rule _ins as on insert to %s do instead(\ninsert into class.id values(new.id,''%s'');%s);', class, class, E'\n'||inss) rule_insert,
              format(E'create rule _upd as on update to %s do instead(%s\nupdate class.id set id=new.id where id=old.id;);', class, E'\n'||upds) rule_update,
              format(E'create rule _del as on delete to %s do instead(\ndelete from class.id where id=old.id;);', class) rule_delete
            from xs
          )
        select format(E'%s\n\n%s\n\n%s\n\n%s', the_view, rule_insert, rule_update, rule_delete) from sq
      );
      -- raise notice E'[DEBUG] sql:\n%', sql;
      execute sql;
    end if;
  end loop;  
end;
$$ language plpgsql;

create or replace function class.destroy() returns event_trigger as $$
declare
  sql varchar;
  class varchar;
begin
  sql = current_query();
  class = regexp_substr(sql, '\mclass\.(\w+)\s*(?:cascade|restrict)?\s*;\s*$', 1, 1, 'i', 1);
  if class is not null then
    execute format(E'drop view if exists %s', class);
  end if;  
end;
$$ language plpgsql;

create event trigger class_construct on ddl_command_end
  when tag in ('CREATE TABLE')
  execute function class.construct();

create event trigger class_destroy on ddl_command_start
  when tag in ('DROP TABLE')
  execute function class.destroy();
