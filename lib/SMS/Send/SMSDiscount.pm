package SMS::Send::SMSDiscount;

# $Id$

=head1 NAME

SMS::Send::SMSDiscount - SMS::Send SMS Discount Driver

=head1 SYNOPSIS

  # Create a testing sender
  my $send = SMS::Send->new( 'SMSDiscount',
                             _login => 'smsdiscount username',
                             _password => 'smsdiscount pin' );

  # Send a message
  $send->send_sms(
     text => 'Hi there',
     to   => '+61 (4) 1234 5678',
  );

=head1 DESCRIPTION

SMS::Send driver for sending SMS messages with the SMS Discount
Software (http://www.smsdiscount.com/) SMS service.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use SMS::Send::Driver;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

our @ISA = qw/SMS::Send::Driver/;
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.05';
our $SVNVERSION = qw/$Revision$/[1];

our $URL = 'https://myaccount.SMSDiscount.com/clx/sendsms.php';

=head1 CONSTRUCTOR

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  exists $p{_login} or die $pkg."->new requires _login parameter\n";
  exists $p{_password} or die $pkg."->new requires _password parameter\n";
  exists $p{_verbose} or $p{_verbose} = 1;
  my $self = \%p;
  bless $self, $pkg;
  $self->{_ua} = LWP::UserAgent->new();
  return $self;
}

sub send_sms {
  my $self = shift;
  my %p = @_;
  $p{to} =~ s/^\+//;
  $p{to} =~ s/[- ]//g;

  my $response = $self->{_ua}->post($URL,
                                    {
                                     username => $self->{_login},
                                     password => $self->{_password},
                                     text => $p{text},
                                     to => '+'.$p{to},
                                    });
  unless ($response->is_success) {
    my $s = $response->as_string;
    warn "HTTP failure: $s\n" if ($self->{_verbose});
    return 0;
  }
  my $s = $response->as_string;
  $s =~ s/\r?\n$//;
  $s =~ s/^.*\r?\n//s;
  unless ($s =~ /Message Sent OK/i) {
    warn "Failed: $s\n" if ($self->{_verbose});
    return 0;
  }
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

SMS::Send(3), SMS::Send::Driver(3)

SMS Discount Website: http://www.smsdiscount.com/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
