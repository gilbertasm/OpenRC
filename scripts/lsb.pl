#!/usr/bin/perl
# parse lsb header and print as in OpenRC style.
# base code borrowed from update-rc.d of Debian

use strict;
use warnings;
use Switch;
use File::Basename;

my $initdscript = shift;
my $name = basename($initdscript);

my %lsb2orc = ('$remote_fs' => 'netmount',
	       '$local_fs' => 'localmount',
	       'mountdevsubfs' => 'devfs',
	       '$syslog' => 'logger',
	       '$time' => 'clock',
	       '$all' => '*',
	       'nfs-common' => 'rpc.statd',
	       '$network' => 'net',
	       'mountkernfs' => 'procfs',
	       '$portmap' => 'rpcbind');

my $lsbheaders = "Provides|Required-Start|Required-Stop|Default-Start|Default-Stop|Short-Description|Description|Should-Start|Should-Stop|X-Start-Before|X-Start-After";



# Usage      : parse_insservconf(configuratoin_file)
# Purpose    : Parses insserv cinfiguration file into hash
# Returns    : Reference to hash containing parsed insserv.conf info
# Parameters : $file - filename of insserv configuration file
# Comments   : Returned hash structure:
#                dependency => facilitiy,
#                dependency => facilitiy,
#                etc
#
# TODO: handle insserv/overrides and insserv.conf.d directories


sub parse_insservconf {
  
    my $file = shift;
    my ($matched, $vs, $vsrv);
    $vsrv = {};

    open(my $vserv_fh, "<", $file) || die "error: unable to read $file";

    while (<$vserv_fh>){
        chomp;
 
        # Skip comments
        next if (m/^\#.*/);

        $matched = m/
                       ^           # start at string beginning
                       (\$\w+)     # capture literal $ followed by word in $1
                       \s+         # one or more whitespace characters
                       (\S+.*)     # capture everything after whitespace in $2
                   /ix;            # use case insensitive maching
    
        if ($matched) {
	    $vs = $1;
        
	    foreach my $srv (split(/\s+/, $2)) {
	        if ($srv =~ m/\+(\S+)/i) {
		    $vsrv->{$1} = $vs;
	        }
	    }
        }
    }

    return $vsrv
}



# Usage      : parse_initd_script(initd_script)
# Purpose    : Parses init script LSB info  into hash
# Returns    : Reference to hash containing parsed LSB info
# Parameters : $initdscript - filename of initd script
# Comments   : Function reads  LSB info from init script line by line
#              and parses it into hash
#              Returned hash structure:
#               lsbheader => rest of line,
#               lsbheader => rest of line,
#               etc           

sub parse_initd_script {

    my $initdscript = shift;
    my $lsbinforef  = {};
    my $matched;

    open(my $init_fh, "<", $initdscript) || die "error: unable to read $initdscript";

    while (<$init_fh>) {
        chomp;
        $lsbinforef->{'found'} = 1 if (m/^\#\#\# BEGIN INIT INFO\s*$/);
        last if (m/^\#\#\# END INIT INFO\s*$/);
        $matched = m/
                  ^              # match only  at string beginning
                  \#\s           # literal # followed by one space character 
                  ($lsbheaders): # capture $lsbheaders part in $1
                  \s+            # skip whitespace 
                  (\S+.*)$       # capture remaining of line in $2
                  /xi;


        if ($matched) {
	    $lsbinforef->{lc($1)} = $2;
        }
    }

    close($init_fh);
    return $lsbinforef;
}



sub l2of {
    my @value;
    my $items = shift;
    foreach my $item (split(/\s+/, $items)) {
	if($lsb2orc{$item}){
	    $item = $lsb2orc{$item}
	}
	push(@value, $item)
    }
    return join(" ", @value)
}

my $dep='';
my $des=''; 

my $lsbinfo = parse_initd_script($initdscript);
my $vsrv    = parse_insservconf("/etc/insserv.conf");

# Check that all the required headers are present
if ($lsbinfo->{found}) {
    foreach my $key (keys %$lsbinfo) {
	switch ($key) {
	    case "provides" {
		my @value;
		foreach my $item (split(/\s+/, $lsbinfo->{$key})) {
		    push(@value, $lsb2orc{$vsrv->{$item}}) if($vsrv->{$item});
		    push(@value, $lsb2orc{$item}) if ($item);
		    push(@value, $item) if ($item ne $name);
		}
		if (@value) {
		    $dep .= "\tprovide " . join(" ", @value) . "\n";
		}
	    }
	    case "required-start" {
		my $ret = l2of $lsbinfo->{$key};
		if($ret) {$dep .= "\tneed " . $ret . "\n"}
	    }
	    case "required-stop" {}
	    case "default-start" {}
	    case "default-stop" {}
	    case "short-description" {
		$des .= 'description="'.$lsbinfo->{$key}.'"'."\n";
	    }
	    case "description" {}
	    case "should-start" {
		my $ret = l2of $lsbinfo->{$key};
		if ($ret) {$dep .= "\tuse " . $ret . "\n"}
	    }
	    case "should-stop" {}
	    case "x-start-before" {
		my $ret = l2of $lsbinfo->{$key};
		if ($ret) {$dep .= "\tbefore " . $ret . "\n"}
	    }
	    case "x-start-after" {
		my $ret = l2of $lsbinfo->{$key};
		if ($ret) {$dep .= "\tafter " . $ret . "\n"}
	    }
	}
    }
}

my $rst;

if ($dep) {$rst = "depend () {\n" . $dep . "}\n"};
if ($des) {$rst = $des . "\n" . $rst};
print $rst
