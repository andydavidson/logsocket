logsocket
=========

Use Perl's File::Tail to attach a log file to a tcp socket.

This can be useful in the event that you need to provide developer access to log files, but can not provide shell accounts on the server for compliance (e.g. pci-dss) reasons.

Specify the logs that you wish to give access to in logs.conf and their 'tag'.  Then run logsock.pl -p [port-number]

Remote users connect to the port and ask for the 'tag' as specified in logs.conf.  The logs are tailed to the user until teh user drops the socket.


