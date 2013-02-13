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
#---------------------------------------------------------------------

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

#---------------------------------------------------------------------
# Get and return the Google authorization credential
#
# Called automatically by _make_request when needed

sub _login
{
  my $self = shift;

  my $rsp = $self->_make_request(
    HTTP::Request::Common::POST($self->loginURL, [
      accountType => 'GOOGLE',
      Email       => $self->{username},
      Passwd      => $self->{password},
      service     => 'grandcentral',
      source      => 'org.cpan.WebService.Google.Voice.SendSMS',
    ]),
    { no_headers => 1 }    # Can't add authorization, we're logging in
  );

  my $cref = $rsp->decoded_content(ref => 1);
  $$cref =~ /Auth=([A-z0-9_-]+)/ or die "no auth: $$cref";

  return $1;
} # end _login

#---------------------------------------------------------------------
# Send a request via our UA and return the response:
#
# Options may be passed in $args hashref:
#   allow_failure:  if true, do not die if request is unsuccessful
#   no_headers:     if true, omit Authorization & Referer headers

sub _make_request
{
  my ($self, $req, $args) = @_;

  unless ($args->{no_headers}) {
    $req->header(Authorization =>
                 'GoogleLogin auth=' . ($self->{login_auth} ||= $self->_login));
    $req->referer($self->{lastURL});
  }

  my $rsp = $self->{ua}->request($req);

  if ($rsp->is_success) {
    $self->{lastURL} = $rsp->request->uri;
  } else {
    die "HTTP request failed: " . $rsp->status_line
        unless $args->{allow_failure};
  }

  $rsp;
} # end _make_request

#---------------------------------------------------------------------
sub _get_rnr_se
{
  my $self = shift;

  my $rsp = $self->_make_request(HTTP::Request::Common::GET($self->inboxURL));

  my $cref = $rsp->decoded_content(ref => 1);
  $$cref =~ /<input[^>]*?name="_rnr_se"[^>]*?value="([^"]*)"/s
      or die "unable to find _rnr_se in $$cref";

  return $1;
} # end _get_rnr_se
#---------------------------------------------------------------------

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

  return $self->_make_request($req, { allow_failure => 1 })->is_success;
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
