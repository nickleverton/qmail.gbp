#!/bin/sh

# Using splogger to send the log through syslog.
# Using procmail to deliver messages to /var/spool/mail/$USER by default.

exec \
qmail-start '|preline procmail' splogger qmail
