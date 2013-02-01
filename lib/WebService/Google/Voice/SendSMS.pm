#---------------------------------------------------------------------
package WebService::Google::Voice::SendSMS;
#
# Copyright 2013 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 29 Jan 2013
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Send a SMS using Google Voice
#---------------------------------------------------------------------

use 5.008;
use strict;
use warnings;

use LWP::UserAgent 6 ();
use HTTP::Request::Common ();

our $VERSION = '0.01';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

#=====================================================================

sub inboxURL { 'https://www.google.com/voice/m/' }
sub loginURL { 'https://www.google.com/accounts/ClientLogin' }
sub smsURL   { 'https://www.google.com/voice/m/sendsms' }

sub new
{
  my ($class, $username, $password) = @_;

  bless {
    username => $username,
    password => $password,
    ua       => LWP::UserAgent->new(
      agent => "Mozilla/5.0 (iPhone; U; CPU iPhone OS 2_2_1 like Mac OS X;".
               " en-us) AppleWebKit/525.18.1 (KHTML, like Gecko) ".
               "Version/3.1.1 Mobile/5H11 Safari/525.20",
      cookie_jar => {},
    ),
  }, $class;
} # end new

sub _login
{
  my $self = shift;

  my $req = HTTP::Request::Common::POST($self->loginURL, [
    accountType => 'GOOGLE',
    Email       => $self->{username},
    Passwd      => $self->{password},
    service     => 'grandcentral',
    source      => 'org.cpan.WebService.Google.Voice.SendSMS',
  ]);

  my $rsp = $self->{ua}->request($req);
  die $rsp->status_line unless $rsp->is_success;
  $self->{lastURL} = $rsp->request->uri;

  my $cref = $rsp->decoded_content(ref => 1);
  $$cref =~ /Auth=([A-z0-9_-]+)/ or die "no auth: $$cref";

  return $1;
} # end _login

sub _make_request
{
  my ($self, $req) = @_;

  $req->header(Authorization =>
               'GoogleLogin auth=' . ($self->{login_auth} ||= $self->_login));
  $req->referer($self->{lastURL});

  my $rsp = $self->{ua}->request($req);

  $self->{lastURL} = $rsp->request->uri if $rsp->is_success;

  $rsp;
} # end _make_request

sub _get_rnr_se
{
  my $self = shift;

  my $req = HTTP::Request::Common::GET($self->inboxURL);

  my $rsp = $self->_make_request($req);
  die $rsp->status_line unless $rsp->is_success;

  my $cref = $rsp->decoded_content(ref => 1);
  $$cref =~ /<input[^>]*?name="_rnr_se"[^>]*?value="([^"]*)"/s
      or die "unable to find _rnr_se in $$cref";

  return $1;
} # end _get_rnr_se

sub send_sms
{
  my ($self, $number, $message) = @_;

  my $req = HTTP::Request::Common::POST($self->smsURL, [
    id      => '',
    c       => '',
    number  => $number,
    smstext => $message,
    _rnr_se => $self->_get_rnr_se,
  ]);

  return $self->_make_request($req)->is_success;
} # end send_sms

#=====================================================================
# Package Return Value:

1;

__END__

=head1 SYNOPSIS

  use WebService::Google::Voice::SendSMS;

  my $sender = WebService::Google::Voice::SendSMS->new(
    $email_address, $password
  );

  $sender->send_sms($phone_number => $message);
