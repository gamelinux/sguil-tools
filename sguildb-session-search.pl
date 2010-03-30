#!/usr/bin/perl

use strict;
use warnings;
use Date::Simple ('date', 'today');
use Getopt::Long qw/:config auto_version auto_help/;
use DBI;

# You need to set DB user,password and host to connect to...
my $db_host      = 'localhost';
my $db_user_name = 'sguil';
my $db_password  = 'awsomepasswd';
my $DLIMIT        = 100;

=head1 NAME

    sguil-sessions.pl - Search Sguil sancp/session data for sessions

=head1 VERSION

    0.1

=head1 SYNOPSIS

$ sguil-sessions.pl [options]

  OPTIONS:

    --src_ip      : Source IP
    --src_port    : Source Port
    --dst_ip      : Destination IP
    --dst_port    : Destination Port
    --proto       : Protocol
    --from-date   : Date to search from in iso format (2010-01-01 etc.)
    --to-date     : Date to search to in iso format (2020-01-01 etc.)
    --limit       : Limit on search results

=cut

our $DEBUG         = 0;
our $SRC_IP;
our $SRC_PORT;
our $DST_IP;
our $DST_PORT;
our $PROTO;
our $FROM_DATE;
our $TO_DATE;
our $LIMIT;

GetOptions(
    'src_ip=s'      => \$SRC_IP,
    'src_port=s'    => \$SRC_PORT,
    'dst_ip=s'      => \$DST_IP,
    'dst_port=s'    => \$DST_PORT,
    'proto=s'       => \$PROTO,
    'from-date=s'   => \$FROM_DATE,
    'to-date=s'     => \$TO_DATE,
    'limit=s'       => \$LIMIT,
);


my $dsn = 'DBI:mysql:sguildb:'.$db_host;
my $dbh = DBI->connect($dsn, $db_user_name, $db_password);
my $today = today();
my $weekago = $today - 7;
my $yesterday = $today->prev;
#$date =~ s/-//g ;

=head1 FUNCTIONS

=head2 tftoa

    Takes decimal representation of TCP flags,
    and returns ascii defined values.

=cut

sub tftoa {
    my $Flags = shift;
    my $out = "";

    $out .= "S" if ( $Flags & 0x02 );
    $out .= "A" if ( $Flags & 0x10 );
    $out .= "P" if ( $Flags & 0x08 );
    $out .= "U" if ( $Flags & 0x20 );
    $out .= "E" if ( $Flags & 0x40 );
    $out .= "C" if ( $Flags & 0x80 );
    $out .= "F" if ( $Flags & 0x01 );
    $out .= "R" if ( $Flags & 0x04 );

    return "-" if $out eq "";
    return $out;
}

our $QUERY = q();
$QUERY = qq[SELECT sancp.start_time,INET_NTOA(sancp.src_ip),sancp.src_port,INET_NTOA(sancp.dst_ip),sancp.dst_port,sancp.ip_proto,src_flags,dst_flags FROM sancp IGNORE INDEX (p_key) WHERE ];

if (defined $FROM_DATE && $FROM_DATE =~ /^\d\d\d\d\-\d\d\-\d\d$/) {
    print "Searching from date: $FROM_DATE 00:00:01\n" if $DEBUG;
    $QUERY = $QUERY . qq[sancp.start_time > '$FROM_DATE 00:00:01' ];
} else {
    print "Searching from date: $yesterday\n" if $DEBUG;
    $QUERY = $QUERY . qq[sancp.start_time > '$yesterday' ];
}

if (defined $TO_DATE && $TO_DATE =~ /^\d\d\d\d\-\d\d\-\d\d$/) {
    print "Searching to date: $TO_DATE 23:59:59\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND sancp.end_time < '$TO_DATE 23:59:59' ];
}

if (defined $SRC_IP && $SRC_IP =~ /^([\d]{1,3}\.){3}[\d]{1,3}$/) {
    print "Source IP is: $SRC_IP\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND INET_NTOA(sancp.src_ip)='$SRC_IP' ];
}

if (defined $SRC_PORT && $SRC_PORT =~ /^([\d]){1,5}$/) {
    print "Source Port is: $SRC_PORT\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND sancp.src_port='$SRC_PORT' ];
}

if (defined $DST_IP && $DST_IP =~ /^([\d]{1,3}\.){3}[\d]{1,3}$/) {
    print "Destination IP is: $DST_IP\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND INET_NTOA(sancp.dst_ip)='$DST_IP' ];
}

if (defined $DST_PORT && $DST_PORT =~ /^([\d]){1,5}$/) {
    print "Destination Port is: $DST_PORT\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND sancp.dst_port='$DST_PORT' ];
}

if (defined $PROTO && $PROTO =~ /^([\d]){1,3}$/) {
    print "Protocol is: $PROTO\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND sancp.ip_proto='$PROTO' ];
}

if (defined $LIMIT && $LIMIT =~ /^([\d])+$/) {
    print "Limit: $LIMIT\n" if $DEBUG;
    $QUERY = $QUERY . qq[ORDER BY sancp.start_time LIMIT $LIMIT ];
} else {
    print "Limit: $DLIMIT\n" if $DEBUG;
    $QUERY = $QUERY . qq[ORDER BY sancp.start_time LIMIT $DLIMIT ];
}

print "\nmysql> $QUERY;\n\n" if $DEBUG;

my $pri = $dbh->prepare( qq{ $QUERY } ); 
$pri->execute();

while (my ($starttime,$src_ip,$src_port,$dst_ip,$dst_port,$proto,$src_flags,$dst_flags) = $pri->fetchrow_array()) {
    next if not defined $src_ip or not defined $dst_ip;
    my $SFlags = tftoa($src_flags);
    my $DFlags = tftoa($dst_flags);
    printf("% 15s:%-5s -> % 15s:%-5s  (%s) [%s|%s]\n",$src_ip,$src_port,$dst_ip,$dst_port,$proto,$SFlags,$DFlags);
}

$pri->finish();
$dbh->disconnect();

=head1 AUTHOR

    Edward Fjellskaal (edwardfjellskaal@gmail.com)

=head1 COPYRIGHT

    Copyright (C) 2010, Edward Fjellskaal (edwardfjellskaal@gmail.com)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

