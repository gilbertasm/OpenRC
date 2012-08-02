#!/usr/bin/perl
# parse lsb header and print as in OpenRC style.
# base code borrowed from update-rc.d of Debian

use Switch;
use File::Basename;

my $initdscript = shift;
my $name = basename($initdscript);
my %lsb2orc = ('$remote_fs' => 'netmount',
	       '$local_fs' => 'localmount',
	       'mountdevsubfs' => 'devfs',
	       '$syslog' => 'logger',
	       '$time' => 'clock',
	       '$all' => '*');

my %vsrv;
open(VSERV, "</etc/insserv.conf") || die "error: unable to read /etc/insserv.conf";
while (<VSERV>){
    next if (m/^\#.*/);
    chomp;
    if (m/^(\$\w+)\s*(\S?.*)$/i) {
	my $vs=$1;
	foreach $srv (split(/ /,$2)) {
	    if ($srv =~ m/\+(\S?.*)/i) {
		$vsrv{$1} = $vs;
	    }
	}
    }
}

my %lsbinfo;
my $lsbheaders = "Provides|Required-Start|Required-Stop|Default-Start|Default-Stop|Short-Description|Description|Should-Start|Should-Stop|X-Start-Before|X-Start-After";
open(INIT, "<$initdscript") || die "error: unable to read $initdscript";
while (<INIT>) {
    chomp;
    $lsbinfo{'found'} = 1 if (m/^\#\#\# BEGIN INIT INFO\s*$/);
    last if (m/\#\#\# END INIT INFO\s*$/);
    if (m/^\# ($lsbheaders):\s*(\S?.*)$/i) {
	$lsbinfo{lc($1)} = $2;
    }
}
close(INIT);

my $dep='';
my $des='';

sub l2of {
    my @value;
    my $items = shift;
    foreach $v (split(/ /, $items)) {
	if($lsb2orc{$v}){
	    $v=$lsb2orc{$v}
	}
	push(@value,$v)
    }
    return join(" ", @value)
}

# Check that all the required headers are present
if ($lsbinfo{found}) {
    foreach $key (keys %lsbinfo) {
	switch ($key) {
	    case "provides" {
		my @value;
		foreach $v (split(/ /, $lsbinfo{$key})) {
		    push(@value, $lsb2orc{$vsrv{$v}}) if($vsrv{$v});
		    push(@value, $v) if ($v ne $name);
		}
		if (@value) {
		    $dep .= "\tprovide " . join(" ", @value) . "\n";
		}
	    }
	    case "required-start" {
		my $ret = l2of $lsbinfo{$key};
		if($ret) {$dep .= "\tneed " . $ret . "\n"}
	    }
	    case "required-stop" {}
	    case "default-start" {}
	    case "default-stop" {}
	    case "short-description" {
		$des .= 'description="'.$lsbinfo{$key}.'"'."\n";
	    }
	    case "description" {}
	    case "should-start" {
		my $ret = l2of $lsbinfo{$key};
		if ($ret) {$dep .= "\tuse " . $ret . "\n"}
	    }
	    case "should-stop" {}
	    case "x-start-before" {
		my $ret = l2of $lsbinfo{$key};
		if ($ret) {$dep .= "\tbefore " . $ret . "\n"}
	    }
	    case "x-start-after" {
		my $ret = l2of $lsbinfo{$key};
		if ($ret) {$dep .= "\tafter " . $ret . "\n"}
	    }
	}
    }
}
if ($dep) {$rst = "depend () {\n" . $dep . "}\n"};
if ($des) {$rst = $des . "\n" . $rst};
print $rst
