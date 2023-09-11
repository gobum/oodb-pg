:Hope /* class Empty */
  create table class.Empty()
  :Pass
:Done

:Hope /* class None */
  create table class.None()
    inherits(class.Empty)
  :Pass
:Done

:Hope /* class Person */
  create table class.Person (
    name    varchar,
    age     int
  )
  :Pass
:Done

:Hope /* class Nobody */
  create table class.Nobody()
    inherits(class.Person)
  :Pass
:Done

:Hope /* class Company */
  create table class.Company (
    name    varchar,
    years   int
  )
  :Pass
:Done

:Hope /* class Worker */
  create table class.Worker (
    company varchar(16) references class.Company(id) references class.Company on update cascade,
    job     varchar,
    salary  numeric
  )inherits(class.Person)
  :Pass
:Done

:Hope /* Make Person */
  insert into Person
    select a.Id(i), a.Name(), a.Int(18,66)
      from a.Series(100000) i
  :Pass
:Done

:Hope /* Make Company */
  insert into Company
    select a.Id(i), a.Company(), a.Int(130)
      from a.Series(1000) i
    :Pass
:Done

:Hope /* Make Worker */
  insert into Worker
    select a.Id(i.i), a.Name(), a.Int(24, 60), Company.id, a.Name()
      from a.Series(1, 10000) i
      join ( select row_number()over() i, id 
        from ( select id from Company order by random() limit 100000 ) t
      ) Company on i.i=Company.i
  :Pass
:Done



