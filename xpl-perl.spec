Summary: Modules for writing xPL applications in Perl
Name: xpl-perl
Version: 0.02
Release: 1
Copyright: Perl Licence (C) 2005 by Mark Hindess
Group: Applications/CPAN
Source0: xPL-Perl-%{version}.tar.gz
Url: http://www.xpl-perl.org.uk/
BuildRoot: %{_tmppath}/xpl-perl-buildroot/
BuildRequires: perl
Requires: perl

%description
These modules are intended to provide a framework for writing xPL
applications (see http://wiki.xplproject.org.uk/) in Perl.  A number
of sample applications are also provided including a hub, a logging
client, a bridge and a command line message sender.

# Provide perl-specific find-{provides,requires}.
#%define __find_provides /usr/lib/rpm/find-provides.perl
#%define __find_requires /usr/lib/rpm/find-requires.perl

%prep
%setup -q -n xPL-Perl-%{version} 

%build
CFLAGS="$RPM_OPT_FLAGS"
perl Makefile.PL DESTDIR=$RPM_BUILD_ROOT INSTALLDIRS=vendor
make

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
make install
rm `find $RPM_BUILD_ROOT/usr -name "perllocal.pod" -print`|| true
rm `find $RPM_BUILD_ROOT/usr -name "\.packlist" -print` || true

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT -type f -print | 
        sed "s@^$RPM_BUILD_ROOT@@g" > xpl-perl-%{version}-filelist
if [ "$(cat xpl-perl-%{version}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f xpl-perl-%{version}-filelist
%defattr(-,root,root)

%changelog
* Mon Dec 12 2005 Mark Hindess <xpl-perl@beanz.uklinux.net>
- Initial spec file
