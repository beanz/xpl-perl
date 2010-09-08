package Net::DBus;
sub session { bless { calls => [] }, 'Net::DBus' }
sub calls { splice @{$_[0]->{calls}} }
sub AUTOLOAD {
  my $self = shift;
  our $AUTOLOAD;
  push @{$self->{calls}}, "$AUTOLOAD ".Data::Dumper->Dump([\@_],[qw/args/]);
  $self;
}
sub DESTROY {}
sub get_object {
  push @{$self->{calls}}, "get_object ".Data::Dumper->Dump([\@_],[qw/args/]);
  Net::DBus::RemoteObject->new();
}

package Net::DBus::RemoteObject;
use Data::Dumper;
sub new { bless { calls => [] }, 'Net::DBus::RemoteObject' }
sub calls { splice @{$_[0]->{calls}} }
sub AUTOLOAD {
  my $self = shift;
  our $AUTOLOAD;
  push @{$self->{calls}}, "$AUTOLOAD ".Data::Dumper->Dump([\@_],[qw/args/]);
}
sub DESTROY {}
1;

