package xPL::Dock::MyHDDTemp;
use base 'xPL::Dock::HDDTemp';
sub read {
  my $self = shift;
  $self->{_read_count}++;
  $self->SUPER::read(@_);
}
1;
