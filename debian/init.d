#!/bin/bash
#
# /etc/init.d/qmail : start or stop the qmail mail subsystem.
#
# Written by Christian Hudon <chrish@debian.org>
# Currently maintained by Jon Marler <jmarler@debian.org>
#
# Configuration
#


# set default delivery method

alias_empty="|/usr/sbin/qmail-procmail"  # procmail delivery to /var/spool/mail
#alias_empty="./Maildir/"       # This uses qmail prefered ~/Maildir/ directory
				# You may want to maildirmake /etc/skel/Maildir
#alias_empty="./Mailbox"        # This uses Mailbox file in users $HOME

logger="splogger qmail 2"	# facility mail == 2
#logger="|accustamp >>/var/log/qmail.log"   # If you have accustamp installed.
#logger=">>/var/log/qmail.log"              # Does not give timing info.

# If you uncommented one of the lines that appends to /var/log/qmail.log, you
# need to uncomment the following two lines.
#touch /var/log/qmail.log
#chown qmaill /var/log/qmail.log

# If you want to use one or more of the Relay Black Lists, uncomment
# the appropriate lines.

rblmsg=
rblsmtpd=
#rblmsg=" (with rblsmtpd)" 
#rblsmtpd="/usr/bin/rblsmtpd -r list.dsbl.org -r relays.ordb.org"

#
# End of configuration
#

test -x /usr/sbin/qmail-start || exit 0
test -x /usr/sbin/qmail-send || exit 0

case "$1" in
    start)
	echo -n "Starting mail-transfer agent: qmail" $rblmsg
	sh -c "start-stop-daemon --start --quiet --user qmails \
		 --exec /usr/sbin/qmail-send \
		 --startas /usr/sbin/qmail-start -- \"$alias_empty\" $logger &"
	# prevent denial-of-service attacks, with ulimit
	ulimit -v 16384
         sh -c "start-stop-daemon --start --quiet --user qmaild \
	    --pidfile /var/run/tcpserver_smtpd.pid --make-pidfile \
            --exec /usr/bin/tcpserver -- -R -H \
            -u `id -u qmaild` -g `id -g nobody` -x /etc/tcp.smtp.cdb 0 smtp \
            $rblsmtpd /usr/sbin/qmail-smtpd 2>&1 \
            | $logger &"

	# Uncomment the following lines to automatically start the pop3 server
	#sh -c "start-stop-daemon --start --quiet --user root \
	#    --pidfile /var/run/tcpserver_pop3d.pid --make-pidfile \
	#    --exec /usr/bin/tcpserver -- -R -H \
	#    0 pop-3 /usr/sbin/qmail-popup `hostname`.`dnsdomainname` \
	#    /usr/bin/checkpassword /usr/sbin/qmail-pop3d Maildir &"
	
	echo "."
	;;
    stop)
	echo -n "Stopping mail-transfer agent: qmail" $rblmsg
	if [ "`pidof /usr/sbin/qmail-send`" ] ; then
	    start-stop-daemon --user qmails --stop --quiet --oknodo --exec /usr/sbin/qmail-send
	    start-stop-daemon --user qmaild --stop --quiet --oknodo --pidfile /var/run/tcpserver_smtpd.pid --exec /usr/bin/tcpserver 
	    # Uncomment the following line if you have enabled the pop3 server
	    #start-stop-daemon --user root --stop --quiet --oknodo --pidfile /var/run/tcpserver_pop3d.pid --exec /usr/bin/tcpserver

	    # Wait until the timeout for qmail processes to die.
	    count=120
	    numdots=0
	    while ([ $count != 0 ]) do
		let count=$count-1
		if [ "`pidof /usr/sbin/qmail-send`" ] ; then
		    echo -n .
		    let numdots=$numdots+1
		    sleep 1
		else
		    count=0
		fi
	    done

	    # If it's not dead yet, kill it.
#	    if [ "`pidof /usr/sbin/qmail-send`" ] ; then
#		echo -n " TIMEOUT!"
#		kill -KILL `pidof /usr/sbin/qmail-send`
#	    else
		case $numdots in
		  0) echo "." ;;
		  1) echo ;;
		  *) echo " done." ;;
		esac
#	    fi
	else
	    echo " not running.";
	fi

	;;
    restart)
	$0 stop
	$0 start
	;;
    cdb)
	echo "Rebuilding tcp.smtp.cdb."
	cd /etc
	tcprules tcp.smtp.cdb tcp.smtp.temp < tcp.smtp
	;;
    flush)
        /usr/sbin/qmail-tcpok
        start-stop-daemon --stop --quiet --oknodo --signal ALRM --exec /usr/sbin/qmail-send
        echo "Queue flushed."
        ;;
    stat)
        /usr/sbin/qmail-qread
        /usr/sbin/qmail-qstat
        ;;
    reload|force-reload)
	echo "Reloading 'locals' and 'virtualdomains' control files."
	start-stop-daemon --stop --quiet --oknodo --signal HUP --exec /usr/sbin/qmail-send
	;;
    *)
	echo 'Usage: /etc/init.d/qmail {start|stop|stat|cdb|restart|reload}'
	exit 1
esac

exit 0
