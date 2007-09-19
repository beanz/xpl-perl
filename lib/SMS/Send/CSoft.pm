package SMS::Send::CSoft;

# $Id: Base.pm 312 2007-06-18 19:20:09Z beanz $

=head1 NAME

xPL::Base - Perl extension for an xPL Base Class

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a module for a common base class for the xPL modules.  It
contains a number of helper methods.

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
our $SVNVERSION = qw/$Revision: 312 $/[1];

my $URL = 'https://www.csoft.co.uk/sendsms';

=head1 CONSTRUCTOR

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  exists $p{_login} or die $pkg."->new requires _login parameter\n";
  exists $p{_password} or die $pkg."->new requires _password parameter\n";
  $p{_verbose} = 1;
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
  print STDERR "P: ", $_, " => ", $p{$_},"\n" foreach (sort keys %p);
  my $response = $self->{_ua}->post($URL,
                                    {
                                     Username => $self->{_login},
                                     PIN => $self->{_password},
                                     Message => $p{text},
                                     SendTo => $p{to},
                                    });
  unless ($response->is_success) {
    my $s = $response->as_string;
    print STDERR "HTTP failure: $s\n" if ($self->{_verbose});
    return 0;
  }
  my $s = $response->as_string;
  $s =~ s/\r?\n$//;
  $s =~ s/^.*\r?\n//s;
  unless ($s =~ /Message Sent OK/i) {
    print STDERR "Failed: $s\n" if ($self->{_verbose});
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

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
