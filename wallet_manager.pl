#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use JSON::XS;
use DateTime;
use File::Path qw(make_path);

my ($conf_file,$actions,$wallets,$backup_dir,$make_dir,$quiet, $force, $disable_prompt);
GetOptions(
	"conf=s" => \$conf_file, # location of wallet JSON conf file - defaults to ~/wallet_conf.json
	
	"actions=s" => \$actions, # comma seperated list of actions - REQUIRED
	# launch reload kill backup make restart
	
	"wallets=s" => \$wallets, # comma seperated list of coins - defaults to all in conf file!
	"backup_dir=s" => \$backup_dir, #where to put wallet backups - defaults to ~/Dropbox
	"make_dir=s" => \$make_dir, #where to put wallet builds - defaults to pwd
	"quiet" => \$quiet, # suppress output - default false
	"force" => \$force, #send -9 to process kill - default false,
	"disable_prompt" => \$disable_prompt #skip prompt when modifying every wallet - default false
);

die "An action is required!"
	unless $actions;

if (!$wallets && !$disable_prompt){
	print "\nYou did not specify a wallet, are you sure you want to perform this action on all wallets (Y/N)?\n";
	my $prompt = <>;
	if ($prompt !~ /y/i){
		print "Exiting due to negative response.\n";
		exit;
	}
}

my $base = '/home/'.$ENV{USER}.'/';
$conf_file ||= './wallet_conf.json';
$actions ||= 'lauch';
$make_dir ||= `pwd`;
chomp $make_dir;

my $conf;
{
	local $/ = undef;
	open my $f, $conf_file or
		die "Error opening configuation file: $!";
	$conf = JSON::XS::decode_json(<$f>);
	close $f;
}
 
$backup_dir ||= $base.'/Dropbox/';

$wallets = $wallets ? [ 
	map { 
		fetch_wallet($_) 
	} (split /\s*,\s*/, $wallets) 
] : $conf->{wallets};

my $update_conf;
my %wallet_dispacther = dispatcher_subs();
for my $wallet (@$wallets){
	for my $action (split /\s*,\s*/, $actions){
		$wallet_dispacther{$action}->($wallet);
	}
}

if ($update_conf) {
	open my $f, '>', $conf_file or
		die "Error opening configuation file: $!";
	my $json = JSON::XS->new->pretty(1)->encode($conf);
	print $f $json;
	close $f;
}

sub fetch_wallet {
	my $wallet = shift;
	my $wallet_conf = (grep {
		$_->{active} && $_->{name} eq $wallet
	} @{$conf->{wallets}})[0];
	die "Can't get wallet conf for $wallet!"
		unless ref $wallet_conf eq 'HASH';
	return $wallet_conf;
};

sub proc_exists {
	my $wallet = shift;
	my $proc = $wallet->{qt_exe} || lc $wallet->{name}.'-qt';
	my $exists = `ps -aef | grep  $proc | grep -v grep`;
	return $exists ? 1 : 0;
};

sub dispatcher_subs {
	return (
	launch => sub {
		my ($wallet) = @_;
		next if $wallet->{backup_only};
		if (proc_exists($wallet)){
			print "$wallet->{name} is already running!\n"
				unless $quiet;
			return 1;
		}
		$wallet->{qt_exe} ||= lc $wallet->{name}.'-qt';
		my $command = sprintf '%1$s/%2$s', 
			($wallet->{dir} || $base.$wallet->{name}),
			$wallet->{qt_exe};
		system("$command &");
		print "Lauched $wallet->{name} wallet!\n"
			unless $quiet;
		sleep(5);
		return 1;
	},
	kill => sub {
		my $wallet = shift;
		my $proc = $wallet->{qt_exe} || lc $wallet->{name}.'-qt';
		if (!proc_exists($wallet)){
			print "$wallet->{name} is not running!\n"
				unless $quiet;
			return 1;
		}
		my $level = $force ? ' -9 ' : '';
		system("pkill $level $proc");
		print "$wallet->{name} has been killed!\n"
		 	unless $quiet;
		return 1;
	},
	backup => sub {
		my $wallet = shift;
		$wallet->{wallet_file} ||= sprintf '~/.%1$s/wallet.dat',
			lc $wallet->{name};
		my $path = $backup_dir;
		my $date = DateTime->now->ymd('');
		$path .= join '/', (
			'Wallets',$wallet->{name},$date
		);
		make_path($path);
		system("cp $wallet->{wallet_file} $backup_dir/Wallets/$wallet->{name}/$date/wallet.dat");
		print "$wallet->{name} wallet backed up!\n"
			unless $quiet;
		return 1;
	},
	restart => sub {
		my $wallet = shift;
		if (!proc_exists($wallet)){
			print "$wallet->{name} was not running!\n"
				unless $quiet;
		} else {
			$wallet_dispacther{kill}->($wallet);
		}
		return $wallet_dispacther{launch}->($wallet);
	},
	reload => sub {
		my $wallet = shift;
		$wallet->{wallet_file} ||= sprintf '~/.%1$s/wallet.dat',
			lc $wallet->{name};
		opendir my($dh), "$backup_dir/Wallets/$wallet->{name}"
			or die "Couldn't open backup dir for '$wallet': $!";
		my @files = readdir $dh;
		closedir $dh;
		my $dir = (sort {
			$b cmp $a 
		} @files)[0];
		$dir = "${backup_dir}Wallets/$wallet->{name}/$dir";
		$wallet_dispacther{kill}->($wallet);
		system("cp $dir/wallet.dat $wallet->{wallet_file}");
		$wallet_dispacther{launch}->($wallet);
		print "$wallet->{name} wallet reloaded!\n"
			unless $quiet;
		return 1;
	},
	make => sub {
		my $wallet = shift;
		print "make_dir arg is required to make!\n"
			unless $make_dir;
		print "$wallet->{name} source url is required to make!\n"
			unless $wallet->{url};
		return unless $wallet->{url};
		my $opt = '';
		$opt = $wallet->{pre_make}
			if $wallet->{pre_make};
		system("git clone $wallet->{url} $make_dir/$wallet->{name}");
		system("cd $make_dir/$wallet->{name}; $opt qmake; make;");
		print "$wallet->{name} wallet built!\n"
			unless $quiet;
		$wallet->{dir} = "$make_dir/$wallet->{name}";
		$update_conf = 1;
		$wallet_dispacther{launch}->($wallet);
		return 1;
	},);
};

1;
