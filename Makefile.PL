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

WriteMakefile(
              NAME => 'xPL-Perl',
              VERSION_FROM => 'lib/xPL/Base.pm',
              EXE_FILES => \@exe,
              ($] >= 5.005 ? ## Add these new keywords supported since 5.005
               (ABSTRACT => 'lib/xPL/Listener.pm',
                AUTHOR  => 'Mark Hindess <xpl-perl@beanz.uklinux.net>',
                PREREQ_PM => {
                  'YAML' => 0,
                },
               ) : ()),
             );

sub MY::postamble {
  return <<'END';

COVER = cover

coverclean:
	$(COVER) -delete

testcover: pure_all coverclean
	HARNESS_PERL_SWITCHES=-MDevel::Cover PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)
	$(COVER)
	ln -s coverage.html cover_db/index.html

END
}
