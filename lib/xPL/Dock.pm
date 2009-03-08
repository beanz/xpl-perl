package xPL::Dock;

=head1 NAME

xPL::Dock - Perl extension for an xPL Client with Plugin Support

=head1 SYNOPSIS

  use xPL::Dock qw/Plugin/;

  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client using available plugins.  There
are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use FileHandle;
use Getopt::Long;
use Pod::Usage;
use xPL::Client;

require Exporter;
our @ISA = qw(xPL::Client);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

my @plugins;
my @getopts;

sub import {
  my $pkg = shift;
  foreach (@_) {
    my $module = $pkg.'::'.$_;
    my $file = $module.'.pm';
    $file =~ s/::/\//g;
    eval { require $file; };
    die "Failed loading plugin: $@\n" if ($@);
    my $instance = $module->new;
    push @plugins, $instance;
    push @getopts, $instance->getopts if ($module->can('getopts'));
  }
}

=head2 C<new(%params)>

The constructor creates a new xPL::Dock object.  The
constructor takes a parameter hash as arguments.  Valid parameters in
the hash are those described in L<xPL::Client>, those of any instantiated
plugins and the following additional elements:

=over 4

=item name

  The device_id to use for this client.

=item getopts

  Additional arguments to C<Getopt::Long::GetOptions>.  Default is none.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my %p = @_;

  my $name;
  if ($p{name}) {
    $name = $p{name};
  } else {
    $name = $0;
    $name =~ s/.*xpl-//g; $name =~ s/-//g;
  }

  my %args = ( vendor_id => 'bnz', device_id => $name, );
  my %opt = ();
  my $verbose;
  my $interface;
  my $help;
  my $man;
  GetOptions('verbose+' => \$verbose,
             'interface=s' => \$interface,
             'define=s' => \%opt,
             'help|?|h' => \$help,
             'man' => \$man,
             @getopts,
             @{$p{getopts}|| [] }
            ) or pod2usage(2);
  pod2usage(1) if ($help);
  pod2usage(-exitstatus => 0, -verbose => 2) if ($man);
  $args{'interface'} = $interface if ($interface);
  $args{'verbose'} = $verbose if ($verbose);

  # Create an xPL Client object (dies on error)
  my $self = $pkg->SUPER::new(%args, %opt);

  foreach (@plugins) {
    $_->init($self, %p);
  }
  return $self;
}

sub plugins {
  return @plugins;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
