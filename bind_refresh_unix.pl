#!/usr/bin/perl

use strict;
use Proc::Simple;
use Proc::Killall;
use Time::localtime;
use LWP::Simple qw($ua getstore);
$ua->agent("");
use Mozilla::CA;

#use Data::Dumper;

my $adblock_stack = [
                     #pgl.yoyo exclusion list
		     { url => 'http://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext',
		              path => '/var/named/pgl-adblock.txt',
		              refresh => 7,
		     },
		     #adblockplus.org tracker list
		     { url => "abp:subscribe?location=https%3A%2F%2Feasylist-downloads.adblockplus.org%2Feasyprivacy.txt&title=EasyPrivacy&requiresLocation=https%3A%2F%2Feasylist-downloads.adblockplus.org%2Feasylist.txt&requiresTitle=EasyList",
		              path => '/var/named/easyprivacy.txt',
		              refresh => 5,
		     },
		     # Add additional hashrefs if you like--script will accept standard or abp:subscribe? urls.
		     # A collection of lists is available at http://adblockplus.org/en/subscriptions. 
];

my %adfilter = ();
#my $blacklist = { path => '/var/named/blacklist' };          #single column format
#my $whitelist = { path => '/var/named/whitelist' };          #single column format
my $outfile = '/var/named/adslist.txt';                      #include file for named.conf

read_config( adblock_stack => $adblock_stack, blacklist => $blacklist, whitelist => $whitelist);

open (OUT, ">$outfile") or die "Couldn't open output file: $!";
print OUT '// bind config generated ',ctime(),"\n\n";

foreach my $key (sort(keys %adfilter)) {
         print OUT 'zone "',$key,'" { type master; notify no; file "null.zone.file"; };',"\n";
       }
close OUT;

print "BIND ad zones updated.\n";
print "Halting BIND.\n" if killall('KILL','/usr/sbin/named');
print "Restarting BIND.\n" if $proc->start('/usr/sbin/named -4');

sub read_config {
        my %cache;

        if ($adblock_stack) {
	  for ( @{ $adblock_stack } ) {
	                    %cache = load_adblock_filter($_);                # adblock plus hosts
                        %adfilter = %adfilter ? ( %adfilter, %cache  ) 
			  : %cache;
			  }
	}
        if ($blacklist) {
	          %cache = parse_single_col_hosts($blacklist->{path});     # local, custom hosts
                        %adfilter = %adfilter ? ( %adfilter, %cache ) 
			  : %cache;
	}
        if ($whitelist) {
	          %cache = parse_single_col_hosts($whitelist->{path});     # remove entries
		  for ( keys %cache ) { delete ( $adfilter{$_} ) };
	}

	#dump_adfilter;
}

sub load_adblock_filter {
  my %cache;

  my $hostsfile = $_->{path} or die "adblock {path} is undefined";
  my $refresh = $_->{refresh} || 7;
  my $age = -M $hostsfile || $refresh;

  if ($age >= $refresh) {
    my $url = $_->{url} or die "attempting to refresh $hostsfile failed as {url} is undefined";
            $url =~ s/^\s*abp:subscribe\?location=//;
                $url =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
                $url =~ s/&.*$//;
            print("refreshing hosts: $hostsfile\n");
            getstore($url, $hostsfile);
  }

  %cache = parse_adblock_hosts($hostsfile);
  
  return %cache;
}

sub parse_adblock_hosts {
  my $hostsfile = shift;
  my %hosts;

  open(HOSTS, $hostsfile) or die "cant open $hostsfile file: $!";

  while (<HOSTS>) {
            chomp;
                next unless s/^\|\|(.*)\^(\$third-party)?$/$1/;  #extract adblock host
	    $hosts{$_}++;
	  }

  close(HOSTS);

  return %hosts;
}

sub parse_single_col_hosts {
  my $hostsfile = shift;
  my %hosts;

  if (-e $hostsfile) {
            open(HOSTS, $hostsfile) or die "cant open $hostsfile file: $!";

	    while (<HOSTS>) {
	            chomp;
		    next if /^\s*#/; # skip comments
		    next if /^$/;    # skip empty lines
		    s/\s*#.*$//;     # delete in-line comments and preceding whitespace
		    $hosts{$_}++;
	    }
	    close(HOSTS);
  }
  return %hosts;
}

sub dump_adfilter {
  my $str = Dumper(\%adfilter);
  open(OUT, ">/var/named/adfilter_dumpfile") or die "cant open dump file: $!";
  print OUT $str;
  close OUT;
}

=head1 NAME

bind_refresh_unix.pl

=head1 DESCRIPTION

This is a maintenance script for use with I<BIND> acting as an ad blocking agent. 
Its purpose is to refresh and format domain lists into master zone definitions for 
inclusion in a bind config file. It was written for osx (10.4), and manually kills 
and restarts the I<named> process.

The script loads externally maintained lists of ad hosts intended for use by the 
I<adblock plus> Firefox extension. Use of the lists focuses only on third-party 
listings that define dedicated ad/tracking hosts.

Locally maintained  blacklists/whitelists can also be loaded. In this case, host 
listings must conform to a one host per line format:

    # ad nauseam
    googlesyndication.com
    facebook.com
    twitter.com
    ...
    adinfinitum.com

Script output can easily be included in your named.conf file:

   ...
   include "/var/named/adslist.txt";

The script outputs zone definitions of the form:

  zone "googlesyndication.com" { type master; notify no; file "null.zone.file"; };

where null.zone.file is a localhost definition such as:

   $TTL 24h

   @ IN SOA example.homeip.net. unused-email.example.homeip.net. (
   2003052800 86400 300 604800 3600 )

   @ IN NS ns1.example.homeip.net.
   @ IN A 127.0.0.1
   * IN A 127.0.0.1

=head1 AUTHOR

David Watson <terminalfool@yahoo.com>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under the same terms as Perl itself.
=cut
