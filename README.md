rrwatch
=======

RoundRobin watch check if hosts defined in A and AAAA records for given urls are available and if not make them stop appear in dns answers.
Script works with PowerDNS and mysql backend.
This is modification of code founded on http://www.pmamediagroup.com/2009/06/setting-powerdns-to-ignore-records-for-downed-web-sites/ added:

* AAAA records
* recognize connection type (http or https)
* logging
* run like a daemon when system start
* always keep at least one record for domain

##PowerDNS configuration

You must configure powerdns to not return records which have -1 priority. To do this put in pdns.conf:

```
gmysql-any-query=select content,ttl,prio,type,domain_id,name \
     from records where name='%s' and (prio<>-1 or prio is null)
```

```

gmysql-any-id-query=select content,ttl,prio,type,domain_id,name \ 
     from records where name='%s' and domain_id=%d and (prio<>-1 or prio is null)
```

If you use DNSSEC put instead this:

```
gmysql-any-query-auth=select content,ttl,prio,type,domain_id,name, auth \
       from records where name='%s' and (prio<>-1 or prio is null)
```

```
gmysql-any-id-query-auth=select content,ttl,prio,type,domain_id,name, auth \
       from records where name='%s' and domain_id=%d and (prio<>-1 or prio is null)
```

Example of creating mysql user:

```
CREATE USER 'rrwatch'@'localhost' IDENTIFIED BY 'PASS';
GRANT SELECT (id,name,type,content,ttl,prio), UPDATE (prio) ON pdns.records TO 'rrwatch'@'localhost';
```

Remember that records will be returned until cache expires.
