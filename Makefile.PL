use 5.006;
use ExtUtils::MakeMaker;
use FileHandle;

my @exe = ();
my $fh = FileHandle->new("<MANIFEST");
while (<$fh>) {
  chomp;
  push @exe, $_ if (m!^bin/!);
}
$fh->close;

eval { require YAML::Syck; };
if ($@) {
  eval { require YAML; };
  die "Missing required YAML::Syck (recommended) or YAML module\n" if ($@);
  warn "Found YAML module which is sufficient but YAML::Syck would be better\n";
}
WriteMakefile(
              NAME => 'xPL-Perl',
              VERSION_FROM => 'lib/xPL/Base.pm',
              EXE_FILES => \@exe,
              ($] >= 5.005 ? ## Add these new keywords supported since 5.005
               (ABSTRACT => 'lib/xPL/Listener.pm',
                AUTHOR  => 'Mark Hindess <soft-xpl-perl@temporalanomaly.com>',
                PREREQ_PM => {
                  'Module::Pluggable' => 0,
                  'Date::Parse' => 0,
                },
               ) : ()),
             );
open F, "<Makefile.local" or exit(0);
open M, ">>Makefile" or exit(0);
while (<F>) {
  print M;
}
close M;
close F;
