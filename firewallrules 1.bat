netsh advfirewall firewall add rule name="Cloud - AMQP 5672"           dir=in action=allow protocol=TCP localport=5672 profile=any
netsh advfirewall firewall add rule name="Cloud - RabbitMQ UI 15672"   dir=in action=allow protocol=TCP localport=15672 profile=any
netsh advfirewall firewall add rule name="Cloud - PostgreSQL 5433"     dir=in action=allow protocol=TCP localport=5433 profile=any
netsh advfirewall firewall add rule name="Cloud - HTTP 80"             dir=in action=allow protocol=TCP localport=80   profile=any
netsh advfirewall firewall add rule name="Cloud - HTTPS 443"           dir=in action=allow protocol=TCP localport=443  profile=any
 
netsh advfirewall firewall add rule name="Cloud - AMQP 5672"           dir=out action=allow protocol=TCP localport=5672 profile=any
netsh advfirewall firewall add rule name="Cloud - RabbitMQ UI 15672"   dir=out action=allow protocol=TCP localport=15672 profile=any
netsh advfirewall firewall add rule name="Cloud - PostgreSQL 5433"     dir=out action=allow protocol=TCP localport=5433 profile=any
netsh advfirewall firewall add rule name="Cloud - HTTP 80"             dir=out action=allow protocol=TCP localport=80   profile=any
netsh advfirewall firewall add rule name="Cloud - HTTPS 443"           dir=out action=allow protocol=TCP localport=443  profile=any