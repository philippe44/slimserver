package Slim::Web::Settings::Server::SqueezeNetwork;

# $Id$

# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Digest::SHA1 qw(sha1_base64);

use Slim::Networking::SqueezeNetwork;
use Slim::Utils::Strings qw(string);
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

my $prefs = preferences('server');

sub name {
	return Slim::Web::HTTP::protectName('SQUEEZENETWORK_SETTINGS');
}

sub page {
	return Slim::Web::HTTP::protectURI('settings/server/squeezenetwork.html');
}

sub prefs {
	# NOTE: if you add a pref here, check that the wizard also submits it
	# in HTML/EN/html/wizard.js
	my @prefs = qw(sn_email sn_password_sha sn_sync sn_disable_stats);

	return ($prefs, @prefs);
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	# The hostname for SqueezeNetwork
	my $sn_server = Slim::Networking::SqueezeNetwork->get_server("sn");
	$params->{sn_server} = $sn_server;

	if ( $params->{saveSettings} ) {
		
		if ( defined $params->{pref_sn_disable_stats} ) {
			Slim::Utils::Timers::setTimer(
				$params->{pref_sn_disable_stats},
				time() + 30,
				\&reportStatsDisabled,
			);
		}

		if ( $params->{pref_sn_email} && $params->{pref_sn_password_sha} ) {
		
			# Verify username/password
			my $request = Slim::Control::Request->new(
				$client ? $client->id : undef,
				[ 
					'setsncredentials', 
					$params->{pref_sn_email}, 
					$params->{pref_sn_password_sha},
					'sync:' . $params->{pref_sn_sync},
				]
			);
			
			$request->callbackParameters(
				sub {
					my $validated = $request->getResult('validated');
					my $warning   = $request->getResult('warning');
			
					if ($params->{'AJAX'}) {
						$params->{'warning'} = $warning;
						$params->{'validated'}->{'valid'} = $validated;
					}
					
					if (!$validated) {
		
						$params->{'warning'} .= $warning . '<br/>' unless $params->{'AJAX'};
		
						delete $params->{pref_sn_email};
						delete $params->{pref_sn_password_sha};
					}

					my $body = $class->SUPER::handler($client, $params);
					$callback->( $client, $params, $body, @args );
				},
			);
			
			$request->execute();

			return;
		}

		elsif ( !$params->{pref_sn_email} && !$params->{pref_sn_password_sha} ) {
			# Shut down SN if username/password were removed
			Slim::Networking::SqueezeNetwork->shutdown();
		}

		else {
			if ($params->{'AJAX'}) {
				$params->{'warning'} = Slim::Utils::Strings::string('SETUP_SN_INVALID_LOGIN', $sn_server); 
				$params->{'validated'}->{'valid'} = 0;
			}
			else {
				$params->{warning} .= Slim::Utils::Strings::string('SETUP_SN_INVALID_LOGIN', $sn_server) . '<br/>';						
			}
			delete $params->{'saveSettings'};
		}
	}

	return $class->SUPER::handler($client, $params);
}

sub reportStatsDisabled {
	my $isDisabled = shift;
	
	my $http = Slim::Networking::SqueezeNetwork->new(
		sub {},
		sub {},
	);
	
	$http->get( $http->url( '/api/v1/stats/mark_disabled/' . $isDisabled ) );
}

1;

__END__
