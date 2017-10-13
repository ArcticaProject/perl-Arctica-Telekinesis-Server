################################################################################
#          _____ _
#         |_   _| |_  ___
#           | | | ' \/ -_)
#           |_| |_||_\___|
#                   _   _             ____            _           _
#    / \   _ __ ___| |_(_) ___ __ _  |  _ \ _ __ ___ (_) ___  ___| |_
#   / _ \ | '__/ __| __| |/ __/ _` | | |_) | '__/ _ \| |/ _ \/ __| __|
#  / ___ \| | | (__| |_| | (_| (_| | |  __/| | | (_) | |  __/ (__| |_
# /_/   \_\_|  \___|\__|_|\___\__,_| |_|   |_|  \___// |\___|\___|\__|
#                                                  |__/
#          The Arctica Modular Remote Computing Framework
#
################################################################################
#
# Copyright (C) 2015-2016 The Arctica Project 
# http://arctica-project.org/
#
# This code is dual licensed: strictly GPL-2 or AGPL-3+
#
# GPL-2
# -----
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
#
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# AGPL-3+
# -------
# This programm is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This programm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Copyright (C) 2015-2016 Guangzhou Nianguan Electronics Technology Co.Ltd.
#                         <opensource@gznianguan.com>
# Copyright (C) 2015-2016 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
################################################################################
package Arctica::Telekinesis::Server;
use strict;
use Exporter qw(import);
use Data::Dumper;
use Arctica::Core::eventInit qw( genARandom BugOUT );
# Be very selective about what (if any) gets exported by default:
our @EXPORT = qw();
# And be mindfull of what we lett the caller request here too:
our @EXPORT_OK = qw();

my $arctica_core_object;

sub new {
	BugOUT(9,"TeKi Server new->ENTER");
	my $class_name = $_[0];# Be EXPLICIT!! DON'T SHIFT OR "@_";
	$arctica_core_object = $_[1];
	my $the_tmpdir = $arctica_core_object->{'a_dirs'}{'tmp_adir'};
	my $teki_tmpdir = "$the_tmpdir/teki";
	unless (-d $teki_tmpdir) {
		mkdir($teki_tmpdir) or die("TeKi Server unable to create TMP dir $teki_tmpdir ($!)");
	}
	
	my $self = {
		tmpdir => $teki_tmpdir,
		isArctica => 1, # Declare that this is a Arctica "something"
		aobject_name => "Telekinesis_Server",
		available_services => {
			multimedia => 1,
			webcontent => 1,
		},
	};
	$self->{'session_id'} = genARandom('id');
	$self->{'state'}{'active'} = 0;

	bless($self, $class_name);
	$arctica_core_object->{'aobj'}{'Telekinesis_Server'} = \$self;

	BugOUT(9,"TeKi Server new->DONE");
	return $self;
}

sub c2s_service_neg {
	my $self = $_[0];
################################################################################
# This is just a "dummy" place holder for the real negotiation function
################################################################################
	my $jdata = $_[1];
	my $sclient_id = $_[2];
	my $bself = $_[3];
#	print "SRVCNEG:\t",Dumper($jdata),"\n";
	if ($jdata->{'step'} eq 1) {
# Client told us which services it can provide,
# We check if we're able to play ball... if server side is version match we're all good.
# If server side is newest, serverside must know if we are compatible.
# If client side is newest, we expect client to tell us if we have a compatible pair.
		BugOUT(9,"Service Negotiation Step 1");
		$_[3]->server_send($_[2],'srvcneg',{
			step => 2,
			services => {
				multimedia => 1,
				webcontent => 1,
			},
		});
	} elsif ($jdata->{'step'} eq 3) {
		BugOUT(9,"Service Negotiation Step 3");
		# By this point we should be done negotiating... 
		BugOUT(9,"TIME TO ACTIVATE THIS STUFF!");
		$self->{'status'}{'active'} = 1;
		if ($self->{'running_apps'}) {
			foreach my $rapp_id (sort (keys %{$self->{'running_apps'}})) {
#				print "\t\t$rapp_id\n";
				$self->tekicli_send('csappreg',$rapp_id);
			}
		}
	}
}



sub tekicli_send {
	my $self = $_[0];
	if ($self->{'TeKiCli'}{'sclient_id'} and $self->{'TeKiCli'}{'_send2sock'}) {
#		print "\t\t1:\t$_[1]\n\t\t2:$_[2]\n";
		$self->{'TeKiCli'}{'_send2sock'}->server_send($self->{'TeKiCli'}{'sclient_id'},$_[1],$_[2]);
	}
}

sub tekicli_socauth_ok {
	BugOUT(9,"TeKi Server tekicli_socauth_ok->START");
	my $self = $_[0];
	my $sclient_id = $_[1];
	my $bself = $_[2];
#	print "CLI AUTH\t$sclient_id\n";
	my $declared_id = $bself->server_get_client_info($sclient_id,'declared_id');
	if (($declared_id->{'app_name'} =~ /telekinesis-client/) and ($declared_id->{'app_class'} eq "noclass")) {# FIXME! CHANGE noclass TO telekinesis-core after finding and fixing  the root cause which is probably where we inititally set this stuff....
		BugOUT(8,"TeKi Server tekicli_socauth_ok->TeKi-Cli Staring Conn Init stuff....");
		if ($self->{'TeKiCli'}{'sclient_id'}) {
			$self->_tekicli_clean_oldcliconn($self->{'TeKiCli'}{'sclient_id'}, $bself);
		}
		$self->{'TeKiCli'}{'sclient_id'} = $sclient_id;
		$self->{'TeKiCli'}{'_send2sock'} = $bself;

#		FIXME: Leftover Scraps? remove this?
#		sub {
#			print "_send:\n\t0:\t$_[0]\n\t1:\t$_[1]\n\t2:\t$_[2]\n";
#			$bself->server_send($sclient_id,$_[1],$_[2]);
#		};
	} else {
		BugOUT(8,"TeKi Server tekicli_socauth_ok->Not TeKi-Cli DROP IT!");
		$bself->server_terminate_client_conn($sclient_id);
	}
	BugOUT(9,"TeKi Server tekicli_socauth_ok->DONE");
}

sub _tekicli_clean_oldcliconn {
	BugOUT(9,"TeKi Server _tekicli_clean_oldcliconn->START");
	my $self = $_[0];
	my $sclient_id = $_[1];
	my $bself = $_[2];

	$self->{'status'}{'active'} = 0;

	if ($self->{'TeKiCli'}{'sclient_id'} eq $sclient_id) {
		$bself->server_terminate_client_conn($sclient_id);
		$self->{'TeKiCli'}{'sclient_id'} = undef;
		delete $self->{'TeKiCli'}{'sclient_id'};
		$self->{'TeKiCli'}{'_send2sock'} = undef;
		delete $self->{'TeKiCli'}{'_send2sock'};
	}
	BugOUT(9,"TeKi Server _tekicli_clean_oldcliconn->DONE");
}

sub tekicli_lostconn {
	BugOUT(9,"TeKi Server tekicli_lostconn->START");
	my $self = $_[0];
	my $sclient_id = $_[1];
	my $bself = $_[2];
#	print "YAY WE LOST CLIENT:\t$sclient_id\n";
	if ($sclient_id eq $bself->{'TeKiCli'}{'sclient_id'}) {
		BugOUT(9,"TeKi Server tekicli_lostconn->LOST ACTIVE CLIENT?");
		$self->_tekicli_clean_oldcliconn($sclient_id, $bself);
	} else {
		BugOUT(9,"TeKi Server tekicli_lostconn->NOT THE CLIENT SO... WHO CARES?");
	}
	BugOUT(9,"TeKi Server tekicli_lostconn->DONE");
}

sub app_init {# FIXME! Are we still using this one?
	my $self = $_[0];
	my $app_id = $_[1];
#	print "GOT APP INIT:\t$app_id\n\t[",$self->{'running_apps'}{$app_id}{'scli_id'},"]\n";
	if ($self->{'running_apps'}{$app_id}{'scli_id'}) {
		warn("ASK APP TO INIT!");
		$self->{'socks'}{'local'}->server_send("$self->{'running_apps'}{$app_id}{'scli_id'}",'appinit',"HELLO")
	}
}

sub _app_reg {
	my $self = $_[0];
	my $data = $_[1];
	my $sclient_id = $_[2];
	my $bself = $_[3];
	my $declared_id = $bself->server_get_client_info($sclient_id,'declared_id');
	if ($declared_id->{'app_class'} eq "noclass") {# FIXME! CHANGE noclass TO tekiapp after finding and fixing  the root cause which is probably where we inititally set this stuff....
#		print "APPREG:\t",Dumper($declared_id),"\n";
		if ($self->{'running_apps'}{$declared_id->{'self_aID'}}) {
			BugOUT(8,"TeKi Server _app_reg-> Previously registered");
#			If previously registered.... remove server and client side instances.
#			so that we can do a full reinstansiation.
		}
		
		$self->{'running_apps'}{$declared_id->{'self_aID'}}{'scli_id'} = $sclient_id;
		
		if ($data->{'service_req'}) {
			my %s_providing;
			my %s_missing;
			foreach my $key (keys %{$data->{'service_req'}}) {
				if ($key =~ /^([a-z]{4,24})$/) {
					my $service_name = $1;
					$self->{'running_apps'}{$declared_id->{'self_aID'}}{'service_req'} = $service_name;
#				if ($self->{'available_services'}{$service_name}) {
#					print "GOT YOUR SERVICE:\t$service_name\n";
#					$s_providing->{$service_name} => 1;
#				} else {
#					$s_missing->{$service_name} => 1;
#				}
				}
			}
		}

		if ($self->{'status'}{'active'} eq 1) {
#			print "241\tACTIVE!?\n";
			$self->tekicli_send('csappreg',$declared_id->{'self_aID'});
		} else {
#			print "243\tNOT!!! ACTIVE!?\n";
		}

	} else {
		$bself->server_terminate_client_conn($sclient_id);
	}
}

sub tmp_socket_info {
# TMP function to inform about socket ID.
# A version of this may be done to provide this info when running TeKi outside of Arctica.
	my $self = $_[0];
	my $localSock = $_[1];
	my $remoteSock = $_[2];
	if ($localSock and $remoteSock) {
		if (-d $self->{'tmpdir'}) {
			open(SIF,">$self->{'tmpdir'}/server_sockets.info");
			print SIF "local:$localSock\nremote:$remoteSock\n";
			close(SIF);
		} else {
			die("TOTAL FAILURE! BUHUHUHHUUUUUUUUUUU!");
		}
	}
}


sub DESTROY {
	my $self = $_[0];
	# FIXME EMIT DIE COMMAND TO ALL APPLICATIONS?
	warn("Telekinesis Server [$self->{'session_id'}] DESTROYED");
	return 0;
}

1;
